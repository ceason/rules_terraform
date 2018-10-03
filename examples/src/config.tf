data kubectl_namespace current {}

variable custom_server_message {
  default     = "Hello, world!"
  description = "The server will respond to all HTTP requests with this message"
}

resource kubernetes_config_map hello_world_server {
  metadata {
    name      = "hello-world-server"
    namespace = "${data.kubectl_namespace.current.id}"
  }

  data {
    CUSTOM_SERVER_MESSAGE = "${var.custom_server_message}"
  }
}