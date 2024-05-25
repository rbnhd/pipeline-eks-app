terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.50.0"
    }
  }
  required_version = ">=1.0"
}

# Although it's possible to create the backend storage location at runtime itself, it's a good idea to create the bucket...
# ... where state file will be stored beforehand and set the bucket as the location for TF state file.....
# .... so that resource state are always consistent
terraform {
  backend "s3" {
    # Partial configuration: the bucket name is provided dynamically during terraform init as param -backend-config=${}
    key = "terraform/state"
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

variable "k8s_version" {
  description = "The kubernetes version to use for EKS"
  type        = string
}

variable "instance_type" {
  description = "The Compute engine instance type to use in EKS node pool"
  type        = string
}
