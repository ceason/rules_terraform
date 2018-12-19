load("//terraform/internal:providers.bzl", "TerraformModuleInfo")
load("//terraform/internal:terraform_lib.bzl", "create_launcher")
load("//experimental/internal/embedding:embedder.bzl", "create_embedded_file")
load("@io_bazel_rules_docker//container:providers.bzl", "PushInfo")

def _terraform_k8s_manifest_impl(ctx):
    # embed image references
    resolved_manifest = ctx.actions.declare_file(ctx.attr.name + ".resolved-manifest.yaml")
    embedded = create_embedded_file(
        ctx,
        srcs = ctx.files.srcs,
        deps = ctx.attr.deps,
        output = resolved_manifest,
        output_delimiter = "\n---\n",
    )

    # write objects to individual files & bundle in a tar
    data_tar = ctx.actions.declare_file(ctx.attr.name + ".tar")
    args = ctx.actions.args()
    args.add("--tf_filename", ctx.attr.name + ".tf")
    args.add("--input", resolved_manifest)
    args.add("--output", data_tar)
    ctx.actions.run(
        inputs = [resolved_manifest],
        outputs = [data_tar],
        executable = ctx.executable._k8s_tool,
        arguments = [args],
        tools = ctx.attr._k8s_tool.default_runfiles.files,
    )

    return [
        TerraformModuleInfo(
            srcs = [],
            file_map = {},
            file_tars = depset(direct = [data_tar]),
            plugins = depset(direct = [ctx.attr._kubectl_plugin]),
        ),
        DefaultInfo(
            files = depset(direct = [data_tar]),
        ),
        OutputGroupInfo(
            content_publisher_executables = embedded.content_publisher_executables,
            content_publisher_runfiles = embedded.content_publisher_runfiles,
        ),
    ]

terraform_k8s_manifest = rule(
    _terraform_k8s_manifest_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = [".yaml", ".json", ".yml"]),
        "deps": attr.label_list(
            doc = "Embeddable targets (eg container_push).",
            providers = [
                [PushInfo],
            ],
            default = [],
        ),
        "_kubectl_plugin": attr.label(default = "//terraform/plugins/kubectl"),
        "_k8s_tool": attr.label(
            default = "//experimental/internal/k8s:k8s_manifest",
            executable = True,
            cfg = "host",
        ),
        "_embedder": attr.label(
            default = "//experimental/internal/embedding:embedder",
            cfg = "host",
            executable = True,
        ),
    },
)
