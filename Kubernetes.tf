resource "kubernetes_ingress" "example_ingress" {
  metadata {
    name = "cloud-ingress"
  }

  spec {
    backend {
      service_name = kubernetes_service.frontend_service.metadata.0.name
      service_port = 80
    }

    rule {
      http {
        path {
          backend {
            service_name = kubernetes_service.backend_service.metadata.0.name
            service_port = 5000
          }

          path = "/api/*"
        }

        path {
          backend {
            service_name = kubernetes_service.frontend_service.metadata.0.name
            service_port = 80
          }

          path = "/*"
        }
      }
    }
  }
}

##########################
### Backend deployment ###
##########################

resource "kubernetes_deployment" "backend" {
  metadata {
    name = "backend-deployment"
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
        }
        image_pull_secrets {
          name = kubernetes_secret.docker_credentials.metadata[0].name
        }

      }
    }
  }
  depends_on = [
    kubernetes_secret.mongo_auth
  ]
}

resource "kubernetes_service" "backend_service" {
  metadata {
    name = "backend-service"
  }
  spec {
    selector = {
      App = kubernetes_deployment.backend.spec[0].template[0].metadata.0.labels.App
    }
    session_affinity = "ClientIP"
    port {
      port        = 80
      target_port = 5000
    }

    type = "LoadBalancer"
  }
}

resource "kubernetes_horizontal_pod_autoscaler" "backend_scaler" {
  metadata {
    name = "backend-scaler"
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
    name = "frontend-deployment"
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

        }
        image_pull_secrets {
          name = kubernetes_secret.docker_credentials.metadata[0].name
        }
      }
    }
  }
}

resource "kubernetes_service" "frontend_service" {
  metadata {
    name = "frontend-service"
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

    type = "LoadBalancer"
  }
}

resource "kubernetes_horizontal_pod_autoscaler" "frontend_scaler" {
  metadata {
    name = "frontend-scaler"
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
