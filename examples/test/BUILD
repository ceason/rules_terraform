load("//terraform:def.bzl", "terraform_integration_test", "terraform_workspace")

terraform_workspace(
    name = "k8s-workspace",
    srcs = [
        "k8s.tf",
        "test_ws.tf",
    ],
    modules = {
        "module": "//examples/src:hello-world_k8s",
    },
)

terraform_workspace(
    name = "ecs-workspace",
    srcs = [
        "ecs.tf",
        "test_ws.tf",
    ],
    modules = {
        "module": "//examples/src:hello-world_ecs",
    },
)

sh_test(
    name = "e2e_test",
    srcs = ["e2e.sh"],
    tags = ["manual"],
)

terraform_integration_test(
    name = "k8s-e2e_integration_test",
    timeout = "short",
    srctest = ":e2e_test",
    tags = ["manual"],
    terraform_workspace = ":k8s-workspace",
)

terraform_integration_test(
    name = "ecs-e2e_integration_test",
    srctest = ":e2e_test",
    tags = ["manual"],
    terraform_workspace = ":ecs-workspace",
)
