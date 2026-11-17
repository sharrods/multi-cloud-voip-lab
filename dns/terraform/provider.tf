# ==============================================================================
# Lab DNS - Provider Configuration
# Route 53 records for the multi-cloud VoIP lab (sharrodskinner.com)
# ==============================================================================

terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project      = "VoIP-Lab"
      ManagedBy    = "Terraform"
      Environment  = "Dev"
      DeployedFrom = "Azure"
      Owner        = "sdot"
    }
  }
}
