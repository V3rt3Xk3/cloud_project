resource "kubernetes_ingress_v1" "cloud_ingress" {
  wait_for_load_balancer = true
  metadata {
    name      = "cloud-ingress"
    namespace = kubernetes_namespace.cloud_namespace.metadata.0.name
    annotations = {
      "kubernetes.io/ingress.class" = "addon-http-application-routing"
    }
  }
  spec {
    rule {
      http {
        path {
          path      = "/api/*"
          path_type = "Prefix"
          backend {
            service {
              name = "backend-service"
              port {
                number = 80
              }
            }
          }
        }

        path {
          path = "/*"
          backend {
            service {
              name = "frontend-service"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
  depends_on = [
    helm_release.nginix_ingress
  ]
}



##########################
### Backend deployment ###
##########################

resource "kubernetes_deployment" "backend" {
  metadata {
    name      = "backend-deployment"
    namespace = kubernetes_namespace.cloud_namespace.metadata.0.name
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        App = "backend"
      }
    }

    template {
      metadata {
        labels = {
          App = "backend"
        }
      }

      spec {
        container {
          image = "v3rt1ke/mindentudoter:backend"
          name  = "backend"

          env {
            name = "COSMOSDB_MONGO_CONNECTIONSTRING"

            value_from {
              secret_key_ref {
                name = "mongo-auth"
                key  = "connection"
              }
            }
          }
          env {
            name  = "CORS_URL"
            value = kubernetes_ingress_v1.cloud_ingress.status.0.load_balancer.0.ingress.0.ip
          }
        }
        image_pull_secrets {
          name = kubernetes_secret.docker_credentials.metadata[0].name
        }

      }
    }
  }
  depends_on = [
    kubernetes_secret.mongo_auth,
    kubernetes_ingress_v1.cloud_ingress,
    kubernetes_secret.docker_credentials,
    azurerm_kubernetes_cluster.CloudKubernetesCluster
  ]
}

resource "kubernetes_service" "backend_service" {
  metadata {
    name      = "backend-service"
    namespace = kubernetes_namespace.cloud_namespace.metadata.0.name
  }
  spec {
    selector = {
      App = kubernetes_deployment.backend.spec[0].template[0].metadata.0.labels.App
    }
    session_affinity = "ClientIP"
    port {
      port        = 80
      target_port = 80
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_horizontal_pod_autoscaler" "backend_scaler" {
  metadata {
    name      = "backend-scaler"
    namespace = kubernetes_namespace.cloud_namespace.metadata.0.name
  }
  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.backend.metadata.0.name
    }
    min_replicas                      = 2
    max_replicas                      = 10
    target_cpu_utilization_percentage = 50

  }
}

###########################
### Frontend deployment ###
###########################

resource "kubernetes_deployment" "frontend" {
  metadata {
    name      = "frontend-deployment"
    namespace = kubernetes_namespace.cloud_namespace.metadata.0.name
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        App = "frontend"
      }
    }

    template {
      metadata {
        labels = {
          App = "frontend"
        }
      }

      spec {
        container {
          image = "v3rt1ke/mindentudoter:frontend"
          name  = "frontend"

          env {
            name  = "VITE_BACKEND_URL"
            value = "http://${kubernetes_ingress_v1.cloud_ingress.status.0.load_balancer.0.ingress.0.ip}"
          }
        }
        image_pull_secrets {
          name = kubernetes_secret.docker_credentials.metadata[0].name
        }
      }
    }
  }
  depends_on = [
    kubernetes_secret.docker_credentials,
    kubernetes_ingress_v1.cloud_ingress,
    azurerm_kubernetes_cluster.CloudKubernetesCluster
  ]
}

resource "kubernetes_service" "frontend_service" {
  metadata {
    name      = "frontend-service"
    namespace = kubernetes_namespace.cloud_namespace.metadata.0.name
  }
  spec {
    selector = {
      App = kubernetes_deployment.frontend.spec[0].template[0].metadata.0.labels.App
    }
    session_affinity = "ClientIP"
    port {
      port        = 80
      target_port = 80
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_horizontal_pod_autoscaler" "frontend_scaler" {
  metadata {
    name      = "frontend-scaler"
    namespace = kubernetes_namespace.cloud_namespace.metadata.0.name
  }
  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.frontend.metadata.0.name
    }
    min_replicas                      = 2
    max_replicas                      = 10
    target_cpu_utilization_percentage = 50
  }
}

output "ingress_hostname" {
  value     = kubernetes_ingress_v1.cloud_ingress.status.0.load_balancer.0.ingress.0.ip
  sensitive = true
}