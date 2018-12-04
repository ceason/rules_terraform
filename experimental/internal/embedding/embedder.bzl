load("@io_bazel_rules_docker//container:providers.bzl", "PushInfo")
load("//experimental/internal:providers.bzl", "EmbeddedContentInfo", "ContentPublisherInfo")

def _get_valid_labels(ctx, embed_label):
    """
    Returns a list of valid replacement strings for this target; eg:
    - @rules_terraform//package:target  ..whenever target belongs to a named workspace (could be current workspace)
    - //package:target                  ..whenever target and ctx are in the same workspace
    - :target                           ..whenever target and ctx are in the same workspace+package
    """

    # TODO(ceason): what is the canonical method for identifying external label? because this probably isn't it.
    valid = []
    tgt_in_different_workspace = False
    label_str = str(embed_label)
    if label_str.startswith("@") and not label_str.startswith("@%s//" % ctx.workspace_name):
        # tgt is in different workspace
        valid += [label_str]
    elif embed_label.workspace_root.startswith("external/"):
        # tgt is in different workspace
        ws_name = embed_label.workspace_root[len("external/"):]
        valid += ["@%s//%s:%s" % (ws_name, embed_label.package, embed_label.name)]
    else:
        # target is in same workspace as ctx
        valid += ["//%s:%s" % (embed_label.package, embed_label.name)]
        if ctx.workspace_name:
            valid += ["@%s//%s:%s" % (ctx.workspace_name, embed_label.package, embed_label.name)]
        if ctx.label.package == embed_label.package:
            valid += [":" + embed_label.name]
    return valid

def _impl(ctx):
    """
    """
    content_publishers = []

    args = ctx.actions.args()
    inputs = [ctx.file.src]
    args.add("--template", ctx.file.src)
    args.add("--output", ctx.outputs.out)
    requires_stamping = False
    for dep in ctx.attr.deps:
        valid_labels = _get_valid_labels(ctx, dep.label)
        if ContentPublisherInfo in dep:
            content_publishers += [dep]
            # TODO: make sure target is executable & fail early if it's not
            info = dep[ContentPublisherInfo]
            inputs += [info.published_location]
            args.add("--content_addressable_file", struct(
                label = str(ctx.label),
                valid_labels = valid_labels,
                published_location_file = info.published_location,
            ).to_json())
        # TODO: move this to "container_push wrapper"
        if PushInfo in dep:
            container_pushes += [dep]
            p = dep[PushInfo]
            inputs += [p.digest]
            args.add("--container_push", struct(
                valid_labels = valid_labels,
                registry = p.registry,
                repository = p.repository,
                digest_file = p.digest.path,
            ).to_json())
            if "{" in p.registry or "{" in p.repository:
                requires_stamping = True

    # TODO: move this to "container_push wrapper"
    if requires_stamping:
        inputs += [ctx.info_file, ctx.version_file]
        args.add("--stamp_info_file", ctx.info_file)
        args.add("--stamp_info_file", ctx.version_file)

    ctx.actions.run(
        inputs = inputs,
        outputs = [ctx.outputs.out],
        arguments = [args],
        mnemonic = "EmbedContentAddressableReferences",
        executable = ctx.executable._embedder,
        tools = ctx.attr._embedder.default_runfiles.files,
    )
    return [EmbeddedContentInfo(
        content_publishers = depset(direct = content_publishers),
    )]

embedded_reference = rule(
    _impl,
    attrs = {
        "src": attr.label(
            doc = "Single template file.",
            allow_single_file = True,
            mandatory = True,
        ),
        "out": attr.output(
            doc = "Single output file.",
            mandatory = True,
        ),
        "deps": attr.label_list(
            doc = "Embeddable targets (eg container_push, content_addressable_file, etc).",
            providers = [
                [PushInfo],
                [ContentPublisherInfo],
            ],
            mandatory = True,
        ),
        "_embedder": attr.label(
            default = "//experimental/cas/internal:embedder",
            cfg = "host",
            executable = True,
        ),
    },
)
