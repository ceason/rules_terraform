load("@rules_terraform//terraform:def.bzl", "terraform_integration_test", "terraform_module", "terraform_workspace", "terraform_distribution_dir")
#load("@io_bazel_rules_k8s//k8s:object.bzl", "k8s_object")
load("@k8s_object//:defaults.bzl", "k8s_object")

k8s_object(
    name = "manifests",
    template = "manifests.yaml",
)

terraform_module(
    name = "authz",
    srcs = ["authz.tf"],
    plugins = [
        "@rules_terraform//terraform/plugins/kubectl",
    ],
)

terraform_module(
    name = "secret",
    srcs = ["secret.tf"],
    deps = [
        ":authz",
        ":manifests",
    ],
    visibility = ["//visibility:public"]
)