load("//experimental/internal:providers.bzl", "EmbeddedContentInfo")
load("//terraform/internal:launcher.bzl", "create_launcher", "runfiles_path")

content_publisher_attrs = {}

PublishableTargetsInfo = provider(
    fields = {
        "targets": "<Depset> of targets which return the 'EmbeddedContentInfo' provider.",
    },
)

def _content_publisher_aspect_impl(target, ctx):
    """
    """
    transitive_targets = []

    if PublishableTargetsInfo in target:
        if target[PublishableTargetsInfo].targets != None:
            transitive_targets += [target[PublishableTargetsInfo].targets]

    if EmbeddedContentInfo in target:
        transitive_targets += [target[EmbeddedContentInfo].content_publishers]

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
                if t[PublishableTargetsInfo].targets != None:
                    transitive_targets.append(t[PublishableTargetsInfo].targets)

    if transitive_targets:
        publishable_targets = depset(transitive = transitive_targets)
    else:
        publishable_targets = None
    return [PublishableTargetsInfo(targets = publishable_targets)]

content_publisher_aspect = aspect(
    implementation = _content_publisher_aspect_impl,
    attr_aspects = ["*"],
    provides = [PublishableTargetsInfo],
)

def create_content_publisher(ctx, output, aspect_targets):
    """
    Creates an executable file
    Returns runfiles necessary when running the content publisher
    """
    targets_to_run = []

    for t in aspect_targets:
        # TODO(ceason): identify file targets in a more robust way
        if PublishableTargetsInfo not in t and str(t).startswith("<input file"):
            continue
        elif getattr(t[PublishableTargetsInfo], "targets"):
            targets_to_run += [t[PublishableTargetsInfo].targets]
        else:
            fail("Something went wrong.")

    # flatten list of depsets
    targets_to_run = depset(transitive = targets_to_run).to_list()

    # runner will iterate each of the publishable targets & run each one
    runner = ctx.actions.declare_file(output.basename + "_runner.bash", sibling = output)
    ctx.actions.write(runner, """#!/usr/bin/env bash
                      set -euo pipefail
                      for f in "$@"; do
                        "$f"
                      done
                      """, is_executable = True)

    # add each runnable target
    args = [runner]
    seen = {}
    for t in targets_to_run:
        if t.label not in seen:
            seen[t.label] = True
            args += [t.files_to_run.executable]
    runfiles = ctx.runfiles(files = [output, runner] + args)
    for t in targets_to_run:
        runfiles = runfiles.merge(t.default_runfiles)
    create_launcher(ctx, output, args)
    return runfiles

def _content_publisher_impl(ctx):
    """
    """
    runfiles = []
    transitive_runfiles = []

    transitive_runfiles.append(create_content_publisher(
        ctx,
        ctx.outputs.executable,
        ctx.attr.deps,
    ))
    return [DefaultInfo(
        runfiles = ctx.runfiles(
            files = runfiles,
            transitive_files = depset(transitive = transitive_runfiles),
        ),
    )]

content_publisher = rule(
    implementation = _content_publisher_impl,
    attrs = content_publisher_attrs + {
        "deps": attr.label_list(aspects = [content_publisher_aspect]),
    },
    executable = True,
)
