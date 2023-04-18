data "aviatrix_account" "this" {
  account_name = var.avx_gcp_account_name
}

data "google_compute_default_service_account" "default" {}

data "google_compute_zones" "this" {
  region = var.region
  status = "UP"
}

module "gke_spoke" {
  source                           = "terraform-aviatrix-modules/mc-spoke/aviatrix"
  version                          = "1.5.0"
  cloud                            = "GCP"
  region                           = var.region
  name                             = "${var.name}-spoke-vpc"
  gw_name                          = "${var.name}-spoke-gateway"
  instance_size                    = var.aviatrix_spoke_instance_size
  cidr                             = local.avx
  account                          = var.avx_gcp_account_name
  transit_gw                       = var.transit_gateway_name
  included_advertised_spoke_routes = local.advertised_ranges
}

resource "google_compute_subnetwork" "gke_subnet" {
  project = data.aviatrix_account.this.gcloud_project_id

  name          = "${var.name}-gke-cluster"
  ip_cidr_range = local.nodes
  region        = var.region
  network       = module.gke_spoke.vpc.id

  secondary_ip_range {
    range_name    = "${var.name}-gke-services"
    ip_cidr_range = local.services
  }

  secondary_ip_range {
    range_name    = "${var.name}-gke-pods"
    ip_cidr_range = local.pods
  }
}

resource "google_container_cluster" "gke" {
  name     = "${var.name}-gke-cluster"
  location = var.region
  project  = data.aviatrix_account.this.gcloud_project_id

  initial_node_count = 1

  node_config {
    machine_type = var.gke_node_instance_size
    disk_size_gb = 20
    gvnic {
      enabled = true
    }

  }

  node_locations = slice(data.google_compute_zones.this.names, 0, 3)

  networking_mode = "VPC_NATIVE"
  network         = module.gke_spoke.vpc.id
  subnetwork      = google_compute_subnetwork.gke_subnet.id

  ip_allocation_policy {
    cluster_secondary_range_name  = "${var.name}-gke-pods"
    services_secondary_range_name = "${var.name}-gke-services"
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "10.0.0.0/8"
      display_name = "rfc10"
    }
    cidr_blocks {
      cidr_block   = "172.16.0.0/12"
      display_name = "rfc172"
    }
    cidr_blocks {
      cidr_block   = "192.168.0.0/16"
      display_name = "rfc192"
    }
    gcp_public_cidrs_access_enabled = false
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = true
    master_ipv4_cidr_block  = local.master
    master_global_access_config {
      enabled = true
    }
  }
}

resource "google_compute_network_peering_routes_config" "peering_routes" {
  peering = google_container_cluster.gke.private_cluster_config[0].peering_name
  network = google_container_cluster.gke.network

  import_custom_routes = true
  export_custom_routes = true
}