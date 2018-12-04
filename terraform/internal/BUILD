# export the bzl files for the doc generator :-\
exports_files(glob([
    "*.tpl",
    "*.bzl",
]))

py_binary(
    name = "render_workspace",
    srcs = ["render_workspace.py"],
    visibility = ["//visibility:public"],
)

py_binary(
    name = "create_root_bundle",
    srcs = ["create_root_bundle.py"],
    visibility = ["//visibility:public"],
)

py_binary(
    name = "resolve_srcs",
    srcs = ["resolve_srcs.py"],
    visibility = ["//visibility:public"],
)

py_binary(
    name = "bundle",
    srcs = ["bundle.py"],
    visibility = ["//visibility:public"],
)
