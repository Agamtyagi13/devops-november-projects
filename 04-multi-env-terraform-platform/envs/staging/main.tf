terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }
}
provider "aws" {
  region = "ap-south-1"
  default_tags {
    tags = {
      Environment = "staging"
      Project     = "mep"
      ManagedBy   = "terraform"
    }
  }
}

module "network" {
  source     = "../../modules/network"
  name       = "mep-staging"
  cidr       = var.cidr
  enable_nat = var.enable_nat
}
module "workload" {
  source         = "../../modules/workload"
  name           = "mep-staging"
  vpc_id         = module.network.vpc_id
  subnet_id      = module.network.private_subnet_ids[0]
  instance_type  = var.instance_type
  instance_count = var.instance_count
}
output "vpc_id" {
  value = module.network.vpc_id
}
