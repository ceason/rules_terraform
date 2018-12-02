load(":providers.bzl", "ContentAddressableFileInfo")
load("@bazel_tools//tools/build_defs/hash:hash.bzl", "sha256", hash_tools = "tools")

def _impl(ctx):
    """
    """
    url_prefix = ctx.expand_make_variables("url_prefix", ctx.attr.url_prefix, {})
    if not url_prefix.endswith("/"):
        url_prefix += "/"
    digest = sha256(ctx, ctx.file.src)
    args = ctx.actions.args()
    args.add("--file_basename", ctx.file.src.basename)
    args.add("--digest", digest)
    args.add("--url_prefix", url_prefix)
    args.add("--output", ctx.outputs.out)
    ctx.actions.run(
        inputs = [digest],
        outputs = [ctx.outputs.out],
        arguments = [args],
        mnemonic = "ComputeContentAddressableUrl",
        executable = ctx.executable._casfile_url,
        tools = ctx.attr._casfile_url.default_runfiles.files,
    )
    return [
        DefaultInfo(files = depset(direct = [ctx.outputs.out])),
        ContentAddressableFileInfo(
            file = ctx.file.src,
            url = ctx.outputs.out,
        ),
    ]

#
content_addressable_file = rule(
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
            default = Label("//experimental/cas/internal:casfile_url"),
            cfg = "host",
            executable = True,
            allow_files = True,
        ),
    },
    outputs = {
        "out": "%{name}.url",
    },
)
