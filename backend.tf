terraform {
  # Local backend: stores state in the parent repo so it stays out of this
  # submodule. Switch to the remote backend below once you have an S3 bucket.
  backend "local" {
    path = "../terraform.tfstate"
  }

  # Remote backend (S3 or S3-compatible, e.g. MinIO). Comment out the local
  # backend above and fill in your values to use this instead.
  #
  # backend "s3" {
  #   bucket = "my-tofu-state"
  #   key    = "site/terraform.tfstate"
  #   region = "us-east-1"
  #
  #   # For MinIO or other S3-compatible stores:
  #   # endpoint                    = "https://minio.example.com"
  #   # force_path_style            = true
  #   # skip_credentials_validation = true
  #   # skip_metadata_api_check     = true
  #   # skip_region_validation      = true
  # }
}
