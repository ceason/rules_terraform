load("//terraform/experimental/ghrelease:def.bzl", "ghrelease", "ghrelease_assets", "ghrelease_test_suite")

VERSION = "0.2"

ghrelease(
    name = "release",
    args = ["--draft"],
    version = VERSION,
    deps = [
        ":prerelease-tests",
        ":tf-modules",
    ],
)

ghrelease_assets(
    name = "tf-modules",
    bazel_flags = ["--config=publish"],
    data = [
        "//examples/src:hello-world_ecs",
        "//examples/src:hello-world_k8s",
    ],
)

ghrelease_test_suite(
    name = "prerelease-tests",
    tests = [
        "//...",
        "//examples/test:k8s-e2e_integration_test",
        # "//examples/test:ecs-e2e_integration_test"
    ],
)
