variable subnet_ids {
  description = "List of subnets for the ECS task (eg one subnet per AZ). All subnets must be in the same VPC."
  type        = "list"
}

data aws_subnet ecs_task {
  count = "${length(var.subnet_ids)}"
  id    = "${var.subnet_ids[count.index]}"
}
locals {
  # grab the VPC id from one of the provided subnets
  vpc_id             = "${data.aws_subnet.ecs_task.0.vpc_id}"
  # get the list of AZs from the provided subnets
  availability_zones = "${sort(distinct(data.aws_subnet.ecs_task.*.availability_zone))}"
}


resource aws_iam_role helloworld {
  name_prefix           = "helloworld"
  force_detach_policies = true
  # language=json
  assume_role_policy    = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Action": "sts:AssumeRole",
    "Principal": {
      "Service": "ec2.amazonaws.com"
    },
    "Effect": "Allow",
    "Sid": ""
    }]
}
EOF
}

# LB Security group
# This is the group you need to edit if you want to restrict access to your application
resource aws_security_group helloworld_lb {
  name_prefix = "helloworld-lb"
  description = "controls access to the LB"
  vpc_id      = "${local.vpc_id}"

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Traffic to the ECS Cluster should only come from the ALB
resource aws_security_group helloworld_ecs {
  name_prefix = "helloworld-ecs-tasks"
  description = "allow inbound access from the LB only"
  vpc_id      = "${local.vpc_id}"

  ingress {
    protocol        = "tcp"
    from_port       = 0
    to_port         = 0
    security_groups = ["${aws_security_group.helloworld_lb.id}"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource aws_lb helloworld {
  name_prefix        = "hellow"
  internal           = false
  load_balancer_type = "application"
  subnets            = ["${var.subnet_ids}"]
  security_groups    = ["${aws_security_group.helloworld_lb.id}"]
}

resource aws_lb_target_group helloworld {
  name_prefix = "hellow"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = "${local.vpc_id}"
  target_type = "ip"
}

resource aws_lb_listener helloworld {
  load_balancer_arn = "${aws_lb.helloworld.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_lb_target_group.helloworld.arn}"
    type             = "forward"
  }
}

resource aws_ecs_cluster helloworld {
  name = "${local.helloworld_unique_name}"
}

output service_url {
  value = "http://${aws_lb.helloworld.dns_name}:80"
}
