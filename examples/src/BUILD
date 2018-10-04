load("//terraform:def.bzl", "terraform_module")
load("@io_bazel_rules_docker//python:image.bzl", "py_image")
load("@io_bazel_rules_k8s//k8s:object.bzl", "k8s_object")

py_image(
    name = "py_image",
    srcs = ["server.py"],
    main = "server.py",
)

k8s_object(
    name = "deployment",
    image_chroot = "{STABLE_IMAGE_CHROOT}",
    images = {
        "hello-world-server:dev": ":py_image",
    },
    template = "server.yaml",
)

terraform_module(
    name = "hello-world",
    srcs = glob(["*.tf"]),
    description = "This is an example terraform module, built with bazel!",
    embed = [
        ":deployment",
    ],
    visibility = ["//visibility:public"],
)
