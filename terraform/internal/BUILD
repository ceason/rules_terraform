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
