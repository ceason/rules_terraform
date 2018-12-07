load(":providers.bzl", "TerraformModuleInfo", "TerraformPluginInfo", "TerraformWorkspaceInfo", "tf_workspace_files_prefix")
load("//experimental/internal/embedding:embedder.bzl", "get_valid_labels")

_module_attrs = {
    "srcs": attr.label_list(
        allow_files = [".tf"],
        default = [],
    ),
    "data": attr.label_list(
        allow_files = True,
        default = [],
    ),
    "embed": attr.label_list(
        doc = "Merge the content of other <terraform_module>s (or other 'ModuleInfo' providing deps) into this one.",
        providers = [TerraformModuleInfo],
        default = [],
    ),
    "deps": attr.label_list(
        providers = [TerraformModuleInfo],
        default = [],
    ),
    "plugins": attr.label_list(
        doc = "Custom Terraform plugins that this module requires.",
        providers = [TerraformPluginInfo],
        default = [],
    ),
    "modulepath": attr.string(),
}

module_outputs = {
    "out": "%{name}.tar.gz",
    "docs_md": "%{name}_docs.md",
    "docs_json": "%{name}_docs.json",
}

module_tool_attrs = {
    "_terraform_docs": attr.label(
        default = Label("@tool_terraform_docs"),
        executable = True,
        cfg = "host",
    ),
    "_resolve_srcs": attr.label(
        default = Label("//terraform/internal:resolve_srcs"),
        executable = True,
        cfg = "host",
    ),
    "_create_root_bundle": attr.label(
        default = Label("//terraform/internal:create_root_bundle"),
        executable = True,
        cfg = "host",
    ),
}

def _collect_srcs(ctx):
    srcs = {}
    for f in ctx.files.srcs:
        if f.basename in srcs and srcs[f.basename] != f:
            fail("Cannot have multiple files with same basename (%s, %s)" % (f, srcs[f.basename]), attr = "srcs")
        srcs[f.basename] = f
    for dep in ctx.attr.embed:
        if getattr(dep[TerraformModuleInfo], "srcs"):
            for f in dep[TerraformModuleInfo].srcs:
                if f.basename in srcs and srcs[f.basename] != f:
                    fail("Cannot have multiple files with same basename (%s, %s)" % (f, srcs[f.basename]), attr = "srcs")
    return srcs.values()

def _collect_data(ctx):
    file_map = {}
    file_tars = []
    for f in ctx.files.data:
        label = f.owner or ctx.label
        prefix = label.package + "/"
        path = f.short_path[len(prefix):]
        if path in file_map and f != file_map[path]:
            fail("Conflicting files for path '%s' (%s, %s)" % (path, f, file_map[path]), attr = "data")
        file_map[path] = f
    for dep in ctx.attr.embed:
        info = dep[TerraformModuleInfo]
        for path, f in getattr(info, "file_map", {}).items():
            if path in file_map and f != file_map[path]:
                fail("Conflicting files for path '%s' (%s, %s)" % (path, f, file_map[path]), attr = "data")
            file_map[path] = f
        if getattr(info, "file_tars"):
            file_tars += [info.file_tars]
    return file_map, depset(transitive = file_tars)

def _collect_plugins(ctx):
    transitive = []
    for dep in ctx.attr.embed:
        if getattr(dep[TerraformModuleInfo], "plugins"):
            transitive += [dep[TerraformModuleInfo].plugins]
    return depset(direct = ctx.attr.plugins, transitive = transitive)

def _collect_deps(ctx):
    transitive = []
    for dep in ctx.attr.embed:
        if getattr(dep[TerraformModuleInfo], "modules"):
            transitive += dep[TerraformModuleInfo].modules
    return depset(direct = ctx.attr.deps, transitive = transitive)

def _generate_docs(ctx, srcs, md_output = None, json_output = None):
    files = ctx.actions.args()
    files.add_all([f for f in srcs if f.extension == "tf"])
    ctx.actions.run_shell(
        inputs = srcs + [ctx.executable._terraform_docs],
        outputs = [md_output, json_output],
        arguments = [
            ctx.executable._terraform_docs.path,
            md_output.path,
            json_output.path,
            files,
        ],
        command = """set -eu
terraform_docs="$1"; shift
md_out="$1"; shift
json_out="$1"; shift
"$terraform_docs" --sort-inputs-by-required md   "$@" > "$md_out"
"$terraform_docs" --sort-inputs-by-required json "$@" > "$json_out"
""",
        tools = ctx.attr._terraform_docs.default_runfiles.files,
    )

