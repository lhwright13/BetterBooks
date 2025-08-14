# Configure the Azure Resource Manager Provider
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

# Configure Azure Provider
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# Resource Group for all BetterBooks resources
resource "azurerm_resource_group" "betterbooks" {
  name     = var.resource_group_name
  location = var.location
  
  tags = {
    Environment = var.environment
    Project     = "BetterBooks"
    ManagedBy   = "Terraform"
  }
}

# Azure Kubernetes Service (AKS) Cluster
resource "azurerm_kubernetes_cluster" "betterbooks" {
  name                = var.cluster_name
  location            = azurerm_resource_group.betterbooks.location
  resource_group_name = azurerm_resource_group.betterbooks.name
  dns_prefix          = var.dns_prefix
  kubernetes_version  = var.kubernetes_version

  # Default node pool for system workloads
  default_node_pool {
    name                = "system"
    node_count          = var.system_node_count
    vm_size             = var.node_vm_size
    enable_auto_scaling = true
    min_count          = 1
    max_count          = 3
    
    # Use Azure CNI for better network performance
    vnet_subnet_id = azurerm_subnet.aks.id
    
    node_labels = {
      "nodepool-type" = "system"
      "environment"   = var.environment
      "nodepoolos"    = "linux"
    }
    
    tags = {
      "nodepool-type" = "system"
      "environment"   = var.environment
    }
  }

  # Identity for AKS cluster (Managed Identity recommended over Service Principal)
  identity {
    type = "SystemAssigned"
  }

  # Network profile for cluster networking
  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    load_balancer_sku = "standard"
    service_cidr      = "10.0.0.0/16"
    dns_service_ip    = "10.0.0.10"
  }

  # Enable monitoring and logging
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.betterbooks.id
  }

  tags = azurerm_resource_group.betterbooks.tags
}

# Additional node pool for application workloads
resource "azurerm_kubernetes_cluster_node_pool" "apps" {
  name                  = "apps"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.betterbooks.id
  vm_size              = var.app_node_vm_size
  node_count           = var.app_node_count
  
  enable_auto_scaling = true
  min_count          = 2
  max_count          = 5
  
  vnet_subnet_id = azurerm_subnet.aks.id
  
  node_labels = {
    "nodepool-type" = "application"
    "workload-type" = "microservices"
  }
  
  tags = {
    "nodepool-type" = "application"
    "environment"   = var.environment
  }
}

# Spot instance node pool for non-critical workloads (70% cost savings)
resource "azurerm_kubernetes_cluster_node_pool" "spot" {
  name                  = "spot"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.betterbooks.id
  vm_size              = var.spot_node_vm_size
  
  enable_auto_scaling = true
  min_count          = 0
  max_count          = 3
  node_count         = var.spot_node_count
  
  priority        = "Spot"
  eviction_policy = "Delete"
  spot_max_price  = -1  # Pay up to on-demand price
  
  vnet_subnet_id = azurerm_subnet.aks.id
  
  node_labels = {
    "nodepool-type"                  = "spot"
    "workload-type"                  = "batch"
    "kubernetes.azure.com/scalesetpriority" = "spot"
  }
  
  node_taints = [
    "kubernetes.azure.com/scalesetpriority=spot:NoSchedule"
  ]
  
  tags = {
    "nodepool-type" = "spot"
    "environment"   = var.environment
    "cost-optimization" = "enabled"
  }
}

# Virtual Network for AKS
resource "azurerm_virtual_network" "betterbooks" {
  name                = "${var.cluster_name}-vnet"
  location            = azurerm_resource_group.betterbooks.location
  resource_group_name = azurerm_resource_group.betterbooks.name
  address_space       = ["10.1.0.0/16"]
  
  tags = azurerm_resource_group.betterbooks.tags
}

# Subnet for AKS nodes
resource "azurerm_subnet" "aks" {
  name                 = "aks-subnet"
  resource_group_name  = azurerm_resource_group.betterbooks.name
  virtual_network_name = azurerm_virtual_network.betterbooks.name
  address_prefixes     = ["10.1.0.0/22"]
}

