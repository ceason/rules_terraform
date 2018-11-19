load(
    "@io_bazel_rules_docker//container:layer_tools.bzl",
    _get_layers = "get_from_target",
    _layer_tools = "tools",
)
load(
    "@io_bazel_rules_docker//skylib:label.bzl",
    _string_to_label = "string_to_label",
)
load(":terraform_lib.bzl", "create_launcher", "runfiles_path")

image_publisher_attrs = {
    "_image_embedder": attr.label(
        default = Label("//terraform/internal:image_embedder"),
        cfg = "host",
        executable = True,
    ),
}

image_embedder_attrs = _layer_tools + {
    "image_chroot": attr.string(),
    "image_tag": attr.string(),
    "images": attr.string_dict(),
    # Implicit dependencies.
    "image_targets": attr.label_list(allow_files = True),
    "image_target_strings": attr.string_list(),
    "_image_embedder": attr.label(
        default = Label("//terraform/internal:image_embedder"),
        cfg = "host",
        executable = True,
    ),
    "_stamper": attr.label(
        default = Label("//terraform/internal:stamper"),
        cfg = "host",
        executable = True,
        allow_files = True,
    ),
}

ImagePublishInfo = provider(
    fields = {
        "image_specs": "List of <struct> containing image_spec.",
        "runfiles": "<Depset> of files.",
    },
)

PublishableTargetsInfo = provider(
    fields = {
        "targets": "<Depset> of targets which return the 'ImagePublishInfo' provider.",
    },
)

def _image_publisher_aspect_impl(target, ctx):
    """
    """
    targets = []
    transitive_targets = []

    if PublishableTargetsInfo in target:
        if target[PublishableTargetsInfo].targets != None:
            transitive_targets.append(target[PublishableTargetsInfo].targets)

    if ImagePublishInfo in target:
        #print(target.label)
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

image_publisher_aspect = aspect(
    implementation = _image_publisher_aspect_impl,
    attr_aspects = ["*"],
    provides = [PublishableTargetsInfo],
)

def create_image_publisher(ctx, output, aspect_targets):
    """
    Creates an executable file
    Returns runfiles necessary when running the image publisher
    """
    runfiles = []
    transitive_runfiles = []
    image_specs = []

    for t in aspect_targets:
        # TODO(ceason): identify file targets in a more robust way
        if PublishableTargetsInfo not in t and str(t).startswith("<input file"):
            continue
        targets = t[PublishableTargetsInfo].targets
        if targets != None:
            for target in targets.to_list():
                info = target[ImagePublishInfo]
                transitive_runfiles.append(info.runfiles)
                image_specs.extend(info.image_specs)

    # dedupe image specs
    image_specs = {k: None for k in image_specs}.keys()
    args = []
    for spec in image_specs:
        json = _image_spec_json(ctx, spec, use_runfiles_path = True)
        args.extend(["--image_spec", json])
    args.append("publish")

    args_file = ctx.actions.declare_file(output.basename + ".args", sibling = output)
    runfiles.append(args_file)
    runfiles.append(output)
    ctx.actions.write(args_file, "\n".join(args))
    ctx.actions.write(output, """#!/usr/bin/env bash
                    set -euo pipefail
                    if [[ -n "${TEST_SRCDIR-""}" && -d "$TEST_SRCDIR" ]]; then
                      # use $TEST_SRCDIR if set.
                      export RUNFILES="$TEST_SRCDIR"
                    elif [[ -z "${RUNFILES-""}" ]]; then
                      # canonicalize the entrypoint.
                      pushd "$(dirname "$0")" > /dev/null
                      abs_entrypoint="$(pwd -P)/$(basename "$0")"
                      popd > /dev/null
                      if [[ -e "${abs_entrypoint}.runfiles" ]]; then
                        # runfiles dir found alongside entrypoint.
                        export RUNFILES="${abs_entrypoint}.runfiles"
                      elif [[ "$abs_entrypoint" == *".runfiles/"* ]]; then
                        # runfiles dir found in entrypoint path.
                        export RUNFILES="${abs_entrypoint%%.runfiles/*}.runfiles"
                      else
                        # runfiles dir not found: fall back on current directory.
                        export RUNFILES="$PWD"
                      fi
                    fi
                    exec "%s" "@%s" "$@" <&0
                    """ % (ctx.executable._image_embedder.short_path, args_file.short_path), is_executable = True)
    transitive_runfiles.append(ctx.attr._image_embedder.default_runfiles.files)
    transitive_runfiles.append(ctx.attr._image_embedder.data_runfiles.files)

    return depset(direct = runfiles, transitive = transitive_runfiles)

