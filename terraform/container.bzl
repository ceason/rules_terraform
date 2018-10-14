load("//terraform:providers.bzl", "ModuleInfo")
load("//terraform/internal:image_resolver_lib.bzl", "create_image_resolver", "image_resolver_attrs", "runfiles_path")
load("//terraform/internal:k8s.bzl", _terraform_k8s_manifest = "terraform_k8s_manifest")

terraform_k8s_manifest = _terraform_k8s_manifest

def _image_resolver_impl(ctx):
    runfiles = []
    transitive_runfiles = []

    resolver_runfiles = create_image_resolver(
        ctx,
        ctx.outputs.executable,
        input_files = [ctx.file.src],
        output_format = ctx.file.src.extension,
    )
    transitive_runfiles.append(resolver_runfiles)

    file_generator = ctx.actions.declare_file("%s.generate-file" % ctx.attr.name)
    ctx.actions.write(file_generator, """#!/usr/bin/env bash
                      set -euo pipefail
                      {resolver} > {output_file}
                      """.format(
        resolver = runfiles_path(ctx, ctx.outputs.executable),
        output_file = "%s.%s" % (ctx.attr.name, ctx.file.src.extension),
    ), is_executable = True)

    return [
        ModuleInfo(
            file_generators = [struct(executable = file_generator, output_prefix = ".")],
        ),
        DefaultInfo(runfiles = ctx.runfiles(
            files = runfiles,
            transitive_files = depset(transitive = transitive_runfiles),
        )),
    ]

_image_resolver = rule(
    implementation = _image_resolver_impl,
    attrs = image_resolver_attrs + {
        "src": attr.label(allow_single_file = [".yaml", ".json", ".yml"]),
    },
    executable = True,
)

def image_resolver(name, images = {}, **kwargs):
    """
    """
    for reserved in ["image_targets", "image_target_strings"]:
        if reserved in kwargs:
            fail("reserved for internal use by docker_bundle macro", attr = reserved)
    deduped_images = {s: None for s in images.values()}.keys()
    _image_resolver(
        name = name,
        images = images,
        image_targets = deduped_images,
        image_target_strings = deduped_images,
        **kwargs
    )
