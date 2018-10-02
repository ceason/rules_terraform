PluginInfo = provider(
    fields = {
        "files": "Map of 'filesRelativeToPluginDir' => 'File'",
    },
)

ModuleInfo = provider(
    fields = {
        "files": "map of target filename => File (aggregated from `srcs`, `embed` and `modules`)",
        "plugins": "Depset of targets with the 'PluginInfo' provider",
        "k8s_objects": "List of 'struct(target<Target>, output_prefix<string>)'. Must produce a yaml stream of k8s objects when run (eg _k8s_object)",
        "description": "String. Optional description of module.",
        "render_tf": "Executable File. Will render terraform (and plugins) to specified output directory",
    },
)

WorkspaceInfo = provider(
    fields = {
        "render_tf": "Executable File. Will render terraform (and plugins) to specified output directory",
    },
)

DistributionDirInfo = provider()


# Workspace files are prefixed as '.rules_terraform/{tf_workspace_name}'
def tf_workspace_files_prefix(target):
    format = ".rules_terraform/%s"
    if hasattr(target, "label"):
        return format % target.label.name
    if hasattr(target, "name"):
        return format % target.name
    return format % target.split(":")[-1]
