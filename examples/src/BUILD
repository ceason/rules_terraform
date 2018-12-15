load("//experimental:k8s.bzl", "terraform_k8s_manifest")
load("//experimental:publishing.bzl", "embedded_reference", "file_uploader")
load("//terraform:def.bzl", "terraform_module")
load("@io_bazel_rules_docker//container:container.bzl", "container_push")
load("@io_bazel_rules_docker//python:image.bzl", "py_image")

py_image(
    name = "py_image",
    srcs = ["server.py"],
    main = "server.py",
)

container_push(
    name = "push_py_image",
    format = "Docker",
    image = ":py_image",
    registry = "$(IMAGE_REGISTRY)",
    repository = "hello-world-server",
    stamp = True,
    tag = "dev",
    visibility = ["//visibility:public"],
)

terraform_k8s_manifest(
    name = "k8s-deployment",
    srcs = ["server.yaml"],
    deps = [
        ":push_py_image",
    ],
)

embedded_reference(
    name = "ecs-task-containers",
    src = "ecs-task-containers.json.tpl",
    out = "ecs-task-containers.json",
    deps = [
        ":push_py_image",
    ],
)

terraform_module(
    name = "hello-world_k8s",
    srcs = [
        "k8s.tf",
        "main.tf",
    ],
    embed = [":k8s-deployment"],
    visibility = ["//visibility:public"],
)

terraform_module(
    name = "hello-world_ecs",
    srcs = [
        "ecs.tf",
        "ecs-plumbing.tf",
        "main.tf",
    ],
    data = [
        ":ecs-task-containers",
    ],
    visibility = ["//visibility:public"],
)
