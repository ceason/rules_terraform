load(
    "//terraform/internal:image_embedder_lib.bzl",
    "create_image_publisher",
    "image_publisher_aspect",
    "image_publisher_attrs",
    "embed_images",
)

def _image_publisher_impl(ctx):
    """
    """
    runfiles = []
    transitive_runfiles = []

    transitive_runfiles.append(create_image_publisher(
        ctx,
        ctx.outputs.executable,
        ctx.attr.deps,
    ))
    return [DefaultInfo(
        runfiles = ctx.runfiles(
            files = runfiles,
            transitive_files = depset(transitive = transitive_runfiles),
        ),
    )]

image_publisher = rule(
    implementation = _image_publisher_impl,
    attrs = image_publisher_attrs + {
        "deps": attr.label_list(aspects = [image_publisher_aspect]),
    },
    executable = True,
)
