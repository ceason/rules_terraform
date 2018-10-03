resource random_string uniqifier {
  length  = 5
  special = false
  upper   = false
}

locals {
  test_message = "This is a custom message, configured in the test workspace! Our unique token for this run is '${random_string.uniqifier.result}'"
}

module hello_world {
  source                = "./module"
  custom_server_message = "${local.test_message}"
}

data kubectl_namespace current {}

resource local_file test_vars {
  filename = "test_vars.sh"
  content = <<EOF
NAMESPACE=${data.kubectl_namespace.current.id}
EXPECTED_OUTPUT="${local.test_message}"
EOF
}

