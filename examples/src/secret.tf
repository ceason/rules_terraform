
resource random_string password {
  length  = 5
  special = false
  upper   = false
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