# K8s Deployment for simple web app (nginxdemos/hello)
resource "kubernetes_deployment" "app" {
  metadata {
    name = "hello-app"
    labels = {
      app = "hello-app"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "hello-app"
      }
    }

    template {
      metadata {
        labels = {
          app = "hello-app"
        }
      }

      spec {
        container {
          name  = "hello-container"
          image = "nginxdemos/hello:latest"

          port {
            container_port = 80
          }

          resources {
            limits = {
              cpu    = "500m"
              memory = "256Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "64Mi"
            }
          }
        }
      }
    }
  }
}

# K8s Service of type NodePort to expose the app on port 30000
resource "kubernetes_service" "app_service" {
  metadata {
    name = "hello-service"
  }

  spec {
    selector = {
      app = kubernetes_deployment.app.metadata[0].labels.app
    }

    port {
      port        = 80
      target_port = 80
      node_port   = var.node_port
    }

    type = "NodePort"
  }
}
