variable "region" {
  type        = string
  default     = ""
  description = "Region in which to create the cluster and run Vault."
}

variable "zone" {
  type = string
  default = ""
}

variable "project" {
  type        = string
  default     = ""
  description = "Project ID where Terraform is authenticated to run to create additional projects. If provided, Terraform will create the GKE and Vault cluster inside this project. If not given, Terraform will generate a new project."
}

variable "project_services" {
  type = list(string)
  default = [
    "cloudkms.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "container.googleapis.com",
    "compute.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "firestore.googleapis.com",
  ]
  description = "List of services to enable on the project."
}

variable "storage_bucket_roles" {
  type = list(string)
  default = [
    "roles/storage.admin",
    "roles/storage.objectAdmin",
    "roles/storage.objectViewer"
  ]
  description = "List of storage bucket roles."
}

#
# KMS options
# ------------------------------

variable "kms_key_ring_prefix" {
  type        = string
  default     = "vault-"
  description = "String value to prefix the generated key ring with."
}

variable "kms_key_ring" {
  type        = string
  default     = ""
  description = "String value to use for the name of the KMS key ring. This exists for backwards-compatability for users of the existing configurations. Please use kms_key_ring_prefix instead."
}

variable "kms_crypto_key" {
  type        = string
  default     = "vault-init"
  description = "String value to use for the name of the KMS crypto key."
}

#
# This is an option used by the kubernetes provider, but is part of the Vault
# security posture.
variable "vault_source_ranges" {
  type        = list(string)
  default     = [ "0.0.0.0/0" ]
  description = "List of addresses or CIDR blocks which are allowed to connect to the Vault IP address. The default behavior is to allow anyone (0.0.0.0/0) access. You should restrict access to external IPs that need to access the Vault cluster."
}

#
# Vault options
# ------------------------------

variable "num_vault_pods" {
  type        = number
  default     = 2
  description = "Number of Vault pods to run. Anti-affinity rules spread pods across available nodes. Please use an odd number for better availability."
}

variable "node_locations" {
  type        = string
  default     = "europe-west1-b"
  description = "Zones for nodepool"
}

variable "machine_type" {
  type        = string
  default     = "e2-small"
  description = "Number of Vault pods to run. Anti-affinity rules spread pods across available nodes. Please use an odd number for better availability."
}

variable "cluster_name" {
  type        = string
  default     = ""
}

variable "vault_container" {
  type        = string
  default     = "vault:latest"
  description = "Name of the Vault container image to deploy. This can be specified like \"container:version\" or as a full container URL."
}

variable "vault_init_container" {
  type        = string
  default     = "sethvargo/vault-init:latest"
  description = "Name of the Vault init container image to deploy. This can be specified like \"container:version\" or as a full container URL."
}

variable "vault_recovery_shares" {
  type        = string
  default     = "1"
  description = "Number of recovery keys to generate."
}

variable "vault_recovery_threshold" {
  type        = string
  default     = "1"
  description = "Number of recovery keys required for quorum. This must be less than or equal to \"vault_recovery_keys\"."
}

variable "kubernetes_secrets_crypto_key" {
  type        = string
  default     = "kubernetes-secrets"
  description = "Name of the KMS key to use for encrypting the Kubernetes database."
}

# variable "gke_endpoint" {
#   type        = string
#   default     = "https://35.194.125.192"
#   description = "GKE endpoint"
# }

