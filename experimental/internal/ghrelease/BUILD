exports_files(glob(["*.bzl"]))

filegroup(
    name = "bzl",
    srcs = glob(["*.bzl"]),
    visibility = ["//tools/docs:__pkg__"],
)

[py_binary(
    name = f[:-len(".py")],
    srcs = [f],
    visibility = ["//visibility:public"],
    deps = [":lib"],
) for f in glob(["*_runner.py"])]

py_library(
    name = "lib",
    srcs = ["lib.py"],
    imports = [
        "rules_terraform/terraform/experimental/ghrelease/internal",
    ],
    deps = [
        "@py_semver",
    ],
)

py_test(
    name = "test",
    size = "small",
    srcs = ["test.py"],
    deps = [":lib"],
)
