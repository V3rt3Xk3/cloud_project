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

provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.CloudKubernetesCluster.kube_config.0.host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.CloudKubernetesCluster.kube_config.0.client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.CloudKubernetesCluster.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.CloudKubernetesCluster.kube_config.0.cluster_ca_certificate)
  }
}

resource "helm_release" "ingress_nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.3.0"
  namespace  = kubernetes_namespace.cloud_namespace.metadata.0.name
  timeout    = 300

  values = [<<EOF
controller:
  admissionWebhooks:
    enabled: false
  electionID: ingress-controller-leader-internal
  ingressClass: nginx
  podLabels:
    app: ingress-nginx
  service:
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: nlb
  scope:
    enabled: true
rbac:
  scope: true
EOF
  ]
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