load("//terraform:def.bzl", "terraform_module", "terraform_workspace")
load("//terraform:container.bzl", "image_embedder", "terraform_k8s_manifest")
load("@io_bazel_rules_docker//python:image.bzl", "py_image")

py_image(
    name = "py_image",
    srcs = ["server.py"],
    main = "server.py",
)

terraform_k8s_manifest(
    name = "k8s-deployment",
    srcs = ["server.yaml"],
    image_chroot = "$(IMAGE_CHROOT)",
    images = {
        "hello-world-server:dev": ":py_image",
    },
)

image_embedder(
    name = "ecs-task-containers",
    src = "ecs-task-containers.tpl.json",
    image_chroot = "$(IMAGE_CHROOT)",
    images = {
        "hello-world-server:dev": ":py_image",
    },
)

terraform_module(
    name = "hello-world_k8s",
    srcs = [
        "k8s.tf",
        "main.tf",
    ],
    description = "A hello-world service that is designed to run on Kubernetes",
    embed = [":k8s-deployment"],
    visibility = ["//visibility:public"],
)

terraform_module(
    name = "hello-world_ecs",
    srcs = [
        "ecs.tf",
        "main.tf",
    ],
    description = "A hello-world service that is designed to run on ECS",
    embed = [":ecs-task-containers"],
    visibility = ["//visibility:public"],
)
