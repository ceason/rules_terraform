load("//terraform:def.bzl", "terraform_integration_test", "terraform_module", "terraform_workspace")
load("@io_bazel_rules_k8s//k8s:object.bzl", "k8s_object")

terraform_workspace(
    name = "test-workspace",
    srcs = ["test_ws.tf"],
    modules = {
        "module": "//examples/src:hello-world",
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
    timeout = "short",
    flaky = 1,
    srctest = ":e2e_test",
    tags = [
        #"manual",
    ],
    terraform_workspace = ":test-workspace",
)
