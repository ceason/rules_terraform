load("//terraform:providers.bzl", "ModuleInfo", "PluginInfo", "WorkspaceInfo", "tf_workspace_files_prefix")
load("//terraform/internal:launcher.bzl", "create_launcher", "runfiles_path")

def create_terraform_renderer(ctx, output, module_info):
    """
    Writes a renderer to the specified output
    Returns a depset of files (for caller to add to runfiles)
    """

    runfiles = [output]
    transitive_runfiles = []
    args = [ctx.executable._render_tf]  # add all files, generated files and plugin files
    transitive_runfiles.append(ctx.attr._render_tf.default_runfiles.files)

    for p in module_info.plugins.to_list():
        plugin = p[PluginInfo]
        for filename, file in plugin.files.items():
            args.extend(["--plugin_file", filename, file])
            runfiles.append(file)
    for filename, file in module_info.files.items():
        args.extend(["--file", filename, file])
        runfiles.append(file)
    for g in module_info.file_generators:
        args.extend(["--file_generator", g.output_prefix, g.executable])
        runfiles.append(g.executable)
    create_launcher(ctx, output, args)
    return depset(direct = runfiles, transitive = transitive_runfiles)

tf_renderer_attrs = {
    "_render_tf": attr.label(
        executable = True,
        cfg = "host",
        default = "//terraform/internal:render_tf",
    ),
}
