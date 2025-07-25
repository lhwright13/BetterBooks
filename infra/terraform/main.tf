terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "cluster" {
  source        = "./cluster"
  cluster_name  = var.cluster_name
  subnet_ids    = var.subnet_ids
  cluster_role_arn = var.cluster_role_arn
  node_role_arn    = var.node_role_arn
}

module "database" {
  source                   = "./database"
  identifier               = var.db_identifier
  username                 = var.db_username
  password                 = var.db_password
  instance_class           = var.db_instance_class
  subnet_ids               = var.subnet_ids
  vpc_security_group_ids   = [module.cluster.cluster_security_group]
}

variable "aws_region" {
  description = "AWS region"
}

variable "cluster_name" {
  default = "betterbooks"
}

variable "subnet_ids" {
  type = list(string)
}

variable "cluster_role_arn" {
  description = "IAM role for the EKS cluster"
}

variable "node_role_arn" {
  description = "IAM role for the worker nodes"
}

variable "db_identifier" {
  default = "betterbooks-db"
}

variable "db_username" {
  default = "betterbooks"
}

variable "db_password" {
  description = "Database password"
  sensitive   = true
}

variable "db_instance_class" {
  default = "db.t3.micro"
}

output "cluster_endpoint" {
  value = module.cluster.endpoint
}

output "db_endpoint" {
  value = module.database.endpoint
}
