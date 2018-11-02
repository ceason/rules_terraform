variable replicas {
  description = "Desired # of ECS replicas"
  default     = 1
}

variable fargate_cpu {
  description = "Fargate instance CPU units to provision (1 vCPU = 1024 CPU units)"
  default     = "256"
}

variable fargate_memory {
  description = "Fargate instance memory to provision (in MiB)"
  default     = "512"
}

resource random_string uniqifier {
  length  = 5
  special = false
  upper   = false
}

locals {
  helloworld_unique_name = "helloworld-${random_string.uniqifier.result}"
}

data template_file ecs_task {
  template = "${file("${path.module}/ecs-task-containers.json")}"
  vars {
    CUSTOM_SERVER_MESSAGE = "${var.custom_server_message}"
  }
}

resource aws_ecs_task_definition hello_world {
  family                   = "${local.helloworld_unique_name}"
  container_definitions    = "${data.template_file.ecs_task.rendered}"
  cpu                      = "${var.fargate_cpu}"
  memory                   = "${var.fargate_memory}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
}

resource aws_ecs_service hello_world {
  name            = "${local.helloworld_unique_name}"
  task_definition = "${aws_ecs_task_definition.hello_world.arn}"
  desired_count   = "${var.replicas}"
  launch_type     = "FARGATE"
  cluster         = "${aws_ecs_cluster.helloworld.id}"

  #ordered_placement_strategy {
  #  type  = "spread"
  #  field = "attribute:ecs.availability-zone"
  #}

  load_balancer {
    target_group_arn = "${aws_lb_target_group.helloworld.arn}"
    container_name   = "server"
    container_port   = 8080
  }

  network_configuration {
    security_groups  = ["${aws_security_group.helloworld_ecs.id}"]
    subnets          = ["${var.subnet_ids}"]

    # todo: don't use public IP
    # need to set up NAT gateway so fargate can pull from registry (see https://github.com/aws/amazon-ecs-agent/issues/1128#issuecomment-354884572)
    assign_public_ip = true
  }

  #placement_constraints {
  #  type       = "memberOf"
  #  expression = "attribute:ecs.availability-zone in [${join(", ", local.availability_zones)}]"
  #  # todo: is this necessary? maybe AZ is implied by 'network_configuration.subnets' ?
  #}

  depends_on      = ["aws_lb_listener.helloworld"]
}

