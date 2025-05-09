terraform {
  required_version = ">= 1.0.0"
  backend "gcs" {
    bucket = var.tf_state_bucket
    prefix = "${var.env}/terraform/state"
  }
}

provider "google" {
  project = var.gcp_project
  region  = var.region
}

module "state_bucket" {
  source         = "./modules/bucket"
  gcp_project    = var.gcp_project
  region         = var.region
  bucket_name    = var.tf_state_bucket
  force_destroy  = true
  state_sa_email = var.state_sa_email
}

locals {
  code_bucket = module.state_bucket.bucket_name
}

resource "google_project_service" "run" {
  project             = var.gcp_project
  service             = "run.googleapis.com"
  disable_on_destroy  = false
}

resource "google_project_service" "cloudfunctions" {
  project             = var.gcp_project
  service             = "cloudfunctions.googleapis.com"
  disable_on_destroy  = false
}

module "word-counter" {
  source              = "./modules/cloud-function"
  gcp_project         = var.gcp_project
  region              = var.region
  bucket_name         = local.code_bucket
  function_name       = "word-counter"
  runtime             = "python39"
  entry_point         = "get_word_count"
  trigger_http        = true
  available_memory_mb = 1024
  timeout             = 300
  source_dir          = "${path.module}/../../services/src/function-word-counter"
  min_instances       = 0
  max_instances       = 10
  invoker_member      = var.invoker_member

  environment_variables = {
    ENVIRONMENT = var.env
  }

  depends_on = [
    google_project_service.cloudfunctions,
    google_project_service.run
  ]
}
