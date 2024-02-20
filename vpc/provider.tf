terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = local.region
  profile = "hashport-tf-dev"
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name             = "vpc-sample"
  region           = "us-west-2"
  availablity_zone = data.aws_availability_zones.available.names[0]
  tags = {
    Project = local.name
    User    = "Hiroto"
  }
  cidr_block = "10.0.0.0/16"
  subnets = {
    public  = "10.0.1.0/24"
    private = "10.0.2.0/24"
  }
}
