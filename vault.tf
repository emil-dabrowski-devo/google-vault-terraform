# This file contains all the interactions with Kubernetes
data "google_client_config" "current" {}

# Create namespace
resource "kubernetes_namespace" "vault" {
  metadata {
    name = var.vault_namespace
  }
}

resource "kubernetes_namespace" "application" {
  metadata {
    name = var.app_namespace
  }

}

# Create service account in GKE
resource "kubernetes_service_account" "vault_sa" {
  metadata {
    name = "vault-server"
    namespace = kubernetes_namespace.vault.metadata[0].name
    annotations = {
      "iam.gke.io/gcp-service-account" = google_service_account.vault_server.email
    }
  }
}

resource "kubernetes_service_account" "app_sa" {
  metadata {
    name = "application-sa"
    namespace = kubernetes_namespace.application.metadata[0].name
    annotations = {
      "iam.gke.io/gcp-service-account" = google_service_account.application.email
    }
  }
}

#Grant service account access to act as Workload Identity User
resource "google_project_iam_binding" "workload_identity" {
  project = var.project
  role    = "roles/iam.workloadIdentityUser"
  members = [
    "serviceAccount:${var.project}.svc.id.goog[${kubernetes_namespace.vault.metadata[0].name}/${kubernetes_service_account.vault_sa.metadata[0].name}]"
  ]
}

# Write the secret
resource "kubernetes_secret" "vault-tls" {
  metadata {
    name = "vault-tls"
    namespace = kubernetes_namespace.vault.metadata[0].name
  }
  data = {
    "vault.crt" = "${tls_locally_signed_cert.vault.cert_pem}\n${tls_self_signed_cert.vault-ca.cert_pem}"
    "vault.key" = tls_private_key.vault.private_key_pem
    "ca.crt"    = tls_self_signed_cert.vault-ca.cert_pem
  }
}

#Create ClusterIP service
resource "kubernetes_service" "vault_cluster" {
  metadata {
    name = "vault"
    namespace = kubernetes_namespace.vault.metadata[0].name
    labels = {
      app = "vault"
    }
  }
  spec {
    type                        = "ClusterIP"
    cluster_ip                  = var.vault_address
    selector = {
      app = "vault"
    }
    port {
      name        = "vault-port"
      port        = 443
      target_port = 8200
      protocol    = "TCP"
    }
  }
}



#Create vault deployment
resource "kubernetes_deployment" "vault" {
  metadata {
    name = "vault"
    namespace = kubernetes_namespace.vault.metadata[0].name
    labels = {
      app = "vault"
    }
  }
  spec {
    replicas     = var.num_vault_pods
    selector {
      match_labels = {
        app = "vault"
      }
    }
    template {
      metadata {
        labels = {
          app = "vault"
        }
      }
      spec {
        toleration {
          effect = "NoSchedule"
          key = "vault"
          operator = "Equal"
          value = "true"
        }
        service_account_name = kubernetes_service_account.vault_sa.metadata[0].name
        node_selector = {
          "vault" = "true"
                }
        termination_grace_period_seconds = 1 
        affinity {
          pod_anti_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 50
              pod_affinity_term {
                topology_key = "kubernetes.io/hostname"
                label_selector {
                  match_expressions {
                    key      = "app"
                    operator = "In"
                    values   = ["vault"]
                  }
                }
              }
            }
          }
        }
        container {
          name              = "vault-init"
          image             = var.vault_init_container
          image_pull_policy = "IfNotPresent"
          env {
            name  = "GCS_BUCKET_NAME"
            value = google_storage_bucket.vault.name
          }
          env {
            name  = "KMS_KEY_ID"
            value = google_kms_crypto_key.vault-init.self_link
          }
          env {
            name  = "VAULT_ADDR"
            value = "http://127.0.0.1:8200"
          }
          env {
            name  = "VAULT_SECRET_SHARES"
            value = var.vault_recovery_shares
          }
          env {
            name  = "VAULT_SECRET_THRESHOLD"
            value = var.vault_recovery_threshold
          }
        }
        container {
          name              = "vault"
          image             = var.vault_container
          image_pull_policy = "IfNotPresent"
          args              = ["server"]
          security_context {
            capabilities {
              add = ["IPC_LOCK"]
            }
          }
          port {
            name           = "vault-port"
            container_port = 8200
            protocol       = "TCP"
          }
          port {
            name           = "cluster-port"
            container_port = 8201
            protocol       = "TCP"
          }
          volume_mount {
            name       = "vault-tls"
            mount_path = "/etc/vault/tls"
          }
          # volume_mount {
          #   name      = "vault-key"
          #   mount_path = "/etc/vault/cred"
          # }
          env {
            name  = "VAULT_ADDR"
            value = "http://127.0.0.1:8200"
          }
          env {
            name = "POD_IP_ADDR"
            value_from {
              field_ref {
                field_path = "status.podIP"
              }
            }
          }
          env {
            name  = "VAULT_LOCAL_CONFIG"
            value = <<EOF
              api_addr     = "https://${var.vault_address}"
              cluster_addr = "https://$(POD_IP_ADDR):8201"
              log_level = "warn"
              ui = true
              seal "gcpckms" {
                project    = "${google_kms_key_ring.vault.project}"
                region     = "${google_kms_key_ring.vault.location}"
                key_ring   = "${google_kms_key_ring.vault.name}"
                crypto_key = "${google_kms_crypto_key.vault-init.name}"
              }
              storage "gcs" {
                bucket     = "${google_storage_bucket.vault.name}"
                ha_enabled = "true"
              }
              listener "tcp" {
                address     = "127.0.0.1:8200"
                tls_disable = "true"
              }
              listener "tcp" {
                address       = "$(POD_IP_ADDR):8200"
                tls_cert_file = "/etc/vault/tls/vault.crt"
                tls_key_file  = "/etc/vault/tls/vault.key"
                tls_disable_client_certs = true
              }
            EOF
          }
          readiness_probe {
            initial_delay_seconds = 5
            period_seconds        = 5
            http_get {
              path   = "/v1/sys/health?standbyok=true"
              port   = 8200
              scheme = "HTTPS"
            }
          }
        }
        volume {
          name = "vault-tls"
          secret {
            secret_name = "vault-tls"
          }
        }
        # volume {
        #   name = "vault-key"
        #   secret {
        #     secret_name = "vault-key"
        #   }
        # }
      }
    }
  }
  depends_on = [google_container_node_pool.vault]
}

#Print token decrypt command
output "root_token_decrypt_command" {
  value = "gsutil cat gs://${google_storage_bucket.vault.name}/root-token.enc | base64 --decode | gcloud kms decrypt --key ${google_kms_crypto_key.vault-init.self_link} --ciphertext-file - --plaintext-file -"
}
