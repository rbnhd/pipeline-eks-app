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
    # bucket = "bucket-to-store-terraform-state-pipeline-eks-app"
    # bucket = var.state_bucket
    # Partial configuration: the bucket name is provided dynamically
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

variable "state_bucket" {
  description = "S3 bucket to store terraform state"
  type        = string
}

variable "name_prefix" {
  description = "The naming prefix to use for naming the created resources (ex: sample-app-eks-subnet1)"
  type        = string
}

variable "eks_bucket" {
  description = "S3 bucket for the EKS app to access"
  type        = string
}

variable "k8s_version" {
  description = "The kubernetes version to use for EKS"
  type        = string
}

variable "instance_type" {
  description = "The Compute engine instance type to use in EKS node pool"
  type        = string
}
