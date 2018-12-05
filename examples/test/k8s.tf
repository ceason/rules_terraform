module hello_world {
  source                = "//examples/src:hello-world_k8s"
  custom_server_message = "${local.test_message}"
}

data kubectl_namespace current {}

resource local_file test_vars {
  filename = "test_vars.sh"
  content = <<EOF
NAMESPACE=${data.kubectl_namespace.current.id}
EXPECTED_OUTPUT="${local.test_message}"
SERVICE_URL=http://hello-world-server.$NAMESPACE.svc.cluster.local
EOF
}
