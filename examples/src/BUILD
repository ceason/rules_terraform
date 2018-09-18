load("//terraform:def.bzl", "terraform_distribution_dir", "terraform_integration_test", "terraform_module", "terraform_workspace")

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
        "//terraform/plugins/kubectl",
    ],
)

terraform_module(
    name = "secret",
    srcs = ["secret.tf"],
    description = "This is an example terraform module, built with bazel!",
    visibility = ["//visibility:public"],
    deps = [
        ":authz",
        ":manifests",
    ],
)
