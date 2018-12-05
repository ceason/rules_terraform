load("//experimental/internal:providers.bzl", "FileUploaderInfo")
load("@bazel_tools//tools/build_defs/hash:hash.bzl", "sha256", hash_tools = "tools")
load("//terraform/internal:launcher.bzl", "create_launcher")

def _impl(ctx):
    """
    """

    # compute the URL where the file will be published
    url_prefix = ctx.expand_make_variables("url_prefix", ctx.attr.url_prefix, {})
    if not url_prefix.endswith("/"):
        url_prefix += "/"
    digest = sha256(ctx, ctx.file.src)
    args = ctx.actions.args()
    args.add("--file_basename", ctx.file.src.basename)
    args.add("--digest", digest)
    args.add("--url_prefix", url_prefix)
    args.add("--output", ctx.outputs.out)
    stamp_files = [ctx.info_file, ctx.version_file] if "{" in url_prefix else []
    for f in stamp_files:
        args.add("--stamp_info_file", f)
    ctx.actions.run(
        inputs = [digest] + stamp_files,
        outputs = [ctx.outputs.out],
        arguments = [args],
        mnemonic = "ComputeContentAddressableUrl",
        executable = ctx.executable._casfile_url,
        tools = ctx.attr._casfile_url.default_runfiles.files,
    )

    # create pubisher executable
    publisher_args = [ctx.executable._casfile_publisher]
    publisher_args += ["--url", ctx.outputs.out]
    publisher_args += ["--file", ctx.file.src]
    create_launcher(ctx, ctx.outputs.executable, publisher_args)

    runfiles = ctx.runfiles(files = [ctx.outputs.out, ctx.file.src])
    runfiles = runfiles.merge(ctx.attr._casfile_publisher.default_runfiles)
    return [
        DefaultInfo(
            files = depset(direct = [ctx.outputs.out]),
            executable = ctx.outputs.executable,
            runfiles = runfiles,
        ),
        FileUploaderInfo(
            url = ctx.outputs.out,
        ),
    ]

#
file_upload = rule(
    _impl,
    attrs = hash_tools + {
        "src": attr.label(
            allow_single_file = True,
            mandatory = True,
        ),
        "url_prefix": attr.string(
            mandatory = True,
            doc = "Prefix of URL where this file should be published (eg 's3://my-bucket-name/')",
        ),
        "_casfile_url": attr.label(
            default = Label("//experimental/internal/embedding:casfile_url"),
            cfg = "host",
            executable = True,
        ),
        "_casfile_publisher": attr.label(
            default = Label("//experimental/internal/embedding:casfile_publisher"),
            cfg = "host",
            executable = True,
        ),
    },
    outputs = {
        "out": "%{name}.url",
    },
    executable = True,
)
