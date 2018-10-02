load("//terraform:providers.bzl", "WorkspaceInfo", "tf_workspace_files_prefix")

def _integration_test_impl(ctx):
    """
    """

    runfiles = []
    transitive_runfiles = []

    transitive_runfiles.append(ctx.attr._runner_template.data_runfiles.files)
    transitive_runfiles.append(ctx.attr._stern.data_runfiles.files)
    transitive_runfiles.append(ctx.attr.srctest.data_runfiles.files)
    transitive_runfiles.append(ctx.attr.terraform_workspace.data_runfiles.files)
    render_tf = ctx.attr.terraform_workspace[WorkspaceInfo].render_tf

    ctx.actions.expand_template(
        template = ctx.file._runner_template,
        substitutions = {
            "%{render_tf}": render_tf.short_path,
            "%{srctest}": ctx.executable.srctest.short_path,
            "%{stern}": ctx.executable._stern.short_path,
            "%{tf_workspace_files_prefix}": tf_workspace_files_prefix(ctx.attr.terraform_workspace),
        },
        output = ctx.outputs.executable,
        is_executable = True,
    )

    return [DefaultInfo(
        runfiles = ctx.runfiles(
            transitive_files = depset(transitive = transitive_runfiles),
            #            collect_data = True,
            #            collect_default = True,
        ),
    )]

# Wraps the source test with infrastructure spinup and teardown
terraform_integration_test = rule(
    test = True,
    implementation = _integration_test_impl,
    attrs = {
        "terraform_workspace": attr.label(
            doc = "TF Workspace to spin up before testing & tear down after testing.",
            mandatory = True,
            executable = True,
            cfg = "host",
            providers = [WorkspaceInfo],
        ),
        "srctest": attr.label(
            doc = "Label of source test to wrap",
            mandatory = True,
            executable = True,
            cfg = "target",  # 'host' does not work for jvm source tests, because it launches with @embedded_jdk//:jar instead of @local_jdk//:jar
        ),
        "_runner_template": attr.label(
            default = "//terraform/internal:integration_test_runner.sh.tpl",
            allow_single_file = True,
        ),
        "_stern": attr.label(
            executable = True,
            cfg = "host",
            default = "@tool_stern",
        ),
    },
)
