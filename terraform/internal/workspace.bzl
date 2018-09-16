load("//terraform:providers.bzl", "ModuleInfo", "PluginInfo", "WorkspaceInfo")
load(":util.bzl", "merge_filemap_dict")

def _impl(ctx):
    """
    """
    runfiles = []
    transitive_runfiles = []
    transitive_plugins = []
    renderer_args = []  # add all files, module files, k8s_objects and plugin files

    for f in ctx.files.srcs:
        label = f.owner or ctx.label
        prefix = label.package + "/"
        path = f.short_path[len(prefix):]
        renderer_args.extend(["--file", path, f.short_path])
        runfiles.append(f)

    for dep in ctx.attr.deps:
        transitive_runfiles.append(dep.default_runfiles.files)
        # we assume this is a '_k8s_object'...
        l = dep.label
        k8s_executable = "%s/%s" % (l.package, l.name)
        renderer_args.extend(["--k8s_object", ".", k8s_executable])

    for m, name in ctx.attr.modules.items():
        module = m[ModuleInfo]
        transitive_runfiles.append(m.default_runfiles.files)
        for path, file in module.files.items():
            renderer_args.extend(["--file", name + "/" + path, file.short_path])
            runfiles.append(file)

        for o in module.k8s_objects.to_list():
            renderer_args.extend(["--k8s_object", name, o])

        if module.plugins:
            transitive_plugins.append(module.plugins)

    plugins = depset(direct = ctx.attr.plugins, transitive = transitive_plugins)

    for p in plugins.to_list():
        plugin = p[PluginInfo]
        for path, file in plugin.files.items():
            renderer_args.extend(["--plugin_file", path, file.short_path])
            runfiles.append(file)

    renderer_argsfile = ctx.actions.declare_file("%s.render-workspace-args" % ctx.label.name)
    runfiles.append(renderer_argsfile)
    ctx.actions.write(renderer_argsfile, "\n".join(renderer_args))
    ctx.actions.write(ctx.outputs.executable, """
                      #!/bin/bash
                      set -eu
                      export PYTHON_RUNFILES=${{PYTHON_RUNFILES:=$0.runfiles}}
                      export TF_PLUGIN_CACHE_DIR="${{TF_PLUGIN_CACHE_DIR:=$HOME/.terraform.d/plugin-cache}}"
                      mkdir -p "$TF_PLUGIN_CACHE_DIR"

                      # figure out which command we are running
                      command="apply"
                      if [ $# -gt 0 ]; then
                        command=$1; shift
                      fi

                      if [ "$command" = "render" ]; then
                        exec {render_tf} '@{argsfile}' "$@"
                      fi

                      tfroot="$BUILD_WORKSPACE_DIRECTORY/{package}/.terraform/tfroot"
                      plugin_dir="$BUILD_WORKSPACE_DIRECTORY/{package}/.terraform/plugins"
                      # 'rules_k8s' needs to have PYTHON_RUNFILES set

                      case "$command" in
                      apply)
                        # rm -rf "$plugin_dir" # potentially can't remove this else 'destroy' won't work if a provider is removed??
                        rm -rf "$tfroot"
                        {render_tf} '@{argsfile}' --output_dir "$tfroot" --plugin_dir "$plugin_dir"

                        cd "$BUILD_WORKSPACE_DIRECTORY/{package}"
                        terraform init -input=false "$tfroot"
                        terraform apply -auto-approve "$tfroot"
                        ;;
                      destroy)
                        cd "$BUILD_WORKSPACE_DIRECTORY/{package}"
                        terraform destroy -refresh=false "$@" "$tfroot"
                        ;;
                      *)
                        terraform "$command" "$@" "$tfroot"
                        ;;
                      esac
                      """.format(
        package = ctx.label.package,
        argsfile = renderer_argsfile.short_path,
        render_tf = ctx.executable._render_tf.short_path
    ))



    return [DefaultInfo(
        runfiles = ctx.runfiles(
            files = runfiles,
            transitive_files = depset(transitive = transitive_runfiles + [
                ctx.attr._render_tf.data_runfiles.files,
            ]),
        ),
    ), WorkspaceInfo()]

terraform_workspace = rule(
    implementation = _impl,
    executable = True,
    attrs = {
        "srcs": attr.label_list(allow_files = True),
        "deps": attr.label_list(
            # todo: make this consistent with 'terraform_module' deps attribute
            allow_rules = [
                "_k8s_object",
            ],
        ),
        "modules": attr.label_keyed_string_dict(
            providers = [ModuleInfo],
        ),
        "plugins": attr.label_list(
            providers = [PluginInfo],
        ),
        "_render_tf": attr.label(
            executable = True,
            cfg = "host",
            default = "//terraform/internal:render_tf",
        ),
    },
)
