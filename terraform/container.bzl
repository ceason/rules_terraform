load("//terraform:providers.bzl", _ModuleInfo = "ModuleInfo")
load("//terraform/internal:k8s.bzl", _terraform_k8s_manifest = "terraform_k8s_manifest")
load("//terraform/internal:image_embedder.bzl", _image_publisher = "image_publisher")
load(
    "//terraform/internal:image_embedder_lib.bzl",
    _embed_images = "embed_images",
    _image_embedder_attrs = "image_embedder_attrs",
)

terraform_k8s_manifest = _terraform_k8s_manifest
image_publisher = _image_publisher

def _image_embedder_impl(ctx):
    providers = []
    runfiles = []
    transitive_runfiles = []

    out = ctx.actions.declare_file("%s.%s" % (ctx.attr.name, ctx.file.src.extension))
    providers.append(_embed_images(
        ctx,
        out,
        input_files = [ctx.file.src],
        output_format = ctx.file.src.extension,
    ))

    return providers + [
        _ModuleInfo(files = {out.basename: out}),
        DefaultInfo(
            files = depset(direct = [out]),
            runfiles = ctx.runfiles(
                files = runfiles,
                transitive_files = depset(transitive = transitive_runfiles),
            ),
        ),
    ]

_image_embedder = rule(
    implementation = _image_embedder_impl,
    attrs = _image_embedder_attrs + {
        "src": attr.label(allow_single_file = [".yaml", ".json", ".yml"]),
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