# variable "gke_cert" {
#   type        = string
#   default     = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURLekNDQWhPZ0F3SUJBZ0lSQU4vaDBrOE5WYmwzV2hnTE01cHNvNHd3RFFZSktvWklodmNOQVFFTEJRQXcKTHpFdE1Dc0dBMVVFQXhNa05EVTVOemRtTVRFdE56QXdNQzAwWW1RMUxXRTVObUV0TlRVd01UWXpNalpsWkdObApNQjRYRFRJd01UQXlPREEzTWpNd09Wb1hEVEkxTVRBeU56QTRNak13T1Zvd0x6RXRNQ3NHQTFVRUF4TWtORFU1Ck56ZG1NVEV0TnpBd01DMDBZbVExTFdFNU5tRXROVFV3TVRZek1qWmxaR05sTUlJQklqQU5CZ2txaGtpRzl3MEIKQVFFRkFBT0NBUThBTUlJQkNnS0NBUUVBdnB5bTZQRVdHOC9ZbE80UVVrZERJZCtTcUpORzJobmRSZ2dlb1RsYwpYSytYTC9yQjVYS1FJQ1p5V0phajBiU3FKZHNQS1A5YUdld2F0UmE0WVBVZ3l2aldtdFlqMTdRa3JjOUNqT2tJCngzTTJuV2tuTHhzYlBSMkpmSW0zUVBmVVFlN2FEYmNFVHZzbi9JbmlSRnJUV2ZWT1RFU1JNa2xtbGNDUVduQjQKbEUzbkJnc3NSdkJ5eUJMckJLUVZMdlJkaCtsNGZXemo0V1pkQ2g2UUVWY240OVcyMFZSY1hORlNqR1dUSSt1SwplcmJlZ1RPNWRFcm1oMVdTcTZqN2dDRVJWaTc5VllObWhvUjdSZlI3dHJSK1dqVkRjcWxDUFZRMmtIcGExSXpjCjRBQlMvUXJLbnc5eWNSWG41U0Z2VkpHSFBvZUllbkFSb2tkdVpHVHZ1VVBUUlFJREFRQUJvMEl3UURBT0JnTlYKSFE4QkFmOEVCQU1DQWdRd0R3WURWUjBUQVFIL0JBVXdBd0VCL3pBZEJnTlZIUTRFRmdRVTU1MmlwMlp1eVFVVgpBU1lnT01FZUtCY1owamd3RFFZSktvWklodmNOQVFFTEJRQURnZ0VCQUVqQmhTRExXUUJtWWhHa1Q3dWVJMEZBCjhBQng5RTIySldnTkpiZEkrdjBsYzFPSkFZNldTMUM2dDFVcVJiNlMvTncyeHBlM3hqZ0RSbWFmY1RpMVhTL3UKMnZDbkJXTTRyTVhBK2VCbFBCTjBOOFZLYnVJSjJpb3A5VVJ3Q2tkKzl0aFhEc1R0VjhCQmh5aUZzM0k2TzJJTQo0WVdMR256Y1A1bzhTeFkzVForbE5xc0p3MVJUTHZHYUR5MDh3eXNyTlBYa3hpRWhhT0s0UTFkYkdMcDhvNlE0Cm5oWGl0bTA4aExzVlE5eXYrczBFNEo2c1NzMTRhSHo1MitQUENLMDd1emRKSWNQU2U4RDZQWUVYVGFMS3A3ZHUKTTQ2ZlBncFdPdThaTkFVOTJuTDgrVUdXUU9FV3N0RzNvK041RDFLaC8vRytyRmdnTGJJNlFuLzJ5clNNcFhRPQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg=="
#   description = "GKE  cert"
# }

# variable "gke_token" {
#   type = string
#   default = "ya29.a0AfH6SMD2eeqzNhsZmS9MPuYXViTwUdq90bvSQ-RFOyDESsk9IDC-HWAGrUaaEyUeoFXCqi5u5lDY8zKq25a8GZRQ3Svptx7HLU1dAREOXxfzC4s43rg9EtHjWPv0fjXkkh-Zi4GId2UaXarZwz2mFaK-yF3SHU5Dj0-HiRzyU6Y8qA"
#   description = "GKE access token"
# }

variable "vault_address" {
  type = string
  default = "10.32.10.200"
  description = "Vault Cluster IP"
}

variable "network_name" {
  type = string
  default = ""
}

variable "main_cidr" {
  type = string
  default = ""
}

variable "pod_cidr" {
  type = string
  default = ""
}

variable "service_cidr" {
  type = string
  default = "10.32.0.0/16"
}

variable "management_cidr" {
  type = string
  default = ""
}

variable "vault_namespace" {
  type = string
  default = "vault"
}

variable "app_namespace" {
  type = string
  default = ""
}
