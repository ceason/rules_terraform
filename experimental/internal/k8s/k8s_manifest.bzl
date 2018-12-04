load("//terraform:providers.bzl", "ModuleInfo")
load("//terraform/internal:content_publisher.bzl", "embed_images", "image_embedder_attrs", "runfiles_path")
load("//terraform/internal:terraform_lib.bzl", "create_launcher")

def _terraform_k8s_manifest_impl(ctx):
    providers = []

    # create a file generator that resolves image references
    # & writes objects to individual files
    embedded = ctx.actions.declare_file("%s.embedded-manifests.yaml" % ctx.attr.name)
    providers.append(embed_images(
        ctx,
        embedded,
        input_files = ctx.files.srcs,
        output_format = "yaml",
    ))

    args = ctx.actions.args()
    args.add("--tf_filename", ctx.attr.name + ".tf")
    args.add("--file", embedded)
    out = ctx.actions.declare_file(ctx.attr.name + ".tar")
    args.add("--output", out)

    ctx.actions.run(
        inputs = [embedded],
        outputs = [out],
        executable = ctx.executable._k8s_tool,
        arguments = [args],
        tools = ctx.attr._k8s_tool.default_runfiles.files,
    )

    return providers + [
        ModuleInfo(
            tar = out,
            plugins = depset(direct = [ctx.attr._kubectl_plugin]),
        ),
        DefaultInfo(
            files = depset(direct = [out]),
        ),
    ]

_terraform_k8s_manifest = rule(
    implementation = _terraform_k8s_manifest_impl,
    attrs = image_embedder_attrs + {
        "srcs": attr.label_list(allow_files = [".yaml", ".json", ".yml"]),
        "_kubectl_plugin": attr.label(default = "//terraform/plugins/kubectl"),
        "_k8s_tool": attr.label(
            default = "//terraform/internal:k8s_manifest",
            executable = True,
            cfg = "host",
        ),
    },
)

def terraform_k8s_manifest(name, images = {}, **kwargs):
    """
    """
    for reserved in ["image_targets", "image_target_strings"]:
        if reserved in kwargs:
            fail("reserved for internal use by docker_bundle macro", attr = reserved)
    deduped_images = {s: None for s in images.values()}.keys()
    _terraform_k8s_manifest(
        name = name,
        images = images,
        image_targets = deduped_images,
        image_target_strings = deduped_images,
        **kwargs
    )
