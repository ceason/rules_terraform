load("//terraform/internal:providers.bzl", "TerraformModuleInfo")
load("//terraform/internal:terraform_lib.bzl", "create_launcher")

def _terraform_k8s_manifest_impl(ctx):
    providers = []

    # write objects to individual files
    args = ctx.actions.args()
    args.add("--tf_filename", ctx.attr.name + ".tf")
    for f in ctx.attr.srcs:
        args.add("--file", f)
    out = ctx.actions.declare_file(ctx.attr.name + ".tar")
    args.add("--output", out)

    ctx.actions.run(
        inputs = ctx.attr.srcs,
        outputs = [out],
        executable = ctx.executable._k8s_tool,
        arguments = [args],
        tools = ctx.attr._k8s_tool.default_runfiles.files,
    )

    return providers + [
        TerraformModuleInfo(
            tar = out,
            modulepath = None,
            srcs = [],
            resolved_srcs = None,
            file_map = {},
            file_tars = depset(direct = [out]),
            plugins = depset(direct = [ctx.attr._kubectl_plugin]),
            modules = None,
        ),
        DefaultInfo(
            files = depset(direct = [out]),
        ),
    ]

terraform_k8s_manifest = rule(
    implementation = _terraform_k8s_manifest_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = [".yaml", ".json", ".yml"]),
        "_kubectl_plugin": attr.label(default = "//terraform/plugins/kubectl"),
        "_k8s_tool": attr.label(
            default = "//experimental/internal/k8s:k8s_manifest",
            executable = True,
            cfg = "host",
        ),
    },
)
