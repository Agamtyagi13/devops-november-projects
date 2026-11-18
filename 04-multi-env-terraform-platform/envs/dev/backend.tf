terraform {
  backend "s3" {
    # bucket injected at init: terraform init -backend-config="bucket=<state_bucket>"
    key            = "dev/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "mep-tflock"
    encrypt        = true
  }
}
