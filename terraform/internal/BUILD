# export the bzl files for the doc generator :-\
exports_files(glob([
    "*.tpl",
    "*.bzl",
]))

py_binary(
    name = "render_tf",
    srcs = ["render_tf.py"],
    visibility = ["//visibility:public"],
)

py_binary(
    name = "render_workspace",
    srcs = ["render_workspace.py"],
    visibility = ["//visibility:public"],
)

py_binary(
    name = "bundle",
    srcs = ["bundle.py"],
    visibility = ["//visibility:public"],
)

py_binary(
    name = "stamper",
    srcs = ["stamper.py"],
    visibility = ["//visibility:public"],
)

py_binary(
    name = "image_embedder",
    srcs = ["image_embedder.py"],
    visibility = ["//visibility:public"],
    deps = [
        "@containerregistry",
        "@yaml",
    ],
)

py_binary(
    name = "k8s",
    srcs = ["k8s.py"],
    visibility = ["//visibility:public"],
    deps = ["@yaml"],
)

py_binary(
    name = "k8s_manifest",
    srcs = ["k8s_manifest.py"],
    visibility = ["//visibility:public"],
    deps = ["@yaml"],
)
