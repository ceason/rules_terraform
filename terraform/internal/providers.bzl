TerraformPluginInfo = provider(
    fields = {
        "files": "Map of 'filesRelativeToPluginDir' => 'File'",
    },
)

TerraformModuleInfo = provider(
    fields = {
        "modulepath":"This module's location within the 'modules/' dir.",
        "srcs":"List<File> of sources",
        "resolved_srcs":".tar bundle of this module's srcs, resolved as if we're in the non-root module",
        "file_map":"dict of 'path => <File>'",
        "file_tars":"depset of .tar files to be unpacked into the module",
        "plugins":"depset <Target(PluginInfo)> of plugins required by this module",
        "modules":"depset <Target(ModuleInfo)> of other modules required by this module",
    },
)

TerraformWorkspaceInfo = provider(
    fields = {
        "render_workspace": "Executable File. Will render terraform (and plugins) to specified output directory",
    },
)

# Workspace files are prefixed as '.rules_terraform'
def tf_workspace_files_prefix(target=None):
    return ".rules_terraform"
