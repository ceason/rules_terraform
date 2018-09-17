load("//terraform:providers.bzl", "DistributionDirInfo", "ModuleInfo", "PluginInfo")
load(":module.bzl", "terraform_module")
load(":util.bzl", "merge_filemap_dict")

def _distribution_dir_impl(ctx):
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
    implementation = _distribution_dir_impl,
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
            default = Label("@tool_terraform_docs"),
            executable = True,
            cfg = "host",
        ),
        "_terraform": attr.label(
            default = Label("@tool_terraform"),
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




def _distribution_publisher_impl(ctx):
    """
    """
    runfiles = []
    transitive_runfiles = []
    env_vars = []
    distrib_dir_targets = []

    for dep in ctx.attr.deps:
        transitive_runfiles.append(dep.data_runfiles.files)
        transitive_runfiles.append(dep.default_runfiles.files)
        distrib_dir_targets.append(dep.label)

    for name, value in ctx.attr.env.items():
        if "'" in name or "\\" in name or "=" in name:
            fail("Env var names may not contain the following characters: \\,',= (got '%s') " % name, attr = "env")
        if "'" in value or "\\" in value:
            fail("Env var values may not contain the following characters: \\,' (got '%s') " % name, attr = "env")
        env_vars.append("'%s=%s'" % (name, value))

    # expand the runner template
    ctx.actions.expand_template(
        template = ctx.file._template,
        substitutions = {
            "%{env_vars}": " ".join(env_vars),
            "%{prepublish_tests}": " ".join(["'%s'" % t for t in ctx.attr.prepublish_tests or []]),
            "%{prepublish_builds}": " ".join(["'%s'" % t for t in ctx.attr.prepublish_builds or []]),
            "%{distrib_dir_targets}": " ".join(distrib_dir_targets),
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
    )]

terraform_distribution_publisher = rule(
    implementation = _distribution_publisher_impl,
    attrs = {
        "deps": attr.label_list(
            mandatory = True,
            providers = [DistributionDirInfo],
        ),
        "_template": attr.label(
            default = Label("//terraform/internal:publisher.sh.tpl"),
            single_file = True,
            allow_files = True,
        ),
        "prepublish_builds": attr.string_list(
            doc = "Ensure these target patterns build prior to publishing (eg make sure '//...' builds)",
            default = ["//..."],
        ),
        "prepublish_tests": attr.string_list(
            doc = "Ensure these tests pass prior to publishing (eg '//...', plus explicitly enumerating select tests tagged as 'manual')",
            default = ["//..."],
        ),
        "env": attr.string_dict(
            doc = "Environment variables set when publishing (useful in conjunction with '--workspace_status_command' script)",
            default = {},
        ),
    },
    executable = True,
)
