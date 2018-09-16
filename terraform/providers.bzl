PluginInfo = provider(
    fields = {
        "files": "Map of 'filesRelativeToPluginDir' => 'File'",
    },
)

ModuleInfo = provider(
    fields = {
        "files": "map of target filename => File (aggregated from `src` and `deps`)",
        "plugins": "Depset of targets with the 'PluginInfo' provider",
        "k8s_objects": "Depset of executables that produce k8s objects when run??",
    },
)

WorkspaceInfo = provider()

DistributionDirInfo = provider()