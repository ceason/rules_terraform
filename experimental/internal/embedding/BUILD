exports_files(glob(["*.bzl"]))

filegroup(
    name = "bzl",
    srcs = glob(["*.bzl"]),
    visibility = ["//tools/docs:__pkg__"],
)

py_binary(
    name = "embedder",
    srcs = ["embedder.py"],
    visibility = ["//visibility:public"],
)

py_binary(
    name = "casfile_url",
    srcs = ["casfile_url.py"],
    visibility = ["//visibility:public"],
)

py_binary(
    name = "casfile_publisher",
    srcs = ["casfile_publisher.py"],
    visibility = ["//visibility:public"],
    deps = ["@py_boto3"],
)
