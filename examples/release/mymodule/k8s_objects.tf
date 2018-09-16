
resource kubectl_generic_object test-admin_serviceaccount {
    yaml = "${file("${path.module}/test-admin-serviceaccount.yaml")}"
}

resource kubectl_generic_object some-user_serviceaccount {
    yaml = "${file("${path.module}/some-user-serviceaccount.yaml")}"
}
