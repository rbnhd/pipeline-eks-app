terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.50.0"
    }
  }
  required_version = ">=1.0"
}

terraform {
  backend "s3" {
    bucket = "bucket-to-store-terraform-state-pipeline-eks-app"
    key    = "terraform/state"
  }
}

provider "aws" {
  region = var.region
}

variable "region" {
  description = "The AWS region where resources should be created"
  type        = string
  default     = "ap-northeast-1"
}

variable "name_prefix" {
  description = "The naming prefix to use for naming the created resources (ex: sample-app-eks-subnet1)"
  type        = string
}

variable "eks_bucket" {
  description = "S3 bucket for the EKS app to access"
  type        = string
}
