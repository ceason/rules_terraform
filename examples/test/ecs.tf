# get subnets in the default VPC to use for testing
data aws_vpc default {
  default = true
}
data aws_subnet_ids default_vpc {
  vpc_id = "${data.aws_vpc.default.id}"
}


module hello_world {
  source                = "@rules_terraform//examples/src:hello-world_ecs"
  custom_server_message = "${local.test_message}"
  subnet_ids            = ["${data.aws_subnet_ids.default_vpc.ids}"]
}

resource local_file test_vars {
  filename = "test_vars.sh"
  content  = <<EOF
EXPECTED_OUTPUT="${local.test_message}"
SERVICE_URL="${module.hello_world.service_url}"
EOF
}

output service_url {
  value = "${module.hello_world.service_url}"
}
