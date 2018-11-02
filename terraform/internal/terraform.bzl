load("//terraform:providers.bzl", "ModuleInfo", "PluginInfo", "WorkspaceInfo", "tf_workspace_files_prefix")
load("//terraform/internal:terraform_lib.bzl", "create_terraform_renderer", "runfiles_path", "tf_renderer_attrs")
load(
    "//terraform/internal:image_embedder_lib.bzl",
    _create_image_publisher = "create_image_publisher",
    _image_publisher_aspect = "image_publisher_aspect",
    _image_publisher_attrs = "image_publisher_attrs",
    _embed_images = "embed_images",
)

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

    runfiles = []
    transitive_runfiles = []
    transitive_plugins = []
    file_map = {}
    file_generators = []

    # aggregate files
    for f in ctx.files.srcs:
        label = f.owner or ctx.label
        prefix = label.package + "/"
        path = f.short_path[len(prefix):]
        file_map[path] = f
        runfiles.append(f)

    # todo: validate that no files (src or embedded) collide with 'modules' attribute (eg module is
    # only thing allowed to populate its subpath)
    # - test that `filepath` does not begin with `module+"/"` for all configured modules
    embeds = []
    embeds.extend(ctx.attr.embed or [])
    if ctx.attr.deps:
        print("Attribute 'deps' is deprecated. Use 'embed' instead (%s)" % ctx.label)
        embeds.extend(ctx.attr.deps or [])
    for dep in embeds:
        transitive_runfiles.append(dep.default_runfiles.files)
        mi = dep[ModuleInfo]
        if hasattr(mi, "file_generators"):
            file_generators.extend(mi.file_generators)
        if hasattr(mi, "plugins"):
            transitive_plugins.append(mi.plugins)
        if hasattr(mi, "files"):
            for filename, file in mi.files.items():
                if filename in file_map and file_map[filename] != file:
                    fail("Cannot embed file '%s' from module '%s' because it already comes from '%s'" % (
                        filename,
                        dep.label,
                        file_map[filename].short_path,
                    ), attr = "embed")
                file_map[filename] = file

    for m, module_name in ctx.attr.modules.items():
        transitive_runfiles.append(m.default_runfiles.files)
        mi = m[ModuleInfo]
        if hasattr(mi, "plugins"):
            transitive_plugins.append(mi.plugins)
        if hasattr(mi, "file_generators"):
            # make the imported module's generated files relative to its own subdirectory
            for o in mi.file_generators:
                file_generators.append(struct(
                    executable = o.executable,
                    output_prefix = "%s/%s" % (module_name, o.output_prefix),
                ))
        if hasattr(mi, "files"):
            # make the imported module's files relative to its own subdirectory
            for filename, file in mi.files.items():
                newname = "%s/%s" % (module_name, filename)
                if newname in file_map and file_map[newname] != file:
                    fail("Cannot embed file '%s' from module '%s' because it already comes from '%s'" % (
                        filename,
                        dep.label,
                        file_map[filename].short_path,
                    ), attr = "embed")
                file_map[newname] = file

    # dedupe any file generators we got
    file_generators = {k: None for k in file_generators}.keys()

    module_info = ModuleInfo(
        files = file_map,
        file_generators = file_generators,
        plugins = depset(direct = ctx.attr.plugins or [], transitive = transitive_plugins),
        description = ctx.attr.description,
    )

    providers = [module_info]

    # if this is a workspace, create a launcher
    if ctx.attr._is_workspace:
        image_publisher = ctx.actions.declare_file(ctx.attr.name + ".image-publisher")
        runfiles.append(image_publisher)
        transitive_runfiles.append(_create_image_publisher(
            ctx,
            image_publisher,
            ctx.attr.deps + ctx.attr.embed + ctx.attr.modules.keys(),
        ))

        # bundle the renderer with args for the content of this tf module
        render_tf = ctx.actions.declare_file("%s.render-tf" % ctx.attr.name)
        transitive_runfiles.append(create_terraform_renderer(ctx, render_tf, module_info))
        ctx.actions.expand_template(
            template = ctx.file._workspace_launcher_template,
            output = ctx.outputs.executable,
            substitutions = {
                "%{package}": ctx.label.package,
                "%{tf_workspace_files_prefix}": tf_workspace_files_prefix(ctx.attr.name),
                "%{render_tf}": render_tf.short_path,
                "%{artifact_publishers}": image_publisher.short_path,
            },
        )
        providers.append(WorkspaceInfo(render_tf = render_tf))

    return providers + [DefaultInfo(runfiles = ctx.runfiles(
        files = runfiles,
        transitive_files = depset(transitive = transitive_runfiles),
    ))]

def _common_attrs(aspects = []):
    return tf_renderer_attrs + {
        "srcs": attr.label_list(
            allow_files = True,
            aspects = aspects,
        ),
        "deps": attr.label_list(
            doc = "Deprecated. Use 'embed' instead ('embed' is functionally identical to 'deps', but seems more semantically correct).",
            allow_rules = [
                "_k8s_object",
                "terraform_module",
            ],
            aspects = aspects,
        ),
        "embed": attr.label_list(
            # we should use "providers" instead, but "k8s_object" does not
            # currently (2018-9-8) support them
            doc = "Merge the content of other <terraform_module>s (or other 'ModuleInfo' providing deps) into this one.",
            providers = [ModuleInfo],
            aspects = aspects,
        ),
        "modules": attr.label_keyed_string_dict(
            # hack: disabling provider check until doc generator supports 'providers' attribute
            #   see https://github.com/bazelbuild/skydoc/blob/master/skydoc/stubs/attr.py#L180
            providers = [ModuleInfo],
            aspects = aspects,
        ),
        "description": attr.string(
            doc = "Optional description of module.",
            default = "",
        ),
        "plugins": attr.label_list(
            doc = "Custom Terraform plugins that this module requires.",
            providers = [PluginInfo],
        ),
    }

terraform_module = rule(
    implementation = _module_impl,
    attrs = dict(
        _common_attrs().items(),
        # hack: this flag lets us share the same implementation function as 'terraform_module'
        _is_workspace = attr.bool(default = False),
    ),
)

terraform_workspace = rule(
    implementation = _module_impl,
    executable = True,
    attrs = _common_attrs([_image_publisher_aspect]) + _image_publisher_attrs + {
        # hack: this flag lets us share the same implementation function as 'terraform_module'
        "_is_workspace": attr.bool(default = True),
        "_workspace_launcher_template" : attr.label(
            allow_single_file = True,
            default = "//terraform/internal:workspace_launcher.sh.tpl",
        ),
    },
)
