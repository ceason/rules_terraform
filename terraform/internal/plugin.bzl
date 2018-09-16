load("//terraform:providers.bzl", "ModuleInfo", "PluginInfo")

def _impl(ctx):
    """
    """
    file_map = {}
    for f in ctx.files.srcs:
        label = f.owner or ctx.label
        prefix = label.package + "/"
        plugin_path = f.short_path[len(prefix):]
        file_map[plugin_path] = f
    return [PluginInfo(files = file_map)]

terraform_plugin = rule(
    implementation = _impl,
    attrs = {
        "srcs": attr.label_list(
            doc = "These files will be placed in the 'terraform.d/plugins' directory in the TF workspace root.",
            allow_files = True,
        ),
    },
)