def _image_spec_json(ctx, spec, use_runfiles_path = False):
    """
    Resolves filepaths
    Returns: <string> json encoded image spec
    """
    out = {}
    for k, v in spec.items():
        type_v = type(v)
        if type_v == "File":
            path = runfiles_path(ctx, v) if use_runfiles_path else v.path
            out[k] = path
        elif type_v == "list":
            values = []
            for item in v:
                if type(item) == "File":
                    path = runfiles_path(ctx, item) if use_runfiles_path else item.path
                    values.append(path)
                else:
                    values.append(item)
            out[k] = values
        else:
            out[k] = v
    return struct(**out).to_json()

def embed_images(ctx, output, input_files = [], **kwargs):
    """
    Embeds container image digests into the provided inputs
    Returns [ImagePublishInfo] provider
    """
    runfiles = []
    transitive_runfiles = [ctx.attr._image_embedder.default_runfiles.files]
    image_specs = []
    image_spec_common = {}

    # resolve stampable/expandable attributes
    for attr in ["image_tag", "image_chroot"]:
        value = getattr(ctx.attr, attr)
        value = ctx.expand_make_variables(attr, value, {})
        if "{" in value:
            value_file = ctx.actions.declare_file(output.basename + "." + attr, sibling = output)
            ctx.actions.run(
                executable = ctx.executable._stamper,
                arguments = [
                    "--stamp-info-file=%s" % ctx.info_file.path,
                    "--stamp-info-file=%s" % ctx.version_file.path,
                    "--format=%s" % value,
                    "--output=%s" % value_file.path,
                ],
                inputs = [ctx.info_file, ctx.version_file],
                outputs = [value_file],
            )
            image_spec_common[attr + "_file"] = value_file
            runfiles.append(value_file)
        else:
            image_spec_common[attr] = value

    if ctx.attr.images:
        # Compute the set of layers from the image_targets.
        image_target_dict = _string_to_label(ctx.attr.image_targets, ctx.attr.image_target_strings)
        for tag in ctx.attr.images:
            target = ctx.attr.images[tag]
            image = _get_layers(ctx, ctx.label.name, image_target_dict[target])
            runfiles.append(image["config"])
            image_spec = image_spec_common + {
                "name": tag,
                "config": image["config"],  # <File>
                "tarball": image.get("legacy", None),
                "digests": [],  # <File>s
                "layers": [],  # <File>s
            }
            if image_spec["tarball"]:
                runfiles.append(image_spec["tarball"])
            for file in image.get("blobsum", []):
                image_spec["digests"].append(file)
                runfiles.append(file)
            for file in image.get("zipped_layer", []):
                image_spec["layers"].append(file)
                runfiles.append(file)
            image_specs.append(image_spec)

    # embed image digests
    args = ctx.actions.args()
    for spec in image_specs:
        args.add("--image_spec", _image_spec_json(ctx, spec))
    args.add("embed")
    args.add("--output_file", output)
    for file in input_files:
        args.add("--template", file)
    for k, v in kwargs.items():
        args.add("--%s=%s" % (k, v))
    ctx.actions.run(
        outputs = [output],
        inputs = input_files + runfiles,
        tools = ctx.attr._image_embedder.default_runfiles.files,
        executable = ctx.executable._image_embedder,
        arguments = [args],
    )

    return ImagePublishInfo(
        image_specs = image_specs,
        runfiles = depset(direct = runfiles, transitive = transitive_runfiles),
    )
