load(
    "@io_bazel_rules_docker//container:layer_tools.bzl",
    _get_layers = "get_from_target",
    _layer_tools = "tools",
)
load(
    "@io_bazel_rules_docker//skylib:label.bzl",
    _string_to_label = "string_to_label",
)
load(":terraform_lib.bzl", "create_launcher", "runfiles_path")

def _resolve(ctx, string, output):
    stamps = [ctx.info_file, ctx.version_file]
    stamp_args = [
        "--stamp-info-file=%s" % sf.path
        for sf in stamps
    ]
    ctx.actions.run(
        executable = ctx.executable._stamper,
        arguments = [
            "--format=%s" % string,
            "--output=%s" % output.path,
        ] + stamp_args,
        inputs = [ctx.executable._stamper] + stamps,
        outputs = [output],
        mnemonic = "Stamp",
    )

def create_image_resolver(ctx, output, input_files = [], **kwargs):
    """
    Creates an image resolver executable.
    Returns depset of files (for adding to runfiles)
    """

    runfiles = []
    transitive_runfiles = []
    image_specs = []
    if ctx.attr.images:
        # Compute the set of layers from the image_targets.
        image_target_dict = _string_to_label(
            ctx.attr.image_targets,
            ctx.attr.image_target_strings,
        )

        # Walk the collection of images passed and for each key/value pair
        # collect the parts to pass to the resolver as --image_spec arguments.
        # Each images entry results in a single --image_spec argument.
        # As part of this walk, we also collect all of the image's input files
        # to include as runfiles, so they are accessible to be pushed.
        for tag in ctx.attr.images:
            target = ctx.attr.images[tag]
            image = _get_layers(ctx, ctx.label.name, image_target_dict[target])

            image_spec = {"name": tag}
            if image.get("legacy"):
                image_spec["tarball"] = runfiles_path(ctx, image["legacy"])
                runfiles += [image["legacy"]]

            blobsums = image.get("blobsum", [])
            image_spec["digest"] = ",".join([runfiles_path(ctx, f) for f in blobsums])
            runfiles += blobsums

            blobs = image.get("zipped_layer", [])
            image_spec["layer"] = ",".join([runfiles_path(ctx, f) for f in blobs])
            runfiles += blobs

            image_spec["config"] = runfiles_path(ctx, image["config"])
            runfiles += [image["config"]]

            image_specs += [";".join([
                "%s=%s" % (k, v)
                for (k, v) in image_spec.items()
            ])]

    image_chroot_arg = ctx.attr.image_chroot
    image_chroot_arg = ctx.expand_make_variables("image_chroot", image_chroot_arg, {})
    if "{" in ctx.attr.image_chroot:
        image_chroot_file = ctx.new_file(ctx.label.name + ".image-chroot-name")
        _resolve(ctx, ctx.attr.image_chroot, image_chroot_file)
        image_chroot_arg = "$(cat %s)" % runfiles_path(ctx, image_chroot_file)
        runfiles += [image_chroot_file]

    image_tag_arg = ctx.attr.image_tag
    image_tag_arg = ctx.expand_make_variables("image_tag", image_tag_arg, {})
    if "{" in ctx.attr.image_tag:
        image_tag_file = ctx.new_file(ctx.label.name + ".image-tag-name")
        _resolve(ctx, ctx.attr.image_tag, image_tag_file)
        image_tag_arg = "$(cat %s)" % runfiles_path(ctx, image_tag_file)
        runfiles += [image_tag_file]

    args = [ctx.executable._image_resolver]
    transitive_runfiles.append(ctx.attr._image_resolver.default_runfiles.files)

    # convert kwargs to args
    for arg, value in kwargs.items():
        args.append("--%s=%s" % (arg, value))

    args.append("--image_chroot=%s" % image_chroot_arg)
    args.append("--image_tag=%s" % image_tag_arg)
    for spec in image_specs:
        args.append("--image_spec=%s" % spec)
    for file in input_files:
        args.append("--template=%s" % runfiles_path(ctx, file))
        runfiles.append(file)

    create_launcher(ctx, output, args)
    return depset(direct = runfiles, transitive = transitive_runfiles)

image_resolver_attrs = _layer_tools + {
    "image_chroot": attr.string(),
    "image_tag": attr.string(),
    "images": attr.string_dict(),
    # Implicit dependencies.
    "image_targets": attr.label_list(allow_files = True),
    "image_target_strings": attr.string_list(),
    "_image_resolver": attr.label(
        default = Label("//terraform/internal:image_resolver"),
        cfg = "host",
        executable = True,
        allow_files = True,
    ),
    "_stamper": attr.label(
        default = Label("//terraform/internal:stamper"),
        cfg = "host",
        executable = True,
        allow_files = True,
    ),
}
