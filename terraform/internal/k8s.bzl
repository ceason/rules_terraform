load("//terraform:providers.bzl", "ModuleInfo")
load("//terraform/internal:image_embedder_lib.bzl", "embed_images", "image_embedder_attrs", "runfiles_path")
load("//terraform/internal:terraform_lib.bzl", "create_launcher")

def _terraform_k8s_manifest_impl(ctx):
    providers = []
    runfiles = []
    transitive_runfiles = []
    module_info = ModuleInfo(
        files = {},
        file_generators = [],
        plugins = depset(direct = [ctx.attr._kubectl_plugin]),
    )
    providers.append(module_info)

    # create a file generator that resolves image references
    # & writes objects to individual files
    embedded = ctx.actions.declare_file("%s.embedded-manifests.yaml" % ctx.attr.name)
    runfiles.append(embedded)
    providers.append(embed_images(
        ctx,
        embedded,
        input_files = ctx.files.srcs,
        output_format = "yaml",
    ))
    file_generator = ctx.actions.declare_file("%s.generate-manifests" % ctx.attr.name)
    ctx.actions.write(ctx.outputs.executable, """#!/bin/bash
                      set -euo pipefail
                      cat "%s"
                      """ % embedded.short_path)
    create_launcher(ctx, file_generator, [
        ctx.executable._k8s_tool,
        "write-k8s",
        "--input_file",
        embedded,
    ])
    transitive_runfiles.append(ctx.attr._k8s_tool.default_runfiles.files)
    module_info.file_generators.append(struct(
        executable = file_generator,
        output_prefix = ".",
    ))

    # create file of terraform resources
    # (one kubectl_generic_object for each k8s object)
    generated_tf = ctx.actions.declare_file("%s.tf" % ctx.attr.name)
    gen_tf_args = ctx.actions.args()
    gen_tf_args.add("write-tf")
    gen_tf_args.add("--output", generated_tf)
    for f in ctx.files.srcs:
        gen_tf_args.add("--file", f)
    ctx.actions.run(
        inputs = ctx.files.srcs,
        outputs = [generated_tf],
        executable = ctx.executable._k8s_tool,
        arguments = [gen_tf_args],
        tools = ctx.attr._k8s_tool.default_runfiles.files,
    )
    module_info.files[generated_tf.basename] = generated_tf

    return providers + [
        DefaultInfo(
            files = depset(direct = [embedded]),
            runfiles = ctx.runfiles(
                files = runfiles,
                transitive_files = depset(transitive = transitive_runfiles),
            ),
        ),
    ]

_terraform_k8s_manifest = rule(
    implementation = _terraform_k8s_manifest_impl,
    attrs = image_embedder_attrs + {
        "srcs": attr.label_list(allow_files = [".yaml", ".json", ".yml"]),
        "_kubectl_plugin": attr.label(default = "//terraform/plugins/kubectl"),
        "_k8s_tool": attr.label(
            default = "//terraform/internal:k8s",
            executable = True,
            cfg = "host",
        ),
    },
    executable = True,
)

def terraform_k8s_manifest(name, images = {}, **kwargs):
    """
    """
    for reserved in ["image_targets", "image_target_strings"]:
        if reserved in kwargs:
            fail("reserved for internal use by docker_bundle macro", attr = reserved)
    deduped_images = {s: None for s in images.values()}.keys()
    _terraform_k8s_manifest(
        name = name,
        images = images,
        image_targets = deduped_images,
        image_target_strings = deduped_images,
        **kwargs
    )
