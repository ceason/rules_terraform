load("@io_bazel_skydoc//skylark:skylark.bzl", "skylark_doc")

exports_files(glob(["*.tpl"]))

py_binary(
    name = "render_tf",
    srcs = ["render_tf.py"],
    visibility = ["//visibility:public"],
)

[skylark_doc(
    name = "docs-" + format,
    srcs = [
        "distribution_dir.bzl",
        "distribution_publisher.bzl",
        "integration_test.bzl",
        "module.bzl",
        "plugin.bzl",
        "workspace.bzl",
    ],
    format = format,
    strip_prefix = "terraform/internal",
    visibility = ["//visibility:public"],
) for format in [
    "html",
    "markdown",
]]
