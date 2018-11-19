load("//terraform:providers.bzl", "ModuleInfo", "PluginInfo", "WorkspaceInfo", "tf_workspace_files_prefix")
load("//terraform/internal:terraform_lib.bzl", "create_terraform_renderer", "runfiles_path", "tf_renderer_attrs")
load(
    "//terraform/internal:image_embedder_lib.bzl",
    _create_image_publisher = "create_image_publisher",
    _embed_images = "embed_images",
    _image_publisher_aspect = "image_publisher_aspect",
    _image_publisher_attrs = "image_publisher_attrs",
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
