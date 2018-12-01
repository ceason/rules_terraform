load("@io_bazel_rules_docker//container:providers.bzl", "PushInfo")
load(":providers.bzl", "ContentAddressableFileInfo", "EmbeddedContentInfo")

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
            valid += [":" + dep.label.name]
    return valid

def _impl(ctx):
    """
    """
    if len(ctx.attr.srcs) != 1:
        fail("Must provide exactly one input", "srcs")
    if len(ctx.attr.outs) != 1:
        fail("Must provide exactly one output", "outs")

    container_pushes = []
    content_addressable_files = []

    args = ctx.actions.args()
    out = ctx.outputs.outs[0]
    inputs = [ctx.attr.srcs[0]]
    args.add("--template", ctx.attr.srcs[0])
    args.add("--output", out)
    requires_stamping = False
    workspace_name
    for dep in ctx.attr.deps:
        valid_labels = _get_valid_labels(ctx, dep)
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
        if ContentAddressableFileInfo in dep:
            content_addressable_files += [dep]
            info = dep[ContentAddressableFileInfo]
            inputs += [info.url]
            args.add("--content_addressable_file", struct(
                valid_labels = valid_labels,
                url_file = info.url.path,
            ).to_json())
    if requires_stamping:
        inputs += [ctx.info_file, ctx.version_file]
        args.add("--stamp_info_file", ctx.info_file)
        args.add("--stamp_info_file", ctx.version_file)

    ctx.actions.run(
        inputs = inputs,
        outputs = [out],
        arguments = [args],
        mnemonic = "EmbedContentAddressableReferences",
        executable = ctx.executable._embedder,
        tools = ctx.attr._embedder.default_runfiles,
    )
    return [
        DefaultInfo(files = depset(direct = [out])),
        EmbeddedContentInfo(
            container_pushes = depset(direct = container_pushes),
            content_addressable_files = depset(direct = content_addressable_files),
        ),
    ]

embedded_reference = rule(
    _impl,
    attrs = {
        "srcs": attr.label_list(
            doc = "Single template file.",
            allow_single_file = True,
            mandatory = True,
        ),
        "outs": attr.output_list(
            doc = "Single output file.",
            mandatory = True,
        ),
        "deps": attr.label_list(
            doc = "Embeddable targets (eg container_push, content_addressable_file, etc).",
            providers = [
                [PushInfo],
                [ContentAddressableFileInfo],
            ],
            mandatory = True,
        ),
        "_embedder": attr.label(
            default = "//experimental/cas:embedder",
            cfg = "host",
            executable = True,
        ),
    },
)
