load(":providers.bzl", "TerraformModuleInfo", "TerraformPluginInfo", "TerraformWorkspaceInfo", "tf_workspace_files_prefix")
load(":module.bzl", "module_impl", "module_outputs", "module_tool_attrs")
load(":terraform_lib.bzl", "create_launcher")
load(
    "//experimental/internal/embedding:content_publisher.bzl",
    "content_publisher_aspect",
    "content_publisher_attrs",
    "create_content_publisher",
)

_workspace_attrs = {
    "srcs": attr.label_list(
        allow_files = [".tf", ".tfvars"],
        aspects = [content_publisher_aspect],
    ),
    "embed": attr.label_list(
        doc = "Merge the content of other <terraform_module>s (or other 'ModuleInfo' providing deps) into this one.",
        providers = [TerraformModuleInfo],
        aspects = [content_publisher_aspect],
    ),
    "deps": attr.label_list(
        providers = [TerraformModuleInfo],
        aspects = [content_publisher_aspect],
    ),
    "data": attr.label_list(
        allow_files = True,
        aspects = [content_publisher_aspect],
    ),
    "plugins": attr.label_list(
        doc = "Custom Terraform plugins that this workspace requires.",
        providers = [TerraformPluginInfo],
    ),
    "_workspace_launcher_template": attr.label(
        allow_single_file = True,
        default = "//terraform/internal:ws_launcher.sh.tpl",
    ),
    "_terraform_workspace_renderer": attr.label(
        default = Label("//terraform/internal:render_workspace"),
        executable = True,
        cfg = "host",
    ),
}

def _workspace_impl(ctx):
    # get our module info
    module_info = module_impl(ctx, modulepath = ctx.attr.name).terraform_module_info
    if not module_info.srcs:
        fail("Must provide srcs", attr = "srcs")

    # create content publisher from aspect-instrumented targets
    content_publisher = ctx.actions.declare_file(ctx.attr.name + ".image-publisher")
    runfiles = create_content_publisher(
        ctx,
        content_publisher,
        ctx.attr.srcs + ctx.attr.embed + ctx.attr.deps + ctx.attr.data,
    )

    files = []

    # bundle the renderer with args for the content of this tf module
    render_workspace = ctx.actions.declare_file("%s.render-workspace" % ctx.attr.name)
    runfiles = runfiles.merge(ctx.attr._terraform_workspace_renderer.default_runfiles)
    renderer_args = [ctx.executable._terraform_workspace_renderer]
    renderer_args += ["--prerender_hook", content_publisher]
    renderer_args += ["--tfroot_archive", ctx.outputs.out]
    files += [ctx.outputs.out]
    renderer_args += ["--terraform_binary", ctx.executable._terraform]
    files += [ctx.executable._terraform]
    transitive_plugins = []
    if hasattr(module_info, "plugins"):
        for p in module_info.plugins.to_list():
            plugin_info = p[TerraformPluginInfo]
            for filename, file in plugin_info.files.items():
                renderer_args += ["--plugin_file", filename, file]
                files += [file]

    create_launcher(ctx, render_workspace, renderer_args)
    files += [render_workspace]

    # create the workspace launcher
    ctx.actions.expand_template(
        template = ctx.file._workspace_launcher_template,
        output = ctx.outputs.executable,
        substitutions = {
            "%{render_workspace}": render_workspace.short_path,
            "%{tf_workspace_dir}": "$BUILD_WORKSPACE_DIRECTORY/%s/%s" % (
                ctx.label.package,
                tf_workspace_files_prefix(),
            ),
        },
    )
    runfiles = runfiles.merge(ctx.runfiles(files = files))
    return [
        TerraformWorkspaceInfo(render_workspace = render_workspace),
        DefaultInfo(
            files = depset(direct = [ctx.outputs.out]),
            runfiles = runfiles,
            executable = ctx.outputs.executable,
        ),
    ]

terraform_workspace = rule(
    _workspace_impl,
    executable = True,
    attrs = module_tool_attrs + content_publisher_attrs + _workspace_attrs,
    outputs = module_outputs,
)

def terraform_workspace_macro(name, **kwargs):
    terraform_workspace(
        name = name,
        **kwargs
    )
    # TODO(ceason): create 'apply' wrapper?

    # create a convenient destroy target which
    # CDs to the package dir and runs terraform destroy
    native.genrule(
        name = "%s.destroy" % name,
        outs = ["%s.destroy.sh" % name],
        cmd = """echo '#!/usr/bin/env bash
            set -euo pipefail
            terraform="$$BUILD_WORKSPACE_DIRECTORY/{package}/{tf_workspace_files_prefix}/.terraform/terraform.sh"
            if [ -e "$$terraform" ]; then
                exec "$$terraform" destroy "$$@" <&0
            else
                >&2 echo "Could not find terraform wrapper, so there is nothing to destroy! ($$terraform)"
            fi
            ' > $@""".format(
            package = native.package_name(),
            tf_workspace_files_prefix = tf_workspace_files_prefix(),
        ),
        executable = True,
    )
