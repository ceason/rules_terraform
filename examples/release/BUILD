load("//terraform:def.bzl", "terraform_distribution_dir", "terraform_distribution_publisher")

terraform_distribution_publisher(
    name = "publish",
    env = {
        "IMAGE_CHROOT": "index.docker.io/netchris",
    },
    prepublish_builds = ["//..."],
    prepublish_tests = [
        "//...",
        "//examples/test:e2e_integration_test",
    ],
    deps = [
        ":mymodule",
    ],
)

terraform_distribution_dir(
    name = "mymodule",
    description = "This is an example terraform module, built with bazel!",
    deps = [
        "//examples/src:secret",
    ],
)
