load("//terraform/internal:launcher.bzl", "create_launcher", "runfiles_path")

content_publisher_attrs = {}

PublishableTargetsInfo = provider(
    fields = {
        "content_publisher_executables": "Depset<File> of executables that will publish content when run",
        "content_publisher_runfiles": "Depset<File> of runfiles needed when running content_publisher_executables",
    },
)

def _content_publisher_aspect_impl(target, ctx):
    """
    """
    transitive_executables = []
    transitive_runfiles = []

    if PublishableTargetsInfo in target:
        transitive_executables += [target[PublishableTargetsInfo].content_publisher_executables]
        transitive_runfiles += [target[PublishableTargetsInfo].content_publisher_runfiles]

    if OutputGroupInfo in target:
        groups = target[OutputGroupInfo]
        if hasattr(groups, "content_publisher_executables"):
            transitive_executables += [groups.content_publisher_executables]
        if hasattr(groups, "content_publisher_runfiles"):
            transitive_runfiles += [groups.content_publisher_runfiles]

    # recursively(ish?) go over all 'dir(ctx.rule.attr)'
    # - check 'if PublishableTargetsInfo in' then targets.append()
    for attr in dir(ctx.rule.attr):
        if attr in ["to_json", "to_proto"] or attr.startswith("_"):
            continue  # skip non-attrs and private attrs
        attr_targets = []  # collect all targets referenced by the current attr
        value = getattr(ctx.rule.attr, attr)
        value_type = type(value)
        if value_type == "Target":
            attr_targets.append(value)
        elif value_type == "list":
            for item in value:
                if type(item) == "Target":
                    attr_targets.append(item)
        elif value_type == "dict":
            for k, v in value.items():
                if type(k) == "Target":
                    attr_targets.append(k)
                if type(v) == "Target":
                    attr_targets.append(v)
        for t in attr_targets:
            if PublishableTargetsInfo in t:
                transitive_executables += [t[PublishableTargetsInfo].content_publisher_executables]
                transitive_runfiles += [t[PublishableTargetsInfo].content_publisher_runfiles]

    if transitive_executables:
        return [PublishableTargetsInfo(
            content_publisher_executables = depset(transitive = transitive_executables),
            content_publisher_runfiles = depset(transitive = transitive_runfiles),
        )]
    else:
        return []

content_publisher_aspect = aspect(
    implementation = _content_publisher_aspect_impl,
    attr_aspects = ["*"],
)

def create_content_publisher(ctx, output, aspect_targets):
    """
    Creates an executable file
    Returns runfiles necessary when running the content publisher
    """

    transitive_executables = []
    transitive_runfiles = []

    for t in aspect_targets:
        if PublishableTargetsInfo in t:
            transitive_executables += [t[PublishableTargetsInfo].content_publisher_executables]
            transitive_runfiles += [t[PublishableTargetsInfo].content_publisher_runfiles]

    # flatten list of depsets to unique list of executable files
    executables = sorted({
        k: None
        for k in depset(transitive = transitive_executables).to_list()
    }.keys())

    # runner will iterate each of the publishable targets & run each one
    runner = ctx.actions.declare_file(output.basename + "_runner.bash", sibling = output)
    ctx.actions.write(runner, """#!/usr/bin/env bash
                      set -euo pipefail
                      for f in "$@"; do
                        "$f"
                      done
                      """, is_executable = True)

    # add each runnable target
    args = [runner] + executables
    create_launcher(ctx, output, args)
    return ctx.runfiles(
        files = [output, runner],
        transitive_files = depset(transitive = transitive_runfiles + transitive_executables),
    )

def _content_publisher_impl(ctx):
    """
    """
    runfiles = create_content_publisher(
        ctx,
        ctx.outputs.executable,
        ctx.attr.deps,
    )
    return [DefaultInfo(
        executable = ctx.outputs.executable,
        runfiles = runfiles,
    )]

content_publisher = rule(
    implementation = _content_publisher_impl,
    attrs = content_publisher_attrs + {
        "deps": attr.label_list(aspects = [content_publisher_aspect]),
    },
    executable = True,
)
