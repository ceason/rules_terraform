load("//terraform:providers.bzl", "ModuleInfo", "PluginInfo", "WorkspaceInfo")
load(":util.bzl", "merge_filemap_dict")

def _plugin_impl(ctx):
    """
    """
    filename = "terraform-provider-%s_%s" % (ctx.attr.provider_name or ctx.attr.name, ctx.attr.version)
    file_map = {}
    if ctx.file.linux_amd64:
        file_map["linux_amd64/%s" % filename] = ctx.file.linux_amd64
    if ctx.file.darwin_amd64:
        file_map["darwin_amd64/%s" % filename] = ctx.file.darwin_amd64
    if ctx.file.windows_amd64:
        file_map["windows_amd64/%s.exe" % filename] = ctx.file.windows_amd64
    return [PluginInfo(files = file_map)]

terraform_plugin = rule(
    implementation = _plugin_impl,
    attrs = {
        # todo: maybe make version stampable?
        "version": attr.string(mandatory = True),
        "provider_name": attr.string(default = "", doc = "Name of terraform provider. Defaults to {name}"),
        "linux_amd64": attr.label(allow_single_file = True),
        "darwin_amd64": attr.label(allow_single_file = True),
        "windows_amd64": attr.label(allow_single_file = True),
    },
)

def _module_impl(ctx):
    """
    """

    # aggregate plugins/deps/etc
    files = {}
    k8s_objects = []
    transitive_k8s_objects = []
    runfiles = []
    transitive_runfiles = []
    plugins = [p for p in ctx.attr.plugins]
    transitive_plugins = []
    for f in ctx.files.srcs:
        label = f.owner or ctx.label
        prefix = label.package + "/"
        path = f.short_path[len(prefix):]
        files[path] = f
        runfiles.append(f)
    if ctx.attr.deps:
        print("Attribute 'deps' is deprecated. Use 'embed' instead (%s)" % ctx.label)

    embeds = []
    embeds.extend(ctx.attr.embed or [])
    embeds.extend(ctx.attr.deps or [])
    for dep in embeds:
        transitive_runfiles.append(dep.default_runfiles.files)
        if ModuleInfo in dep:
            mi = dep[ModuleInfo]
            files = merge_filemap_dict(files, mi.files)
            if mi.k8s_objects:
                transitive_k8s_objects.append(mi.k8s_objects)
            if mi.plugins:
                transitive_plugins.append(mi.plugins)
        else:
            # we assume this is a '_k8s_object'...
            l = dep.label
            k8s_executable = "%s/%s" % (l.package, l.name)
            k8s_objects.append(k8s_executable)

    # add default kubectl plugin if no plugins are specified
    if k8s_objects and not ctx.attr.plugins:
        plugins.append(ctx.attr._default_kubectl_plugin)

    return [
        ModuleInfo(
            files = files,
            plugins = depset(direct = plugins, transitive = transitive_plugins),
            k8s_objects = depset(direct = k8s_objects, transitive = transitive_k8s_objects),
            description = ctx.attr.description,
        ),
        DefaultInfo(
            runfiles = ctx.runfiles(
                files = runfiles,
                transitive_files = depset(transitive = transitive_runfiles),
            ),
        ),
    ]

terraform_module = rule(
    implementation = _module_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = True),
        "deps": attr.label_list(
            doc = "Deprecated. Use 'embed' instead ('embed' is functionally identical to 'deps', but seems more semantically correct).",
            allow_rules = [
                "_k8s_object",
                "terraform_module",
            ],
        ),
        "embed": attr.label_list(
            # we should use "providers" instead, but "k8s_object" does not
            # currently (2018-9-8) support them
            doc = "Merge the content of other <terraform_module>s (or <k8s_object>s) into this one.",
            allow_rules = [
                "_k8s_object",
                "terraform_module",
            ],
        ),
        "description": attr.string(
            doc = "Optional description of module.",
            default = "",
        ),
        "plugins": attr.label_list(
            doc = "Custom Terraform plugins that this module requires.",
            providers = [PluginInfo],
        ),
        "_default_kubectl_plugin": attr.label(
            providers = [PluginInfo],
            default = "//terraform/plugins/kubectl",
        ),
    },
)

def _workspace_impl(ctx):
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
                      apply|refresh)
                        # rm -rf "$plugin_dir" # potentially can't remove this else 'destroy' won't work if a provider is removed??
                        rm -rf "$tfroot"
                        {render_tf} '@{argsfile}' --output_dir "$tfroot" --plugin_dir "$plugin_dir"

                        cd "$BUILD_WORKSPACE_DIRECTORY/{package}"
                        terraform init -input=false "$tfroot"
                        terraform "$command" -backup=- "$tfroot"
                        ;;
                      destroy)
                        cd "$BUILD_WORKSPACE_DIRECTORY/{package}"
                        terraform destroy -backup=- "$@" "$tfroot"
                        ;;
                      state|import)
                        cd "$BUILD_WORKSPACE_DIRECTORY/{package}"
                        terraform "$command" "$@"
                        ;;
                      *)
                        rm -rf "$tfroot"
                        {render_tf} '@{argsfile}' --output_dir "$tfroot" --plugin_dir "$plugin_dir"

                        cd "$BUILD_WORKSPACE_DIRECTORY/{package}"
                        terraform init -input=false "$tfroot"
                        terraform "$command" "$@" "$tfroot"
                        ;;
                      esac
                      """.format(
        package = ctx.label.package,
        argsfile = renderer_argsfile.short_path,
        render_tf = ctx.executable._render_tf.short_path,
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
    implementation = _workspace_impl,
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
            # hack: disabling provider check until doc generator supports 'providers' attribute
            #   see https://github.com/bazelbuild/skydoc/blob/master/skydoc/stubs/attr.py#L180
            # providers = [ModuleInfo],
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
