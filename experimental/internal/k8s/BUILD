exports_files(glob(["*.bzl"]))

filegroup(
    name = "bzl",
    srcs = glob(["*.bzl"]),
    visibility = ["//tools/docs:__pkg__"],
)

py_binary(
    name = "k8s_manifest",
    srcs = ["k8s_manifest.py"],
    visibility = ["//visibility:public"],
    deps = ["@py_yaml"],
)