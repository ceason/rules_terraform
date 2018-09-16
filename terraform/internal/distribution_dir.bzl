load("//terraform:providers.bzl", "DistributionDirInfo", "ModuleInfo", "PluginInfo")
load(":module.bzl", "terraform_module")
load(":util.bzl", "merge_filemap_dict")

def _impl(ctx):
    """
    """
    runfiles = []
    transitive_runfiles = []
    renderer_args = []

    module = ctx.attr.module[ModuleInfo]
    transitive_runfiles.append(ctx.attr.module.data_runfiles.files)
    for path, file in module.files.items():
        renderer_args.extend(["--file", path, file.short_path])
        runfiles.append(file)

    for o in module.k8s_objects.to_list():
        renderer_args.extend(["--k8s_object", ".", o])

    if module.plugins:
        for p in module.plugins.to_list():
            plugin = p[PluginInfo]
            for path, file in plugin.files.items():
                renderer_args.extend(["--plugin_file", path, file.short_path])
                runfiles.append(file)

    renderer_argsfile = ctx.actions.declare_file("%s.render-args" % ctx.label.name)
    runfiles.append(renderer_argsfile)
    ctx.actions.write(renderer_argsfile, "\n".join(renderer_args))

    # add tools' runfiles
    transitive_runfiles.append(ctx.attr._render_tf.data_runfiles.files)
    transitive_runfiles.append(ctx.attr._terraform_docs.data_runfiles.files)

    runfiles.append(ctx.file.srcs_list)

    # expand the runner template
    ctx.actions.expand_template(
        template = ctx.file._template,
        substitutions = {
            "%{output_dir}": ctx.label.name,
            "%{package}": ctx.label.package,
            "%{workspace_name}": ctx.workspace_name,
            "%{srcs_list_path}": ctx.file.srcs_list.short_path,
            "%{readme_description}": ctx.attr.description,
            "%{render_tf}": ctx.executable._render_tf.short_path,
            "%{argsfile}": renderer_argsfile.short_path,
        },
        output = ctx.outputs.executable,
    )

    return [DefaultInfo(
        runfiles = ctx.runfiles(
            files = runfiles,
            transitive_files = depset(transitive = transitive_runfiles),
            collect_data = True,
            collect_default = True,
        ),
    ), DistributionDirInfo()]

terraform_distribution_dir = rule(
    implementation = _impl,
    attrs = {
        "srcs_list": attr.label(mandatory = True, single_file = True),
        "description": attr.string(default = ""),
        "module": attr.label(
            mandatory = True,
            providers = [ModuleInfo],
        ),
        "_template": attr.label(
            default = Label("//terraform/internal:distribution_dir.sh.tpl"),
            single_file = True,
            allow_files = True,
        ),
        "_terraform_docs": attr.label(
            default = Label("@tool_terraform_docs//:binary"),
            executable = True,
            cfg = "host",
        ),
        "_terraform": attr.label(
            default = Label("@tool_terraform//:binary"),
            executable = True,
            cfg = "host",
        ),
        "_render_tf": attr.label(
            executable = True,
            cfg = "host",
            default = "//terraform/internal:render_tf",
        ),
    },
    executable = True,
)

def terraform_distribution_dir_macro(name, deps, **kwargs):
    srcs_name = "%s.srcs-list" % name
    module_name = "%s.module" % name

    # change "relative" deps to absolute deps
    deps_abs = [
        "//" + native.package_name() + dep if dep.startswith(":") else dep
        for dep in deps
    ]
    native.genquery(
        name = srcs_name,
        opts = ["--noimplicit_deps"],
        expression = """kind("source file", deps(set(%s)))""" % " ".join(deps_abs),
        scope = deps_abs,
    )

    terraform_module(
        name = module_name,
        deps = deps_abs,
    )

    terraform_distribution_dir(
        name = name,
        srcs_list = ":" + srcs_name,
        module = ":" + module_name,
        **kwargs
    )
