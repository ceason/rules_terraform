load("//terraform:providers.bzl", "ModuleInfo", "PluginInfo", "WorkspaceInfo", "tf_workspace_files_prefix")
load(":module.bzl", "flip_modules_attr", _module = "module")
load(":terraform_lib.bzl", "create_launcher")
load(
    "//terraform/internal:image_embedder_lib.bzl",
    "create_image_publisher",
    "image_publisher_aspect",
    "image_publisher_attrs",
    _embed_images = "embed_images",
)

def _impl(ctx):
    providers = []
    runfiles = []
    transitive_runfiles = []

    module = _module.implementation(ctx).terraform_module_info
    providers.append(module)

    image_publisher = ctx.actions.declare_file(ctx.attr.name + ".image-publisher")
    runfiles.append(image_publisher)

    #    for f in ctx.attr.srcs:
    #        print("%s: %s" % (type(f), f))
    transitive_runfiles.append(create_image_publisher(
        ctx,
        image_publisher,
        ctx.attr.srcs + ctx.attr.embed + ctx.attr.modules.keys(),
    ))

    # bundle the renderer with args for the content of this tf module
    render_workspace = ctx.actions.declare_file("%s.render-workspace" % ctx.attr.name)
    renderer_args = []
    renderer_args.append(ctx.executable._terraform_workspace_renderer)
    transitive_runfiles.append(ctx.attr._terraform_workspace_renderer.default_runfiles.files)
    transitive_runfiles.append(ctx.attr._terraform_workspace_renderer.data_runfiles.files)
    renderer_args.extend(["--prerender_hook", image_publisher])
    renderer_args.extend(["--tfroot_archive", module.tar])
    runfiles.append(module.tar)
    for p in module.plugins.to_list():
        plugin = p[PluginInfo]
        for filename, file in plugin.files.items():
            renderer_args.extend(["--plugin_file", filename, file])
            runfiles.append(file)

    create_launcher(ctx, render_workspace, renderer_args)
    runfiles.append(render_workspace)

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
    return providers + [
        WorkspaceInfo(
            render_workspace = render_workspace,
        ),
        DefaultInfo(
            runfiles = ctx.runfiles(
                files = runfiles,
                transitive_files = depset(transitive = transitive_runfiles),
            ),
        ),
    ]

_terraform_workspace = rule(
    _impl,
    executable = True,
    attrs = _module.attributes([image_publisher_aspect]) + image_publisher_attrs + {
        "_workspace_launcher_template": attr.label(
            allow_single_file = True,
            default = "//terraform/internal:ws_launcher.sh.tpl",
        ),
        "_terraform_workspace_renderer": attr.label(
            default = Label("//terraform/internal:render_workspace"),
            executable = True,
            cfg = "host",
        ),
    },
    outputs = _module.outputs,
)

def terraform_workspace(name, modules = {}, **kwargs):
    _terraform_workspace(
        name = name,
        modules = flip_modules_attr(modules),
        **kwargs
    )
