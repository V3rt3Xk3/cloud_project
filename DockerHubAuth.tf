variable "docker_username" {
  description = "Docker username"
  type        = string
}

variable "docker_password" {
  description = "Docker password"
  type        = string
  sensitive   = true
}

variable "docker_server" {
  description = "Docker server"
  type        = string

}

variable "docker_email" {
  description = "Docker email"
  type        = string
}

resource "kubernetes_secret" "docker_credentials" {
  metadata {
    name      = "docker-cfg"
    namespace = kubernetes_namespace.cloud_namespace.metadata.0.name
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      "auths" = {
        "${var.docker_server}" = {
          "username" = var.docker_username
          "password" = var.docker_password
          "email"    = var.docker_email
          "auth"     = base64encode("${var.docker_username}:${var.docker_password}")
        }
      }
    })
  }
}