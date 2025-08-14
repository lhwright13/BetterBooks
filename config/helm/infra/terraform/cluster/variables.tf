# Variables for BetterBooks Azure AKS Infrastructure
# These variables allow customization of the infrastructure deployment

variable "resource_group_name" {
  description = "Name of the Azure Resource Group"
  type        = string
  default     = "betterbooks-rg"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "East US"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
  default     = "betterbooks-aks"
}

variable "dns_prefix" {
  description = "DNS prefix for the AKS cluster"
  type        = string
  default     = "betterbooks"
}

variable "kubernetes_version" {
  description = "Kubernetes version for AKS"
  type        = string
  default     = "1.27.7"
}

variable "system_node_count" {
  description = "Number of nodes in the system node pool"
  type        = number
  default     = 1
}

variable "app_node_count" {
  description = "Initial number of nodes in the application node pool"
  type        = number
  default     = 2
}

variable "node_vm_size" {
  description = "VM size for system nodes"
  type        = string
  default     = "Standard_B2s"
}

variable "app_node_vm_size" {
  description = "VM size for application nodes"
  type        = string
  default     = "Standard_B2ms"
}

variable "acr_name" {
  description = "Name of the Azure Container Registry (must be globally unique)"
  type        = string
  default     = "betterbooksacr"
}

variable "db_admin_username" {
  description = "Administrator username for PostgreSQL"
  type        = string
  default     = "bbadmin"
  sensitive   = true
}

variable "db_admin_password" {
  description = "Administrator password for PostgreSQL"
  type        = string
  sensitive   = true
}

variable "app_version" {
  description = "Version tag for application Docker images"
  type        = string
  default     = "latest"
}

variable "spot_node_count" {
  description = "Initial number of spot instance nodes"
  type        = number
  default     = 1
}

variable "spot_node_vm_size" {
  description = "VM size for spot instance nodes"
  type        = string
  default     = "Standard_B2s"
}