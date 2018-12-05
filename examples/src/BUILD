load("//terraform:def.bzl", "terraform_module")
load("//terraform:container.bzl", "image_embedder", "terraform_k8s_manifest")
load("@io_bazel_rules_docker//python:image.bzl", "py_image")
load("@io_bazel_rules_docker//container:container.bzl", "container_push")
load("//experimental/cas:def.bzl", "content_addressable_file", "embedded_reference")

py_image(
    name = "py_image",
    srcs = ["server.py"],
    main = "server.py",
)

container_push(
    name = "push_py_image",
    format = "Docker",
    image = ":py_image",
    registry = "index.docker.io",
    repository = "netchris/hello-world-server",
    stamp = True,
    tag = "dev",
    visibility = ["//visibility:public"],
)

terraform_k8s_manifest(
    name = "k8s-deployment",
    srcs = ["server.yaml"],
    image_chroot = "$(IMAGE_CHROOT)",
    images = {
        "hello-world-server:dev": ":py_image",
    },
)

embedded_reference(
    name = "ecs-task-containers",
    src = "ecs-task-containers.tpl.json",
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
        ":ecs-task-containers",
    ],
    #embed = [":ecs-task-containers"],
    visibility = ["//visibility:public"],
)
