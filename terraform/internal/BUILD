load("@io_bazel_skydoc//skylark:skylark.bzl", "skylark_doc")

exports_files(glob(["*.tpl"]))

py_binary(
    name = "render_tf",
    srcs = ["render_tf.py"],
    visibility = ["//visibility:public"],
)

DOC_SRCS = [
    "distribution.bzl",
    "test.bzl",
    "terraform.bzl",
]

skylark_doc(
    name = "docs-markdown",
    srcs = DOC_SRCS,
    format = "markdown",
    strip_prefix = "terraform/internal",
    visibility = ["//visibility:public"],
    overview_filename = "README",
)

skylark_doc(
    name = "docs-html",
    srcs = DOC_SRCS,
    format = "html",
    strip_prefix = "terraform/internal",
    visibility = ["//visibility:public"],
    site_root = "rules_terraform",
)
