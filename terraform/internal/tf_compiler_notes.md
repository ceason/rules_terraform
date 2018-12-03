
Modules can exist in two ways:
- as the root module
- non-root module (eg in the {tfroot}/modules dir)

This means we create an artifact for each way:
- bundle srcs+data+embed for just this module
  - one with module refs resolved as if we're the root module
  - another with module refs resolved as if we're non-root module

Providers:
- TerraformModuleInfo
  - modulepath: this module's location within the 'modules/' dir.
  - srcs: List<File> of sources
    - ^ error when file.basename conflicts
  - resolved_srcs: tar bundle of this module's srcs, resolved as if we're in the non-root module
  - data: dict of "path => <File>"
    - ^ error when files are in 'modules/' subdir
    - ^ error when embedding conflicting files
  - plugins: depset of "<Target(PluginInfo)>" of plugins required by this module
    - ^ workspace rule will warn when there are duplicate versions of same plugin
  - deps: "Depset<Target(ModuleInfo)>" of other modules required by this module
    - ^ compiler gives error when different modules have same modulepath
    - ^ compiler gives error when modulepath is a subdirectory within another module's modulepath

- DefaultInfo.files:
  - .tar.gz bundle of module data+srcs(resolved as if we're in the root module)
    - includes 'deps' modules data+srcs(from TerraformModuleInfo.resolved_srcs) in "modules/{modulepath}" subdirectory

- OutputGroupInfo
  - docs: %{name}_docs.md

- Predeclared Outputs:
  - docs_md: %{name}_docs.md
  - docs_json: %{name}_docs.json


### Toolchain tools / Compilation steps
resolve_srcs (eg 'compile')
> Resolves module source references from bazel labels to module path
- inputs: srcs, embedded_srcs
- outputs: module_resolved_srcs.tar, root_resolved_srcs.tar
^ ?consider adding docs to resolved srcs (README.md?)

create_root_bundle (eg 'link')
> Creates .tar.gz bundle of module data+srcs(resolved as if we're in
> the root module). Also includes 'deps' modules data+srcs(from
> TerraformModuleInfo.resolved_srcs) in "modules/{modulepath}" subdirectory
- inputs: root_resolved_srcs.tar, datafiles, deps_datafiles, deps_resolved_srcs
- outputs: %{name}.tar.gz


### Rule implementation
- collect:
  - srcs+embedded_srcs
  - data+embedded_data
  - plugins+embedded_plugins+deps_plugins
- resolve_srcs
- create_root_bundle
- create_docs