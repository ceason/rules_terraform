load("//terraform:providers.bzl", "DistributionDirInfo", "ModuleInfo", "PluginInfo")
load(":module.bzl", "terraform_module")
load(":util.bzl", "merge_filemap_dict")

def _impl(ctx):
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
            "%{prepublish_tests}": " ".join(ctx.attr.prepublish_tests),
            "%{prepublish_builds}": " ".join(ctx.attr.prepublish_builds),
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
    implementation = _impl,
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
            default = [],
        ),
        "prepublish_tests": attr.string_list(
            doc = "Ensure these tests pass prior to publishing (eg '//...', plus explicitly enumerating select tests tagged as 'manual')",
            default = [],
        ),
        "env": attr.string_dict(
            doc = "",
            default = {},
        ),
    },
    executable = True,
)
