load("//terraform:providers.bzl", "ModuleInfo", "PluginInfo", "WorkspaceInfo", "tf_workspace_files_prefix")

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
    file_map = {}
    k8s_objects = []
    runfiles = []
    transitive_runfiles = []
    plugins = [p for p in ctx.attr.plugins]
    transitive_plugins = []
    for f in ctx.files.srcs:
        label = f.owner or ctx.label
        prefix = label.package + "/"
        path = f.short_path[len(prefix):]
        file_map[path] = f
        runfiles.append(f)
    if ctx.attr.deps:
        print("Attribute 'deps' is deprecated. Use 'embed' instead (%s)" % ctx.label)

    # todo: validate that no files (src or embedded) collide with 'modules' attribute (eg module is
    # only thing allowed to populate its subpath)
    # - test that `filepath` does not begin with `module+"/"` for all configured modules

    embeds = []
    embeds.extend(ctx.attr.embed or [])
    embeds.extend(ctx.attr.deps or [])
    has_k8s_embeds = False
    for dep in embeds:
        transitive_runfiles.append(dep.default_runfiles.files)
        if ModuleInfo in dep:
            mi = dep[ModuleInfo]
            for filename, file in mi.files.items():
                if filename in file_map and file_map[filename] != file:
                    fail("Cannot embed file '%s' from module '%s' because it already comes from '%s'" % (
                        filename,
                        dep.label,
                        file_map[filename].short_path,
                    ), attr = "embed")
                else:
                    file_map[filename] = file
            if mi.k8s_objects:
                k8s_objects.extend(mi.k8s_objects)
            if mi.plugins:
                transitive_plugins.append(mi.plugins)
        else:
            # we assume this is a '_k8s_object'...
            # todo: better way to do this? (eg does 'dep.kind' exist)
            has_k8s_embeds = True
            k8s_objects.append(struct(target = dep, output_prefix = ""))

    for m, module_name in ctx.attr.modules.items():
        module = m[ModuleInfo]
        transitive_runfiles.append(m.default_runfiles.files)
        for filename, file in module.files.items():
            file_map["%s/%s" % (module_name, filename)] = file
        for o in module.k8s_objects:
            k8s_objects.append(struct(
                target = o.target,
                output_prefix = "%s/%s" % (module_name, o.output_prefix),
            ))
        if module.plugins:
            transitive_plugins.append(module.plugins)

    # dedupe any k8s objects we got
    if k8s_objects:
        k8s_objects = {
            "%s:%s" % (o.target.label, o.output_prefix): o
            for o in k8s_objects
        }.values()

    # add default kubectl plugin if no plugins are specified
    if has_k8s_embeds and not ctx.attr.plugins:
        plugins.append(ctx.attr._default_kubectl_plugin)

    # bundle the renderer with args for the content of this tf module
    render_tf = ctx.actions.declare_file("%s.render-tf" % ctx.attr.name)
    render_tf_argsfile = ctx.actions.declare_file("%s.render-tf-args" % ctx.attr.name)
    render_tf_args = []  # add all files, module files, k8s_objects and plugin files
    runfiles.append(render_tf)
    runfiles.append(render_tf_argsfile)
    transitive_runfiles.append(ctx.attr._render_tf.default_runfiles.files)

    plugins_depset = depset(direct = plugins, transitive = transitive_plugins)
    for p in plugins_depset.to_list():
        plugin = p[PluginInfo]
        for filename, file in plugin.files.items():
            render_tf_args.extend(["--plugin_file", filename, file.short_path])
            runfiles.append(file)
    for filename, file in file_map.items():
        render_tf_args.extend(["--file", filename, file.short_path])
        runfiles.append(f)
    for obj in k8s_objects:
        executable = obj.target.files_to_run.executable.short_path
        render_tf_args.extend(["--k8s_object", obj.output_prefix or ".", executable])
        transitive_runfiles.append(obj.target.default_runfiles.files)

    ctx.actions.write(render_tf_argsfile, "\n".join(render_tf_args))
    ctx.actions.write(render_tf, """#!/bin/sh
                          exec "{render_tf}" "@{argsfile}" "$@"
                          """.format(
        argsfile = render_tf_argsfile.short_path,
        render_tf = ctx.executable._render_tf.short_path,
    ))

    providers = []

    # if this is a workspace, create a launcher
    if ctx.attr._is_workspace:
        providers.append(WorkspaceInfo(
            render_tf = render_tf,
        ))
        ctx.actions.expand_template(
            template = ctx.file._workspace_launcher_template,
            output = ctx.outputs.executable,
            substitutions = {
                "%{package}": ctx.label.package,
                "%{tf_workspace_files_prefix}": tf_workspace_files_prefix(ctx.attr.name),
                "%{render_tf}": render_tf.short_path,
            },
        )
    else:
        providers.append(ModuleInfo(
            files = file_map,
            plugins = plugins_depset,
            k8s_objects = k8s_objects,
            description = ctx.attr.description,
            render_tf = render_tf,
        ))

    return providers + [DefaultInfo(runfiles = ctx.runfiles(
        files = runfiles,
        transitive_files = depset(transitive = transitive_runfiles),
    ))]

_common_attrs = {
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
    "modules": attr.label_keyed_string_dict(
        # hack: disabling provider check until doc generator supports 'providers' attribute
        #   see https://github.com/bazelbuild/skydoc/blob/master/skydoc/stubs/attr.py#L180
        # providers = [ModuleInfo],
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
    "_workspace_launcher_template": attr.label(
        allow_single_file = True,
        default = "//terraform/internal:workspace_launcher.sh.tpl",
    ),
    "_render_tf": attr.label(
        executable = True,
        cfg = "host",
        default = "//terraform/internal:render_tf",
    ),
}

terraform_module = rule(
    implementation = _module_impl,
    attrs = dict(
        _common_attrs.items(),
        # hack: this flag lets us share the same implementation function as 'terraform_module'
        _is_workspace = attr.bool(default = False),
    ),
)

terraform_workspace = rule(
    implementation = _module_impl,
    executable = True,
    attrs = dict(
        _common_attrs.items(),
        # hack: this flag lets us share the same implementation function as 'terraform_module'
        _is_workspace = attr.bool(default = True),
    ),
)
