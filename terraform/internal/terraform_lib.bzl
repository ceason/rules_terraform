load("//terraform:providers.bzl", "ModuleInfo", "PluginInfo", "WorkspaceInfo", "tf_workspace_files_prefix")

def runfiles_path(ctx, f):
    """Return the runfiles relative path of f."""
    if ctx.workspace_name:
        return "${RUNFILES}/" + ctx.workspace_name + "/" + f.short_path
    else:
        return "${RUNFILES}/" + f.short_path

def create_launcher(ctx, output, args):
    """
    Writes a launcher to the specified output
    """
    resolved_args = []
    for arg in args:
        if type(arg) == "File":
            if ctx.workspace_name:
                arg_str = '"${RUNFILES}/%s/%s"' % (ctx.workspace_name, arg.short_path)
            else:
                arg_str = '"${RUNFILES}/%s"' % (arg.short_path)
        elif type(arg) == "string":
            # todo: escape double quotes & escape chars
             arg_str = '"%s"' % arg
            # arg_str = arg
        else:
            fail("Unknown argument type '%s' for arg '%s'" % (type(arg), arg))
        resolved_args.append(arg_str)
    launcher = """#!/usr/bin/env bash
set -euo pipefail
err_report(){
  >&2 echo "Error when executing command:"
  >&2 printf "  %%s\n" "${ARGS[@]}"
}
trap err_report ERR
RUNFILES=${RUNFILES-${TEST_RUNFILES-"$(cd $0.runfiles && pwd)"}}
ARGS=(
  %s
)
exec "${ARGS[@]}" "$@" <&0
""" % "\n  ".join(resolved_args)
    ctx.actions.write(output, launcher, is_executable = True)

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
