load("//terraform:def.bzl", "terraform_integration_test", "terraform_workspace")

terraform_workspace(
    name = "test-workspace",
    srcs = ["test_ws.tf"],
    modules = {
        "module": "//examples/src:hello-world_k8s",
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
    #flaky = 1,
    srctest = ":e2e_test",
    # tags = ["manual"],
    terraform_workspace = ":test-workspace",
)
