load("@io_bazel_rules_docker//container:providers.bzl", "PushInfo")
load("//experimental/internal:providers.bzl", "FileUploaderInfo")

def get_valid_labels(ctx, embed_label):
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

def create_embedded_file(ctx, srcs = [], output = None, deps = None, output_delimiter = ""):
    content_publisher_executables = []
    content_publisher_runfiles = []
    inputs = []

    args = ctx.actions.args()
    args.add("--output_delimiter", output_delimiter)
    for f in srcs:
        args.add("--input", f)
        inputs += [f]
    args.add("--output", output)
    requires_stamping = False
    for dep in deps:
        valid_labels = get_valid_labels(ctx, dep.label)
        if FileUploaderInfo in dep:
            content_publisher_executables += [dep.files_to_run.executable]
            content_publisher_runfiles += [dep.default_runfiles.files]

            # TODO: make sure target is executable & fail early if it's not
            info = dep[FileUploaderInfo]
            inputs += [info.url]
            args.add("--content_addressable_file", struct(
                label = str(dep.label),
                valid_labels = valid_labels,
                url_file = info.url.path,
            ).to_json())

        if PushInfo in dep:
            content_publisher_executables += [dep.files_to_run.executable]
            content_publisher_runfiles += [dep.default_runfiles.files]
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
        outputs = [output],
        arguments = [args],
        mnemonic = "EmbedContentAddressableReferences",
        executable = ctx.executable._embedder,
        tools = ctx.attr._embedder.default_runfiles.files,
    )
    return struct(
        content_publisher_executables = depset(direct = content_publisher_executables),
        content_publisher_runfiles = depset(transitive = content_publisher_runfiles),
    )

def _impl(ctx):
    """
    """
    embedded = create_embedded_file(
        ctx,
        srcs = [ctx.file.src],
        deps = ctx.attr.deps,
        output = ctx.outputs.out,
    )
    return [OutputGroupInfo(
        content_publisher_executables = embedded.content_publisher_executables,
        content_publisher_runfiles = embedded.content_publisher_runfiles,
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
                [FileUploaderInfo],
            ],
            mandatory = True,
        ),
        "_embedder": attr.label(
            default = "//experimental/internal/embedding:embedder",
            cfg = "host",
            executable = True,
        ),
    },
)
