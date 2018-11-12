def _resolve_label(label):
    # append package path & workspace name as necessary
    if label.startswith(":"):
        label = native.package_name() + label
    if label.startswith("//"):
        label = native.repository_name() + label
    return label

def _quoted_bash_string(str):
    return '"%s"' % str.replace('"', '\\"')

def _impl(ctx):
    """
    """

    runfiles = []
    transitive_runfiles = []
    hub_args = []

    transitive_runfiles.append(ctx.attr._tool_hub.default_runfiles.files)
    if ctx.attr.draft:
        hub_args.append("--draft")
    if ctx.attr.prerelease:
        hub_args.append("--prerelease")

    for file in ctx.files.assets:
        runfiles.append(file)
        hub_args.append("--attach=$PWD/" + file.short_path)

    ctx.actions.expand_template(
        template = ctx.file._launcher_template,
        output = ctx.outputs.executable,
        substitutions = {
            "%{hub_args}": " ".join([_quoted_bash_string(arg) for arg in hub_args]),
            "%{tool_hub}": ctx.executable._tool_hub.short_path,
            "%{bazelrc_config}": ctx.attr.bazelrc_config or "",
            "%{prepublish_builds}": " ".join([
                _quoted_bash_string(l)
                for l in sorted(ctx.attr.prepublish_builds)
            ]),
            "%{prepublish_tests}": " ".join([
                _quoted_bash_string(l)
                for l in sorted(ctx.attr.tests)
            ]),
            "%{version}": ctx.attr.version,
            "%{branch}": ctx.attr.version,
            "%{env}": " ".join([
                "'%s=%s'" % (k, _quoted_bash_string(v))
                for k, v in ctx.attr.env
            ]),
        },
    )

    return [DefaultInfo(
        runfiles = ctx.runfiles(
            files = runfiles,
            transitive_files = depset(transitive = transitive_runfiles),
        ),
    )]

_github_release_publisher = rule(
    implementation = _impl,
    attrs = {
        #        "assets_map": attr.string_dict(mandatory = True),
        "assets": attr.label_list(allow_files = True, mandatory = True),
        "version": attr.string(default = "0.0", doc = "Major & minor semver version; does NOT include patch version (which is automatically incremented/generated)"),
        "bazelrc_config": attr.string(default = ""),
        "branch": attr.string(default = "master", doc = "Only allow releases to be published from this branch."),
        "prepublish_builds": attr.string_list(
            doc = "Ensure these target patterns build prior to publishing (eg make sure '//...' builds)",
            default = ["//..."],
        ),
        "tests": attr.string_list(
            doc = "Ensure these tests pass prior to publishing (eg '//...', plus explicitly enumerating select tests tagged as 'manual')",
            default = ["//..."],
        ),
        "draft": attr.bool(default = False, doc = "Create a draft release"),
        "prerelease": attr.bool(default = False, doc = "Create a pre-release"),
        "env": attr.string_dict(
            doc = "Environment variables set when publishing (useful in conjunction with '--workspace_status_command' script)",
            default = {},
        ),
        "_launcher_template": attr.label(
            executable = True,
            cfg = "host",
            allow_single_file = True,
            default = ":publisher.sh.tpl",
        ),
        "_tool_hub": attr.label(
            default = "@tool_hub",
            executable = True,
            cfg = "host",
        ),
    },
    executable = True,
)

def github_release(name, assets = [], **kwargs):
    """
    """

    # translate assets map to a mapping of name-to-labelname and list of asset labels
    assets = [_resolve_label(l) for l in assets]

    _github_release_publisher(
        name = name,
        assets = assets,
        **kwargs
    )

    native.genquery(
        name = name + ".srcs-list",
        opts = ["--noimplicit_deps"],
        expression = """kind("source file", deps(set(%s)))""" % " ".join(assets),
        scope = assets,
    )
