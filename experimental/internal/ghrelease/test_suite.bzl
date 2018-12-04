GhReleaseTestSuiteInfo = provider(
    fields = {
    },
)

def _impl(ctx):
    """
    """
    files = []
    transitive_runfiles = []

    transitive_runfiles.append(ctx.attr._test_suite_runner.data_runfiles)
    transitive_runfiles.append(ctx.attr._test_suite_runner.default_runfiles)

    config_file = ctx.actions.declare_file(ctx.attr.name + ".config.json")
    files.append(config_file)
    config = struct(
        env = ctx.attr.env,
        bazel_flags = ctx.attr.bazel_flags,
        tests = ctx.attr.tests,
    )
    ctx.actions.write(config_file, config.to_json())

    executable = ctx.actions.declare_file(ctx.attr.name + ".runner.bash")
    ctx.actions.write(executable, """#!/usr/bin/env bash
                      set -euo pipefail
                      exec "{runner}" "--config={config}" "$@" <&0
                      """.format(
        runner = ctx.executable._test_suite_runner.short_path,
        config = config_file.short_path,
    ), is_executable = True)

    runfiles = ctx.runfiles(files = files)
    for rf in transitive_runfiles:
        runfiles = runfiles.merge(rf)

    return [
        DefaultInfo(
            files = depset(direct = files),
            executable = executable,
            runfiles = runfiles,
        ),
        GhReleaseTestSuiteInfo(),
    ]

ghrelease_test_suite = rule(
    _impl,
    attrs = {
        "bazel_flags": attr.string_list(default = []),
        "env": attr.string_dict(default = {}),
        "tests": attr.string_list(default = []),
        "_test_suite_runner": attr.label(
            default = Label("//experimental/internal/ghrelease:test_suite_runner"),
            executable = True,
            cfg = "host",
        ),
    },
    executable = True,
)
