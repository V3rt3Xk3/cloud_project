terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.11.0"
    }
  }
}

provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.CloudKubernetesCluster.kube_config.0.host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.CloudKubernetesCluster.kube_config.0.client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.CloudKubernetesCluster.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.CloudKubernetesCluster.kube_config.0.cluster_ca_certificate)
  }
}

resource "helm_release" "nginix_ingress" {
  name       = "nginx-ingress"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "nginx"
  namespace  = "kube-system"
}


# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }

  subscription_id = "2a60ecc9-354f-4786-8d44-4d27d0f40a15"
}

# Kubernetes provider
provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.CloudKubernetesCluster.kube_config.0.host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.CloudKubernetesCluster.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.CloudKubernetesCluster.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.CloudKubernetesCluster.kube_config.0.cluster_ca_certificate)
}

resource "kubernetes_namespace" "cloud_namespace" {
  metadata {
    labels = {
      app = "cloud"
    }
    name = "cloud"
  }
}

resource "azurerm_resource_group" "CloudProject" {
  name     = "CloudProject"
  location = "West Europe"
}

resource "azurerm_kubernetes_cluster" "CloudKubernetesCluster" {
  name                = "cloud_project_kubernetes_cluster"
  location            = azurerm_resource_group.CloudProject.location
  resource_group_name = azurerm_resource_group.CloudProject.name
  dns_prefix          = "cloud"

  default_node_pool {
    name                = "nodepool"
    vm_size             = "Standard_B2s"
    enable_auto_scaling = true
    min_count           = 1
    max_count           = 5
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "Production"
  }

  http_application_routing_enabled = true
}



output "kubernetes_client_certificate" {
  value     = azurerm_kubernetes_cluster.CloudKubernetesCluster.kube_config.0.client_certificate
  sensitive = true
}

output "kubernetes_config" {
  value     = azurerm_kubernetes_cluster.CloudKubernetesCluster.kube_config_raw
  sensitive = true
}

output "kubernetes_dns" {
  value     = azurerm_kubernetes_cluster.CloudKubernetesCluster.kube_config.0.host
  sensitive = true
}