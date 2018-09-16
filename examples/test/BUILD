load("@rules_terraform//terraform:def.bzl", "terraform_integration_test", "terraform_module", "terraform_workspace", "terraform_distribution_dir")
load("@io_bazel_rules_k8s//k8s:object.bzl", "k8s_object")

terraform_workspace(
    name = "test-workspace",
    srcs = ["test_ws.tf"],
    modules = {
        "//examples/src:secret": "module",
    },
)

sh_test(
    name = "e2e_test",
    srcs = ["e2e.sh"],
    tags = [
        "manual",
    ],
)

terraform_integration_test(
    name = "e2e_integration_test",
    srctest = ":e2e_test",
    terraform_workspace = ":test-workspace",
    tags = [
        "manual",
    ],
)