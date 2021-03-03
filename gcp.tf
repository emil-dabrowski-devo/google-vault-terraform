# Use an existing project, if defined
data "google_project" "vault" {
  project_id = var.project
}

# Create the vault service account
resource "google_service_account" "vault_server" {
  account_id   = "vaultserver"
  display_name = ""
  project      = data.google_project.vault.project_id
}

# Create service account key
# resource "google_service_account_key" "vault_server" {
#   service_account_id = google_service_account.vault_server.name
# }


resource "google_service_account" "applicattion" {
  account_id   = "applicattion"
  display_name = ""
  project      = data.google_project.vault.project_id
}


# Enable required services on the project
resource "google_project_service" "service" {
  count   = length(var.project_services)
  project = data.google_project.vault.project_id
  service = element(var.project_services, count.index)
  # Do not disable the service on destroy. On destroy, we are going to
  # destroy the project, but we need the APIs available to destroy the
  # underlying resources.
  disable_on_destroy = false
}

# Create the storage bucket
resource "google_storage_bucket" "vault" {
  name          = "${data.google_project.vault.project_id}-vault-storage"
  project       = data.google_project.vault.project_id
  force_destroy = true
  storage_class = "REGIONAL"
  location      = var.region
  uniform_bucket_level_access = true
  versioning {
    enabled = true
  }
  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      num_newer_versions = 1
    }
  }
  depends_on = [google_project_service.service]
}

# Grant service account access to the storage bucket
resource "google_storage_bucket_iam_member" "vault_server" {
  count  = length(var.storage_bucket_roles)
  bucket = google_storage_bucket.vault.name
  role   = element(var.storage_bucket_roles, count.index)
  member = "serviceAccount:${google_service_account.vault_server.email}"
}


# Grand service account access to create JWT
resource "google_project_iam_member" "jwtaccess" {
  project = var.project
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:${google_service_account.vault_server.email}"
}

# Grand service account access serviceAccountAdmin
resource "google_project_iam_member" "saadmin" {
  project = var.project
  role    = "roles/iam.serviceAccountAdmin"
  member  = "serviceAccount:${google_service_account.vault_server.email}"
}


# Generate a random suffix for the KMS keyring. Like projects, key rings names
# must be globally unique within the project. A key ring also cannot be
# destroyed, so deleting and re-creating a key ring will fail.
#
# This uses a random_id to prevent that from happening.
resource "random_id" "kms_random" {
  prefix      = var.kms_key_ring_prefix
  byte_length = "8"
}

# Obtain the key ring ID or use a randomly generated on.
locals {
  kms_key_ring = var.kms_key_ring != "" ? var.kms_key_ring : random_id.kms_random.hex
}

# Create the KMS key ring
resource "google_kms_key_ring" "vault" {
  name     = local.kms_key_ring
  location = var.region
  project  = data.google_project.vault.project_id
  depends_on = [google_project_service.service]
}

# Create the crypto key for encrypting init keys
resource "google_kms_crypto_key" "vault-init" {
  name            = var.kms_crypto_key
  key_ring        = google_kms_key_ring.vault.id
  rotation_period = "604800s"
}

# Grant service account access to the key
resource "google_kms_crypto_key_iam_member" "vault-init" {
  crypto_key_id = google_kms_crypto_key.vault-init.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_service_account.vault_server.email}"
}

# Create the crypto key for encrypting Kubernetes secrets
resource "google_kms_crypto_key" "kubernetes-secrets" {
  name            = var.kubernetes_secrets_crypto_key
  key_ring        = google_kms_key_ring.vault.id
  rotation_period = "604800s"
}

# Grant GKE access to the key
resource "google_kms_crypto_key_iam_member" "kubernetes-secrets-gke" {
  crypto_key_id = google_kms_crypto_key.kubernetes-secrets.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.vault.number}@container-engine-robot.iam.gserviceaccount.com"
}

# Create network
resource "google_compute_network" "default" {
  name                    = var.network_name
  auto_create_subnetworks = "false"
  depends_on = [
    google_project_service.service 
    ]
}

resource "google_compute_subnetwork" "main" {
  name                     = "${var.network_name}-main"
  ip_cidr_range            = var.main_cidr
  network                  = google_compute_network.default.self_link
  region                   = var.region
  private_ip_google_access = true
}

# resource "google_compute_subnetwork" "pod" {
#   name                     = "${var.network_name}-pod"
#   ip_cidr_range            = var.pod_cidr
#   network                  = google_compute_network.default.self_link
#   region                   = var.region
#   private_ip_google_access = true
# }

# resource "google_compute_subnetwork" "service" {
#   name                     = "${var.network_name}-service"
#   ip_cidr_range            = var.service_cidr
#   network                  = google_compute_network.default.self_link
#   region                   = var.region
#   private_ip_google_access = true
# }

# resource "google_compute_router" "router" {
#   name    = "${var.project}-router"
#   project = var.project
#   region  = var.region
#   network = google_compute_network.default.self_link
# }

# resource "google_compute_router_nat" "main" {
#   project                            = var.project
#   region                             = var.region
#   name                               = "${var.project}-nat"
#   router                             = google_compute_router.router.name
#   nat_ip_allocate_option             = "AUTO_ONLY"
#   source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_PRIMARY_IP_RANGES"
# }