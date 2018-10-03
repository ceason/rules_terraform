load("//terraform:def.bzl", "terraform_distribution_dir", "terraform_distribution_publisher", "terraform_module_publisher")

terraform_module_publisher(
    name = "publish",
    env = {
        "IMAGE_CHROOT": "index.docker.io/netchris",
    },
    prepublish_tests = [
        "//...",
        "//examples/test:e2e_integration_test",
    ],
    published_modules = {
        "mymodule": "//examples/src:hello-world",
    },
)
