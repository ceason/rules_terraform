load(":providers.bzl", "TerraformWorkspaceInfo", "tf_workspace_files_prefix")
load("//experimental/internal/embedding:content_publisher.bzl", "create_content_publisher", "content_publisher_aspect", "content_publisher_attrs")

def _integration_test_impl(ctx):
    """
    """

    runfiles = []
    transitive_runfiles = []

    transitive_runfiles.append(ctx.attr._runner_template.default_runfiles.files)
    transitive_runfiles.append(ctx.attr._stern.default_runfiles.files)
    transitive_runfiles.append(ctx.attr._kubectl.default_runfiles.files)
    transitive_runfiles.append(ctx.attr.srctest.default_runfiles.files)
    transitive_runfiles.append(ctx.attr.terraform_workspace.default_runfiles.files)
    render_workspace = ctx.attr.terraform_workspace[TerraformWorkspaceInfo].render_workspace

    ctx.actions.expand_template(
        template = ctx.file._runner_template,
        substitutions = {
            "%{render_workspace}": render_workspace.short_path,
            "%{srctest}": ctx.executable.srctest.short_path,
            "%{stern}": ctx.executable._stern.short_path,
            "%{kubectl}": ctx.executable._kubectl.short_path,
        },
        output = ctx.outputs.executable,
        is_executable = True,
    )

    return [DefaultInfo(
        runfiles = ctx.runfiles(
            files = runfiles,
            transitive_files = depset(transitive = transitive_runfiles),
        ),
    )]

# Wraps the source test with infrastructure spinup and teardown
terraform_integration_test = rule(
    test = True,
    implementation = _integration_test_impl,
    attrs = content_publisher_attrs + {
        "terraform_workspace": attr.label(
            doc = "TF Workspace to spin up before testing & tear down after testing.",
            mandatory = True,
            executable = True,
            cfg = "host",
            providers = [TerraformWorkspaceInfo],
            aspects = [content_publisher_aspect],
        ),
        "srctest": attr.label(
            doc = "Label of source test to wrap",
            mandatory = True,
            executable = True,
            cfg = "target",  # 'host' does not work for jvm source tests, because it launches with @embedded_jdk//:jar instead of @local_jdk//:jar
            aspects = [content_publisher_aspect],
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
        "_kubectl": attr.label(
            executable = True,
            cfg = "host",
            default = "@tool_kubectl",
        ),
    },
)
