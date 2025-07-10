terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  # Configurar backend remoto (opcional)
  # backend "s3" {
  #   bucket = "your-terraform-state-bucket"
  #   key    = "n8n/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "AgroValue-N8N"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
