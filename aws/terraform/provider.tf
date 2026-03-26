# ==============================================================================
# AWS VoIP Lab - Provider Configuration
# ==============================================================================

terraform {
  required_version = ">= 1.0"
  
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
