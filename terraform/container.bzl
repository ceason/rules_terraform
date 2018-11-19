load("//terraform:providers.bzl", _ModuleInfo = "ModuleInfo")
load("//terraform/internal:k8s_manifest.bzl", "terraform_k8s_manifest")
load("//terraform/internal:image_embedder.bzl", "image_publisher")
load(
    "//terraform/internal:image_embedder_lib.bzl",
    _embed_images = "embed_images",
    _image_embedder_attrs = "image_embedder_attrs",
)

def _image_embedder_impl(ctx):
    providers = []

    out = ctx.actions.declare_file("%s.%s" % (ctx.attr.name, ctx.file.src.extension))
    providers.append(_embed_images(
        ctx,
        out,
        input_files = [ctx.file.src],
        output_format = ctx.file.src.extension,
    ))

    tar = ctx.actions.declare_file(ctx.attr.name + ".tar")
    bundle_args = ctx.actions.args()
    bundle_args.add("--output", tar)
    bundle_args.add("--file", [out.basename, out])
    ctx.actions.run(
        inputs = [out],
        outputs = [tar],
        arguments = [bundle_args],
        executable = ctx.executable._bundle_tool,
    )

    return providers + [
        _ModuleInfo(
            files = {out.basename: out},
            tar = tar,
        ),
        DefaultInfo(
            files = depset(direct = [out]),
        ),
    ]

_image_embedder = rule(
    implementation = _image_embedder_impl,
    attrs = _image_embedder_attrs + {
        "src": attr.label(allow_single_file = [".yaml", ".json", ".yml"]),
        "_bundle_tool": attr.label(
            default = Label("//terraform/internal:bundle"),
            executable = True,
            cfg = "host",
        ),
    },
)

def image_embedder(name, images = {}, **kwargs):
    """
    """
    for reserved in ["image_targets", "image_target_strings"]:
        if reserved in kwargs:
            fail("reserved for internal use by docker_bundle macro", attr = reserved)
    deduped_images = {s: None for s in images.values()}.keys()
    _image_embedder(
        name = name,
        images = images,
        image_targets = deduped_images,
        image_target_strings = deduped_images,
        **kwargs
    )