# Azure Container Registry for Docker images
resource "azurerm_container_registry" "betterbooks" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.betterbooks.name
  location            = azurerm_resource_group.betterbooks.location
  sku                 = "Standard"
  admin_enabled       = false
  
  tags = azurerm_resource_group.betterbooks.tags
}

# Grant AKS cluster access to ACR
resource "azurerm_role_assignment" "aks_acr" {
  principal_id                     = azurerm_kubernetes_cluster.betterbooks.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                           = azurerm_container_registry.betterbooks.id
  skip_service_principal_aad_check = true
}

# PostgreSQL Flexible Server with pgvector extension
resource "azurerm_postgresql_flexible_server" "betterbooks" {
  name                   = "${var.cluster_name}-psql"
  resource_group_name    = azurerm_resource_group.betterbooks.name
  location               = azurerm_resource_group.betterbooks.location
  version                = "14"
  administrator_login    = var.db_admin_username
  administrator_password = var.db_admin_password
  
  storage_mb = 32768
  sku_name   = "B_Standard_B1ms"
  
  backup_retention_days = 7
  geo_redundant_backup_enabled = false
  
  tags = azurerm_resource_group.betterbooks.tags
}

# Database for Context Service
resource "azurerm_postgresql_flexible_server_database" "context" {
  name      = "context_db"
  server_id = azurerm_postgresql_flexible_server.betterbooks.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

# Enable pgvector extension
resource "azurerm_postgresql_flexible_server_configuration" "extensions" {
  name      = "azure.extensions"
  server_id = azurerm_postgresql_flexible_server.betterbooks.id
  value     = "VECTOR,UUID-OSSP"
}

# Azure Redis Cache for session management
resource "azurerm_redis_cache" "betterbooks" {
  name                = "${var.cluster_name}-redis"
  location            = azurerm_resource_group.betterbooks.location
  resource_group_name = azurerm_resource_group.betterbooks.name
  capacity            = 0
  family              = "C"
  sku_name            = "Basic"
  
  minimum_tls_version = "1.2"
  
  redis_configuration {
    maxmemory_policy = "allkeys-lru"
  }
  
  tags = azurerm_resource_group.betterbooks.tags
}

# Storage Account for audiobook files
resource "azurerm_storage_account" "betterbooks" {
  name                     = "${replace(var.cluster_name, "-", "")}storage"
  resource_group_name      = azurerm_resource_group.betterbooks.name
  location                 = azurerm_resource_group.betterbooks.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  
  blob_properties {
    cors_rule {
      allowed_headers    = ["*"]
      allowed_methods    = ["GET", "HEAD", "POST", "PUT", "DELETE"]
      allowed_origins    = ["*"]
      exposed_headers    = ["*"]
      max_age_in_seconds = 3600
    }
  }
  
  tags = azurerm_resource_group.betterbooks.tags
}

# Blob container for audiobook files
resource "azurerm_storage_container" "audiobooks" {
  name                  = "audiobooks"
  storage_account_name  = azurerm_storage_account.betterbooks.name
  container_access_type = "blob"
}

# Log Analytics Workspace for monitoring
resource "azurerm_log_analytics_workspace" "betterbooks" {
  name                = "${var.cluster_name}-logs"
  location            = azurerm_resource_group.betterbooks.location
  resource_group_name = azurerm_resource_group.betterbooks.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  
  tags = azurerm_resource_group.betterbooks.tags
}

# Application Insights for APM
resource "azurerm_application_insights" "betterbooks" {
  name                = "${var.cluster_name}-appinsights"
  location            = azurerm_resource_group.betterbooks.location
  resource_group_name = azurerm_resource_group.betterbooks.name
  workspace_id        = azurerm_log_analytics_workspace.betterbooks.id
  application_type    = "web"
  
  tags = azurerm_resource_group.betterbooks.tags
}

# Configure Kubernetes provider to connect to AKS
provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.betterbooks.kube_config.0.host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.betterbooks.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.betterbooks.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.betterbooks.kube_config.0.cluster_ca_certificate)
}

# Configure Helm provider
provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.betterbooks.kube_config.0.host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.betterbooks.kube_config.0.client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.betterbooks.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.betterbooks.kube_config.0.cluster_ca_certificate)
  }
}

