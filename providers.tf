terraform {
  required_version = ">= 0.14"
}

provider "kubernetes" {
  #load_config_file = false
  host = "https://${google_container_cluster.workload_demo.endpoint}"
  cluster_ca_certificate = "${base64decode(google_container_cluster.workload_demo.master_auth.0.cluster_ca_certificate)}"
  token = "${data.google_client_config.current.access_token}"
}

provider "google" {
  region  = var.region
  project = var.project
}

