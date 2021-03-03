resource "google_container_cluster" "workload_demo" {
  # provider = google-beta
  name     = var.cluster_name
  location = var.zone
  project = var.project
  network = google_compute_network.default.self_link
  subnetwork = google_compute_subnetwork.main.self_link
  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"
  #remove_default_node_pool = true

  ip_allocation_policy {
    cluster_ipv4_cidr_block  = var.pod_cidr
    services_ipv4_cidr_block = var.service_cidr
  }

  workload_identity_config {
  identity_namespace = "${var.project}.svc.id.goog"
  }

  # private_cluster_config {
  #   enable_private_endpoint = true
  #   enable_private_nodes    = true
  #   master_ipv4_cidr_block  = var.management_cidr
  # }

  # master_authorized_networks_config {

  # }
  
  release_channel {
    channel =  "REGULAR" 
    }

  enable_shielded_nodes = true
  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  addons_config {

    http_load_balancing {
        disabled = true
    }
    
    horizontal_pod_autoscaling {
        disabled = false
    }

    network_policy_config {
        disabled = false
    }

  }

  maintenance_policy {
    recurring_window {
        start_time = timestamp()
        end_time = timeadd(timestamp(), "48h")
        recurrence = "FREQ=WEEKLY;BYDAY=FR,SA,SU"
        }
    }

  database_encryption {
    state = "DECRYPTED"
    }

  network_policy {
    provider = "CALICO"
    enabled = true
    }

  node_pool {
    name       = "default-pool"
    node_count = 1

    management {
      auto_upgrade = true
      auto_repair = true
    }


  node_config {
    disk_size_gb    = 50
    disk_type       = "pd-standard"
    machine_type    = var.machine_type
    image_type       = "COS"
    
    workload_metadata_config {
      node_metadata = "GKE_METADATA_SERVER"
    }


    shielded_instance_config {
      enable_secure_boot = true
      enable_integrity_monitoring = true
      }

    metadata = {
      disable-legacy-endpoints = "true"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/devstorage.full_control",
      "https://www.googleapis.com/auth/servicecontrol",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/trace.append",
    ]
  }
}

timeouts {
    create = "45m"
    update = "45m"
    delete = "45m"
  }

}

resource "google_container_node_pool" "ordermanagement" {
  name       = "ordermanagement"
  location   = var.zone
  cluster    = google_container_cluster.workload_demo.name
  node_count = 1

  management {
    auto_upgrade = true
    auto_repair = true
    }

  autoscaling {
    min_node_count = 0
    max_node_count = 3
    }

  node_config {
    workload_metadata_config {
      node_metadata = "GKE_METADATA_SERVER"
    }
    preemptible  = false
    machine_type = var.machine_type
    disk_size_gb = 100
    image_type = "COS"
    disk_type = "pd-standard"

    shielded_instance_config {
        enable_secure_boot = true
        enable_integrity_monitoring = true
    }
 
    metadata = {
      disable-legacy-endpoints = "true"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
  
  timeouts {
    create = "45m"
    update = "45m"
    delete = "45m"
  }

}

resource "google_container_node_pool" "vault" {
  name       = "vault"
  location   = var.zone
  cluster    = google_container_cluster.workload_demo.name
  node_count = var.num_vault_pods

  management {
    auto_upgrade = true
    auto_repair = true
    }

  node_config {
    workload_metadata_config {
      node_metadata = "GKE_METADATA_SERVER"
    }
    preemptible  = false
    machine_type = var.machine_type
    disk_size_gb = 50
    image_type = "COS"
    service_account = google_service_account.vault_server.email
    disk_type = "pd-standard"
    shielded_instance_config {
        enable_secure_boot = true
        enable_integrity_monitoring = true
    } 
    metadata = {
      disable-legacy-endpoints = "true"
    }    

    taint {
      key = "vault"
      value = "true"
      effect = "NO_SCHEDULE"
    }

    labels = {
      vault = "true"
    }
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  } 
  timeouts {
    create = "45m"
    update = "45m"
    delete = "45m"
  }
}