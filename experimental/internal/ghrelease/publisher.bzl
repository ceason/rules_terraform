load(":test_suite.bzl", "GhReleaseTestSuiteInfo")
load(":assets.bzl", "GhReleaseAssetsInfo")

def _parse_version(version):
    v = version
    if v.startswith("v"):
        v = v[1:]
    parts = v.split(".")
    if (len(parts) == 2 and
        parts[0].isdigit() and
        parts[1].isdigit()):
        return struct(major = parts[0], minor = parts[1])
    fail("Expected '[v]MAJOR.MINOR' but got '%s'" % version, attr = "version")

def _impl(ctx):
    """
    """
    files = []
    transitive_runfiles = []

    transitive_docs = []
    asset_configs = []
    test_configs = []

    for dep in ctx.attr.deps:
        if GhReleaseAssetsInfo in dep:
            nfo = dep[GhReleaseAssetsInfo]
            if nfo.docs:
                transitive_docs += [nfo.docs]
            asset_configs.append(struct(
                label = str(dep.label),
                env = nfo.env,
                bazel_flags = nfo.bazel_flags,
            ))
        if GhReleaseTestSuiteInfo in dep:
            i = dep[GhReleaseTestSuiteInfo]
            test_configs.append(struct(
                label = str(dep.label),
            ))

    docs = depset(direct = ctx.files.docs, transitive = transitive_docs).to_list()
    docs = {k: None for k in docs}.keys()

    # make sure there are no duplicate filenames
    filenames = {}
    for f in docs:
        if f.basename in filenames:
            filenames[f.basename].append(f)
        else:
            filenames[f.basename] = [f]
    duplicates = {k: v for k, v in filenames.items() if len(v) > 1}
    if len(duplicates) > 0:
        fail("Found duplicate file names: %s" % duplicates, attr = "docs")

    args_file = ctx.actions.declare_file(ctx.attr.name + ".args")
    files.append(args_file)
    ctx.actions.write(args_file, "\n".join(ctx.attr.args))

    config_file = ctx.actions.declare_file(ctx.attr.name + ".config.json")
    files.append(config_file)
    config = struct(
        asset_configs = asset_configs,
        test_configs = test_configs,
        docs = [f.short_path for f in docs],
        docs_branch = ctx.attr.docs_branch,
        branch = ctx.attr.branch,
        version = _parse_version(ctx.attr.version),
        hub = ctx.executable._tool_hub.short_path,
    )
    ctx.actions.write(config_file, config.to_json())
    ctx.actions.write(
        ctx.outputs.executable,
        """#!/usr/bin/env bash
           set -euo pipefail
           exec "%s" "--config=$0.config.json" "@$0.args" "$@" <&0
        """ % ctx.executable._publisher_runner.short_path,
    )
    transitive_runfiles.append(ctx.attr._publisher_runner.data_runfiles)
    transitive_runfiles.append(ctx.attr._publisher_runner.default_runfiles)
    transitive_runfiles.append(ctx.attr._tool_hub.data_runfiles)
    transitive_runfiles.append(ctx.attr._tool_hub.default_runfiles)

    runfiles = ctx.runfiles(files = files + docs)
    for rf in transitive_runfiles:
        runfiles = runfiles.merge(rf)

    return [
        DefaultInfo(
            files = depset(direct = files),
            runfiles = runfiles,
        ),
    ]

ghrelease_publisher = rule(
    _impl,
    attrs = {
        "deps": attr.label_list(
            default = [],
            providers = [
                [GhReleaseAssetsInfo],
                [GhReleaseTestSuiteInfo],
            ],
        ),
        "version": attr.string(mandatory = True),
        "semver_env_var": attr.string(
            default = "GHRELEASE_SEMVER",
            # TODO(ceason): implement this
            doc = "UNIMPLEMENTED. Expose the SEMVER via this environment variable (eg for use in stamping via --workspace_status_command).",
        ),
        "branch": attr.string(default = "master"),
        "docs_branch": attr.string(default = "docs"),
        "docs": attr.label_list(default = [], allow_files = True),
        "_publisher_runner": attr.label(
            default = Label("//experimental/internal/ghrelease:publisher_runner"),
            executable = True,
            cfg = "host",
        ),
        "_tool_hub": attr.label(
            default = "@tool_hub",
            executable = True,
            cfg = "host",
        ),
    },
    executable = True,
)