def _resolve_srcs(
        ctx,
        modulepath = None,
        srcs = None,
        modules = None,
        module_resolved_srcs_output = None,
        root_resolved_srcs_output = None):
    args = ctx.actions.args()
    args.add("--modulepath", modulepath)
    args.add("--module_resolved_output", module_resolved_srcs_output)
    args.add("--root_resolved_output", root_resolved_srcs_output)
    for f in srcs:
        args.add("--input", f)
    for m in modules:
        info = m[TerraformModuleInfo]
        if not getattr(info, "modulepath"):
            fail("Implementation error. %s's TerraformModuleInfo provider has no 'modulepath' field." % ctx.label, attr = "deps")
        args.add("--embedded_module", struct(
            label = str(m.label),
            modulepath = info.modulepath,
            valid_labels = get_valid_labels(ctx, m.label),
        ).to_json())
    ctx.actions.run(
        inputs = srcs,
        outputs = [module_resolved_srcs_output, root_resolved_srcs_output],
        arguments = [args],
        mnemonic = "ResolveTerraformSrcs",
        executable = ctx.executable._resolve_srcs,
        tools = ctx.attr._resolve_srcs.default_runfiles.files,
    )

def _create_root_bundle(ctx, output, root_resolved_srcs, module_info):
    args = ctx.actions.args()
    inputs = []
    transitive = []

    args.add("--output", output)

    # get relevant data from the immediate module
    args.add_all("--input_tar", ["", root_resolved_srcs])
    inputs += [root_resolved_srcs]
    if module_info.file_map:
        for path, file in module_info.file_map.items():
            args.add_all("--input_file", [path, file])
            inputs += [file]
    if module_info.file_tars:
        transitive += [module_info.file_tars]
        for f in module_info.file_tars.to_list():
            args.add_all("--input_tar", ["", f])

    # get relevant data from dependant modules
    if module_info.modules:
        for dep in module_info.modules.to_list():
            m = dep[TerraformModuleInfo]
            args.add_all("--input_tar", [m.modulepath, m.resolved_srcs])
            inputs += [m.resolved_srcs]
            for f in m.file_tars.to_list():
                args.add_all("--input_tar", [m.modulepath, f])
            transitive += [m.file_tars]
            if getattr(m, "file_map"):
                for path, file in m.file_map.items():
                    args.add_all("--input_file", ["modules/%s/%s" % (m.modulepath, path), file])
                    inputs += [file]
    ctx.actions.run(
        inputs = depset(direct = inputs, transitive = transitive),
        outputs = [output],
        arguments = [args],
        mnemonic = "CreateTerraformRootBundle",
        executable = ctx.executable._create_root_bundle,
        tools = ctx.attr._create_root_bundle.default_runfiles.files,
    )

def module_impl(ctx, modulepath = None):
    """
    """
    modulepath = modulepath or ctx.attr.modulepath or ctx.attr.name

    # collect & resolve sources
    srcs = _collect_srcs(ctx)
    module_resolved_srcs = ctx.actions.declare_file(ctx.attr.name + ".module-srcs.tar")
    root_resolved_srcs = ctx.actions.declare_file(ctx.attr.name + ".root-srcs.tar")
    modules = _collect_deps(ctx)
    _resolve_srcs(
        ctx,
        modulepath = modulepath,
        srcs = srcs,
        modules = modules,
        module_resolved_srcs_output = module_resolved_srcs,
        root_resolved_srcs_output = root_resolved_srcs,
    )

    # generate docs from sources
    _generate_docs(
        ctx,
        srcs,
        md_output = ctx.outputs.docs_md,
        json_output = ctx.outputs.docs_json,
    )

    # collect files & add generated docs
    file_map, file_tars = _collect_data(ctx)
    file_map["README.md"] = ctx.outputs.docs_md

    # collect plugins & we can finally create our TerraformModuleInfo!
    plugins = _collect_plugins(ctx)
    module_info = TerraformModuleInfo(
        modulepath = modulepath,
        srcs = srcs,
        resolved_srcs = module_resolved_srcs,
        file_map = file_map,
        file_tars = file_tars,
        plugins = plugins,
        modules = modules,
    )

    # create the "root module bundle" by providing our module_info
    _create_root_bundle(ctx, ctx.outputs.out, root_resolved_srcs, module_info)

    # return our module_info on a struct so other things can use it
    return struct(
        terraform_module_info = module_info,
        providers = [
            module_info,
            DefaultInfo(files = depset(direct = [ctx.outputs.out])),
            OutputGroupInfo(docs = [ctx.outputs.docs_md]),
        ],
    )

terraform_module = rule(
    module_impl,
    attrs = module_tool_attrs + _module_attrs,
    outputs = module_outputs,
)
