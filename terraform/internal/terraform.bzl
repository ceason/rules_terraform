load(":providers.bzl", "TerraformModuleInfo", "TerraformPluginInfo", "TerraformWorkspaceInfo", "tf_workspace_files_prefix")
load("//terraform/internal:terraform_lib.bzl", "create_terraform_renderer", "runfiles_path", "tf_renderer_attrs")

def _impl(ctx):
    """
    """
    provider_name = ctx.attr.provider_name
    if not provider_name:
        if ctx.attr.name.startswith("terraform-provider-"):
            provider_name = ctx.attr.name[len("terraform-provider-"):]
        elif ctx.attr.file.label.name.startswith("terraform-provider-"):
            provider_name = ctx.attr.file.label.name[len("terraform-provider-"):]
        else:
            fail("Could not determine provider_name. Please specify explicitly, or provide a name (or file) attribute formatted as 'terraform-provider-{provider_name}'.", attr = "provider_name")

    version = ctx.attr.version
    if not version.startswith("v"):
        version = "v" + version
    filename = "terraform-provider-%s_%s" % (provider_name, version)
    file_map = {
        "linux_amd64/%s" % filename: ctx.file.file,
        "darwin_amd64/%s" % filename: ctx.file.file,
        "windows_amd64/%s.exe" % filename: ctx.file.file,
    }
    return [TerraformPluginInfo(files = file_map)]

terraform_provider = rule(
    _impl,
    attrs = {
        # todo: maybe make version stampable?
        "version": attr.string(default = "v999.9.9"),
        "provider_name": attr.string(default = "", doc = "Name of terraform provider."),
        "file": attr.label(allow_single_file = True),
    },
)
