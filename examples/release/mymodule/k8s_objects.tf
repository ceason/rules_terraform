
resource kubectl_generic_object hello-world-server_service {
    yaml = "${file("${path.module}/hello-world-server-service.yaml")}"
}

resource kubectl_generic_object hello-world-server_deployment {
    yaml = "${file("${path.module}/hello-world-server-deployment.yaml")}"
}
