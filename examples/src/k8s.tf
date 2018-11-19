/**
 * A hello-world service that is designed to run on Kubernetes
 */
data kubectl_namespace current {}

resource kubernetes_config_map hello_world_server {
  metadata {
    name      = "hello-world-server"
    namespace = "${data.kubectl_namespace.current.id}"
  }

  data {
    CUSTOM_SERVER_MESSAGE = "${var.custom_server_message}"
  }
}


resource kubernetes_secret super_secret_string {
  metadata {
    name      = "super-secret-string"
    namespace = "${data.kubectl_namespace.current.id}"
  }

  data {
    password = "${random_string.password.result}"
  }
}