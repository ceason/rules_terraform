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
    targets = []
    transitive_targets = []

    if PublishableTargetsInfo in target:
        if target[PublishableTargetsInfo].targets != None:
            transitive_targets.append(target[PublishableTargetsInfo].targets)

    if EmbeddedContentInfo in target:
        targets.append(target)

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

    if targets or transitive_targets:
        publishable_targets = depset(direct = targets, transitive = transitive_targets)
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
    files = []
    runfiles = []

    content_publishers = []

    for t in aspect_targets:
        # TODO(ceason): identify file targets in a more robust way
        if PublishableTargetsInfo not in t and str(t).startswith("<input file"):
            continue
        targets = t[PublishableTargetsInfo].targets
        if targets != None:
            for target in targets.to_list():
                found_something = False
                if EmbeddedContentInfo in target:
                    info = target[EmbeddedContentInfo]
                    content_publishers += [info.content_publishers]
    # flatten list of depsets to list of content
    content_publishers = depset(transitive = content_publishers).to_list()

    # add content publisher targets args+runfiles
    for t in content_publishers:
        runfiles = runfiles.merge(t.default_runfiles)
        files += [t.files_to_run.executable]
        args += ["--content_publisher", t.files_to_run.executable]

    create_launcher(ctx, output, args)
    files += [output]
    runfiles = runfiles.merge(ctx.runfiles(files = files))

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
