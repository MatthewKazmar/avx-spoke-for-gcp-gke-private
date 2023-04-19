variable "avx_gcp_account_name" {
  description = "GCP account as it appears in the controller."
  type        = string
}

variable "transit_gateway_name" {
  description = "Transit Gateway to connect this spoke to."
  type        = string
}

variable "network_domain" {
  description = "Network domain to associate this spoke with. Optional."
  type        = string
  default     = null
}

variable "name" {
  description = "Name of the GKE spoke."
  type        = string
}

variable "region" {
  description = "Region to deploy Aviatrix Spoke and GKE."
  type        = string
}

variable "cidr" {
  description = "CIDR for the Spoke Gateway and GKE ranges. Use /22."
  type        = string

  validation {
    condition     = split("/", var.cidr)[1] == "22"
    error_message = "This module needs a /22."
  }
}

variable "aviatrix_spoke_instance_size" {
  description = "Size of the Aviatrix Spoke Gateway."
  type        = string
  default     = "n1-standard-1"
}

variable "gke_node_instance_size" {
  description = "Size of the GCP Cloud Build worker instance."
  type        = string
  default     = "e2-medium"
}

variable "advertise_pod_service_ranges" {
  description = "Advertise the pod and service ranges into the larger network."
  type        = bool
  default     = false
}

variable "use_aviatrix_firenet_egress" {
  description = "Apply the avx_snat_noip tag to nodes for Egress"
  type        = bool
  default     = true
}

locals {

  avx      = cidrsubnet(var.cidr, 2, 0)  # 10.0.0.0/22 -> 10.0.0.0/24
  nodes    = cidrsubnet(var.cidr, 4, 4)  # 10.0.0.0/22 -> 10.0.1.0/26
  master   = cidrsubnet(var.cidr, 6, 20) # 10.0.0.0/22 -> 10.0.1.64/28
  services = cidrsubnet(var.cidr, 3, 3)  # 10.0.0.0/22 -> 10.0.1.128/25
  pods     = cidrsubnet(var.cidr, 1, 1)  # 10.0.0.0/22 -> 10.0.2.0/23
  proxy    = cidrsubnet(var.cidr, 6, 21) # 10.0.0.0/22 -> 10.0.1.80/28

  advertised_ranges = var.advertise_pod_service_ranges ? var.cidr : "${local.avx},${local.nodes},${local.master},${local.proxy}"
  firewall_source   = var.advertise_pod_service_ranges ? [local.master, local.services, local.pods, local.proxy] : [local.master, local.proxy]
  tags              = var.use_aviatrix_firenet_egress ? ["avx-snat-noip"] : null
}