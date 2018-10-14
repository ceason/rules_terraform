load("//terraform:providers.bzl", "DistributionDirInfo", "ModuleInfo", "PluginInfo")
load(":terraform.bzl", "terraform_module")
load("//terraform/internal:terraform_lib.bzl", "create_terraform_renderer", "runfiles_path", "tf_renderer_attrs")

def _distribution_dir_impl(ctx):
    """
    """
    runfiles = []
    transitive_runfiles = []
    renderer_args = []

    module = ctx.attr.module[ModuleInfo]
    transitive_runfiles.append(ctx.attr.module.data_runfiles.files)

    # add tools' runfiles
    transitive_runfiles.append(ctx.attr._terraform_docs.data_runfiles.files)

    runfiles.append(ctx.file.srcs_list)

    # bundle the renderer with args for the content of this tf module
    render_tf = ctx.actions.declare_file("%s.render-tf" % ctx.attr.name)
    transitive_runfiles.append(create_terraform_renderer(ctx, render_tf, module))

    # expand the runner template
    ctx.actions.expand_template(
        template = ctx.file._template,
        substitutions = {
            "%{workspace_name}": ctx.workspace_name,
            "%{srcs_list_path}": ctx.file.srcs_list.short_path,
            "%{readme_description}": ctx.attr.description or module.description,
            "%{render_tf}": render_tf.short_path,
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
    attrs = dict(
        tf_renderer_attrs.items(),
        srcs_list = attr.label(mandatory = True, single_file = True),
        description = attr.string(default = ""),
        module = attr.label(
            mandatory = True,
            providers = [ModuleInfo],
        ),
        _template = attr.label(
            default = Label("//terraform/internal:distribution_dir.sh.tpl"),
            single_file = True,
            allow_files = True,
        ),
        _terraform_docs = attr.label(
            default = Label("@tool_terraform_docs"),
            executable = True,
            cfg = "host",
        ),
        _terraform = attr.label(
            default = Label("@tool_terraform"),
            executable = True,
            cfg = "host",
        ),
    ),
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
        distrib_dir_targets.append("%s=%s" % (dep.label.name, dep.label))

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
            "%{package}": ctx.label.package,
            "%{remote}": ctx.attr.remote or "",
            "%{remote_path}": ctx.attr.remote_path or "",
            "%{remote_branch}": ctx.attr.remote_branch or "master",
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
        "remote": attr.string(doc = "Git remote URI. Publish to this repo instead of a local directory."),
        "remote_path": attr.string(),
        "remote_branch": attr.string(default = "master"),
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

def terraform_module_publisher(name, published_modules = {}, **kwargs):
    """
    """

    # for each output path, create a 'distribution_dir' & srcs list
    dist_dirs = []
    for path, label in published_modules.items():
        label_abs = "//" + native.package_name() + label if label.startswith(":") else label
        srcs_name = "%s.srcs-list" % path
        native.genquery(
            name = srcs_name,
            opts = ["--noimplicit_deps"],
            expression = """kind("source file", deps(%s))""" % label_abs,
            scope = [label_abs],
        )
        dist_dirs.append(":%s" % path)
        terraform_distribution_dir(
            name = path,
            module = label,
            srcs_list = srcs_name,
        )

    terraform_distribution_publisher(
        name = name,
        deps = dist_dirs,
        **kwargs
    )