# Create namespace for BetterBooks services
resource "kubernetes_namespace" "betterbooks" {
  metadata {
    name = "betterbooks"
    
    labels = {
      name        = "betterbooks"
      environment = var.environment
      managed_by  = "terraform"
    }
  }
  
  depends_on = [azurerm_kubernetes_cluster.betterbooks]
}

# =================================================================
# Helm Chart Deployments (Optional - can be managed separately)
# =================================================================
# 
# The following sections show how to deploy BetterBooks services
# using Helm charts directly from Terraform. This is optional -
# you can also deploy Helm charts separately using kubectl/helm CLI.
#
# To deploy services with Helm after infrastructure is created:
# 1. Get AKS credentials: az aks get-credentials --resource-group <rg> --name <cluster>
# 2. Deploy each service: helm install <service> ../../../<service-chart-path> -n betterbooks
#
# Example Helm deployment from Terraform (uncomment to use):

# # Deploy API Gateway
# resource "helm_release" "api_gateway" {
#   name       = "api-gateway"
#   namespace  = kubernetes_namespace.betterbooks.metadata[0].name
#   chart      = "../../../api_gateway"
#   
#   values = [
#     yamlencode({
#       image = {
#         repository = "${azurerm_container_registry.betterbooks.login_server}/api-gateway"
#         tag        = var.app_version
#       }
#       service = {
#         type = "LoadBalancer"
#         port = 8000
#       }
#       env = {
#         LLM_GATEWAY_URL     = "http://llm-gateway:8002"
#         CONTEXT_SERVICE_URL = "http://context-service:8001"
#         TTS_SERVICE_URL     = "http://tts-service:8003"
#       }
#     })
#   ]
#   
#   depends_on = [
#     kubernetes_namespace.betterbooks,
#     azurerm_kubernetes_cluster_node_pool.apps
#   ]
# }

# Output important values for use with Helm deployments
output "kube_config" {
  value     = azurerm_kubernetes_cluster.betterbooks.kube_config_raw
  sensitive = true
}

output "cluster_name" {
  value = azurerm_kubernetes_cluster.betterbooks.name
}

output "resource_group_name" {
  value = azurerm_resource_group.betterbooks.name
}

output "acr_login_server" {
  value = azurerm_container_registry.betterbooks.login_server
}

output "postgresql_fqdn" {
  value = azurerm_postgresql_flexible_server.betterbooks.fqdn
}

output "redis_hostname" {
  value = azurerm_redis_cache.betterbooks.hostname
}

output "storage_account_name" {
  value = azurerm_storage_account.betterbooks.name
}

output "app_insights_instrumentation_key" {
  value     = azurerm_application_insights.betterbooks.instrumentation_key
  sensitive = true
}

# Instructions for next steps
output "next_steps" {
  value = <<-EOT
    
    ========================================
    BetterBooks Azure Infrastructure Created
    ========================================
    
    Next steps to deploy your applications:
    
    1. Get AKS credentials:
       az aks get-credentials --resource-group ${azurerm_resource_group.betterbooks.name} --name ${azurerm_kubernetes_cluster.betterbooks.name}
    
    2. Build and push Docker images:
       az acr build --registry ${azurerm_container_registry.betterbooks.name} --image api-gateway:latest ../../services/api_gateway/
       az acr build --registry ${azurerm_container_registry.betterbooks.name} --image llm-gateway:latest ../../services/llm_gateway/
       az acr build --registry ${azurerm_container_registry.betterbooks.name} --image context-service:latest ../../services/context_service/
       az acr build --registry ${azurerm_container_registry.betterbooks.name} --image tts-service:latest ../../services/tts_service/
    
    3. Deploy services with Helm:
       helm install api-gateway ../../../api_gateway -n betterbooks
       helm install llm-gateway ../../../llm_gateway -n betterbooks
       helm install context-service ../../../context_service -n betterbooks
       helm install tts-service ../../../tts_service -n betterbooks
    
    4. Check deployment status:
       kubectl get pods -n betterbooks
       kubectl get services -n betterbooks
    
    ========================================
  EOT
}