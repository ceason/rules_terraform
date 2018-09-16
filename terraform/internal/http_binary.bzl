_PROVIDED_TEMPLATE_VARIABLES = [
    "Platform",
    "PLATFORM",
    "platform",
]

def _expand_template(s, ctx, platform_info):
    return s.format(
        Platform = platform_info.platform_name.capitalize(),
        PLATFORM = platform_info.platform_name.upper(),
        platform = platform_info.platform_name.lower(),
        version = ctx.attr.version,
    )

def _host_platform_info(ctx):
    """
    """
    if ctx.os.name == "linux":
        platform_name = "linux"
    elif ctx.os.name == "mac os x":
        platform_name = "darwin"
    elif ctx.os.name.startswith("windows"):
        platform_name = "windows"
    elif ctx.os.name == "freebsd":
        platform_name = "freebsd"
    else:
        fail("Unsupported operating system: " + ctx.os.name)
    return struct(
        platform_name = platform_name,
    )

def _http_archive_binary_impl(ctx):
    info = _host_platform_info(ctx)

    # expand template for attributes
    url = _expand_template(ctx.attr.url, ctx, info)
    strip_prefix = _expand_template(ctx.attr.strip_prefix, ctx, info) if ctx.attr.strip_prefix else ""
    path = _expand_template(ctx.attr.path, ctx, info)

    # append ".exe" if we're on windows
    if info.platform_name == "windows":
        path = path + ".exe"

    # create a launcher
    ctx.file("WORKSPACE", content = """workspace(name = "%s")""" % ctx.attr.name)
    ctx.file("BUILD.bazel", content = """
sh_binary(
    name = "binary",
    srcs = ["@{repository_name}//archive:{path}"],
    data = ["@{repository_name}//archive"],
)
alias(
    name = "{repository_name}",
    actual = ":binary",
    visibility = ["//visibility:public"],
)
    """.format(
        repository_name = ctx.attr.name,
        path = path,
    ))

    # download the archive
    ctx.download_and_extract(url, output = "archive", stripPrefix = strip_prefix)
    ctx.file("archive/BUILD.bazel", content = """
exports_files(glob(["**"]))

filegroup(
    name = "archive",
    srcs = glob(["**"]),
    visibility = ["//visibility:public"],
)
""")

http_archive_binary = repository_rule(
    implementation = _http_archive_binary_impl,
    attrs = {
        "url": attr.string(mandatory = True),
        "version": attr.string(mandatory = True),
        "path": attr.string(mandatory = True),
        "strip_prefix": attr.string(default = ""),
        "host_binary": attr.string(
            # todo(ceason): Implement this
            default = "",
            doc = "Use the binary from the host's PATH (if exists) instead of downloading the archive.",
        ),
    },
)

def _http_file_binary_impl(ctx):
    info = _host_platform_info(ctx)

    # expand template for attributes
    url = _expand_template(ctx.attr.url, ctx, info)
    filename = "file.exe" if info.platform_name == "windows" else "file"

    # create a launcher
    ctx.file("WORKSPACE", content = """workspace(name = "%s")""" % ctx.attr.name)
    ctx.file("BUILD.bazel", content = """
sh_binary(
    name = "binary",
    srcs = ["{filename}"],
)
alias(
    name = "{repository_name}",
    actual = ":binary",
    visibility = ["//visibility:public"],
)
    """.format(filename = filename, repository_name = ctx.attr.name))

    # download file to the appropriate location
    ctx.download(url, output = "file", executable = True)

http_file_binary = repository_rule(
    implementation = _http_file_binary_impl,
    attrs = {
        "url": attr.string(mandatory = True),
        "version": attr.string(mandatory = True),
        "host_binary": attr.string(
            # todo(ceason): Implement this
            default = "",
            doc = "Use the binary from the host's PATH (if exists) instead of downloading the archive.",
        ),
    },
)
