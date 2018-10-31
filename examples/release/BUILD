load("//terraform:def.bzl", "terraform_module_publisher")

terraform_module_publisher(
    name = "publish",
    bazelrc_config = "publish",
    prepublish_tests = [
        "//...",
        "//examples/test:k8s-e2e_integration_test",
    ],
    published_modules = {
        "mymodule": "//examples/src:hello-world_k8s",
    },
)
