terraform {
  # Local backend: stores state in the parent repo so it stays out of this
  # submodule. Switch to the remote backend below once you have an S3 bucket.
  backend "local" {
    path = "./terraform.tfstate"
  }

  # Remote backend (S3 or S3-compatible, e.g. MinIO/Garage). Comment out the
  # local backend above and fill in your values to use this instead.
  #
  # backend "s3" {
  #   bucket = "terraform"
  #   key    = "infra/terraform.tfstate"
  #   region = "garage"
  #
  #   endpoint       = "http://s3.example.lan:3900"
  #   use_path_style = true
  #
  #   skip_credentials_validation = true
  #   skip_metadata_api_check     = true
  #   skip_region_validation      = true
  # }
}
