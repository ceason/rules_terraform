load("//experimental/internal/embedding:content_publisher.bzl", "create_content_publisher", "content_publisher_aspect", "content_publisher_attrs")

GhReleaseAssetsInfo = provider(
    fields = {
        "bazel_flags": "List<string>",
        "env": "dict<string,string>",
        "docs": "Depset<File>",
    },
)

def _impl(ctx):
    """
    """
    files = []
    transitive_runfiles = []
    transitive_assets = []
    transitive_docs = []

    for t in ctx.attr.data:
        # todo: handle file targets appropriately
        # get assets
        transitive_assets.append(t[DefaultInfo].files)

        # grab docs from the 'docs' property if present
        og_info = t[OutputGroupInfo]
        if hasattr(og_info, "docs"):
            if type(og_info.docs) == "list":
                transitive_docs.append(depset(direct = og_info.docs))
            else:
                transitive_docs.append(og_info.docs)

    # flatten & 'uniquify' our list of asset files
    assets = depset(transitive = transitive_assets).to_list()
    assets = {k: None for k in assets}.keys()

    # make sure there are no duplicate filenames
    filenames = {}
    for f in assets:
        if f.basename in filenames:
            filenames[f.basename].append(f)
        else:
            filenames[f.basename] = [f]
    duplicates = {k: v for k, v in filenames.items() if len(v) > 1}
    if len(duplicates) > 0:
        fail("Found duplicate file names: %s" % duplicates, attr = "data")

    # create an image publisher
    image_publisher = ctx.actions.declare_file(ctx.attr.name + ".image-publisher")
    files.append(image_publisher)
    publisher_runfiles = create_content_publisher(ctx, image_publisher, ctx.attr.data)

    config_file = ctx.actions.declare_file(ctx.attr.name + ".config.json")
    files.append(config_file)
    config = struct(
        env = ctx.attr.env,
        bazel_flags = ctx.attr.bazel_flags,
        assets = [f.short_path for f in sorted(assets)],
        label = str(ctx.label),
        image_publisher = image_publisher.short_path,
    )
    ctx.actions.write(config_file, config.to_json())
    ctx.actions.write(ctx.outputs.executable, """#!/usr/bin/env bash
                      set -euo pipefail
                      exec "{runner}" "--config={config}" "$@" <&0
                      """.format(
        runner = ctx.executable._assets_runner.short_path,
        config = config_file.short_path,
    ), is_executable = True)
    transitive_runfiles.append(ctx.attr._assets_runner.data_runfiles)
    transitive_runfiles.append(ctx.attr._assets_runner.default_runfiles)

    runfiles = ctx.runfiles(files = files + assets, transitive_files = publisher_runfiles)
    for rf in transitive_runfiles:
        runfiles = runfiles.merge(rf)

    return [
        DefaultInfo(
            files = depset(direct = files),
            runfiles = runfiles,
        ),
        GhReleaseAssetsInfo(
            bazel_flags = ctx.attr.bazel_flags,
            env = ctx.attr.env,
            docs = depset(transitive = transitive_docs) if transitive_docs else None,
        ),
    ]

ghrelease_assets = rule(
    _impl,
    attrs = content_publisher_attrs + {
        "bazel_flags": attr.string_list(default = []),
        "env": attr.string_dict(default = {}),
        "data": attr.label_list(
            default = [],
            aspects = [content_publisher_aspect],
            #allow_files = True,
        ),
        "_assets_runner": attr.label(
            default = Label("//experimental/internal/ghrelease:assets_runner"),
            executable = True,
            cfg = "host",
        ),
    },
    executable = True,
)
