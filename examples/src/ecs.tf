variable image_registry_credentials_arn {
  description = "AWS SecretsManager ARN of image registry credentials, used by ECS"
  default     = ""
}

data template_file ecs_task {
  template = "${file("${path.module}/ecs-task-containers.json")}"
  vars {
    ecs_repository_credentials_parameter = "${var.image_registry_credentials_arn}"
  }
}


resource aws_ecs_task_definition service {
  family                = "service"
  container_definitions = "${data.template_file.ecs_task.rendered}"

}
