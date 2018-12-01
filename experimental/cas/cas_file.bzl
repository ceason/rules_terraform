load(":providers.bzl", "ContentAddressableFileInfo")

def _impl(ctx):
    """
    """
    if len(ctx.attr.srcs) != 1:
        fail("Must provide exactly one input", "srcs")
    args = ctx.actions.args()
    args.add("--input", ctx.files.srcs[0])
    args.add("--url_prefix", ctx.attr.url_prefix)
    args.add("--output", ctx.outputs.out)
    ctx.actions.run(
        inputs = ctx.files.srcs,
        outputs = [ctx.outputs.out],
        arguments = [args],
        mnemonic = "ComputeContentAddressableUrl",
        executable = ctx.executable._casfile_url,
        tools = ctx.attr._casfile_url.default_runfiles,
    )
    return [
        DefaultInfo(files = depset(direct = [ctx.outputs.out])),
        ContentAddressableFileInfo(
            file = ctx.files.srcs[0],
            url = ctx.outputs.out,
        ),
    ]

#
content_addressable_file = rule(
    _impl,
    attrs = {
        "srcs": attr.label_list(allow_single_file = True, mandatory = True),
        "url_prefix": attr.string(
            mandatory = True,
            doc = "Prefix of URL where this file should be published (eg 's3://my-bucket-name/')",
        ),
        "_casfile_url": attr.label(
            default = Label("//experimental/cas:casfile_url"),
            cfg = "host",
            executable = True,
            allow_files = True,
        ),
    },
    outputs = {
        "out": "%{name}.url",
    },
)
