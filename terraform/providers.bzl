PluginInfo = provider(
    fields = {
        "files": "Map of 'filesRelativeToPluginDir' => 'File'",
        "platform_executables": "Map of 'os_arch (eg linux_amd64)' => 'File'",
    },
)

ModuleInfo = provider(
    fields = {
        "files": "map of target filename => File (aggregated from `srcs`, `embed` and `modules`)",
        "file_generators": "List of 'struct(executable<File>, output_prefix<string>).'",
        "plugins": "Depset of targets with the 'PluginInfo' provider",
        "description": "String. Optional description of module.",
    },
)

WorkspaceInfo = provider(
    fields = {
        "render_tf": "Executable File. Will render terraform (and plugins) to specified output directory",
    },
)

DistributionDirInfo = provider()

# Workspace files are prefixed as '.rules_terraform'
def tf_workspace_files_prefix(target):
    return ".rules_terraform"
