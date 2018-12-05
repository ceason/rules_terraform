load(":providers.bzl", "TerraformModuleInfo", "TerraformPluginInfo", "TerraformWorkspaceInfo", "tf_workspace_files_prefix")

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
    srcs = []
    srcs += ctx.attr.srcs
    for dep in ctx.attr.embed:
        srcs += dep[TerraformModuleInfo].srcs
    return srcs

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
    for dep in ctx.embed.embed:
        info = dep[TerraformModuleInfo]
        for path, f in getattr(info, "file_map", {}).items():
            if path in file_map and f != file_map[path]:
                fail("Conflicting files for path '%s' (%s, %s)" % (path, f, file_map[path]), attr = "data")
            file_map[path] = f
        file_tars += getattr(info, "file_tars") or []
    return file_map, depset(transitive = file_tars)

def _collect_plugins(ctx):
    transitive = []
    for dep in ctx.attr.embed:
        transitive += dep[TerraformModuleInfo].plugins
    return depset(direct = ctx.attr.plugins, transitive = transitive)

def _collect_deps(ctx):
    transitive = []
    transitive += ctx.attr.deps
    for dep in ctx.attr.embed:
        transitive += dep[TerraformModuleInfo].modules
    return depset(direct = ctx.attr.modules, transitive = transitive)

def _generate_docs(ctx, srcs, md_output = None, json_output = None):
    fail("Unimplemented")
    ctx.actions.run_shell(
        inputs = [
            ctx.outputs.out,
            ctx.executable._terraform_docs,
        ],
        outputs = [
            ctx.outputs.docs_md,
            ctx.outputs.docs_json,
        ],
        arguments = [
            ctx.outputs.out.path,
            ctx.outputs.docs_md.path,
            ctx.outputs.docs_json.path,
        ],
        command = """#!/usr/bin/env bash
    set -euo pipefail
    terraform_docs="%s"
    module_dir=$(mktemp -d)
    tar -xf "$1" -C "$module_dir"
    $terraform_docs --sort-inputs-by-required md   "$module_dir" > "$2"
    $terraform_docs --sort-inputs-by-required json "$module_dir" > "$3"
    rm -rf "$module_dir"
            """ % ctx.executable._terraform_docs.path,
        tools = ctx.attr._terraform_docs.default_runfiles.files,
    )

def _resolve_srcs(
        ctx,
        module_resolved_srcs_output = None,
        root_resolved_srcs_output = None):
    fail("Unimplemented")

def _create_root_bundle(ctx, output, module_info):
    fail("Unimplemented")

def module_impl(ctx, modulepath = None):
    """
    """
    modulepath = modulepath or ctx.attr.modulepath or ctx.attr.name

    # collect & resolve sources
    srcs = _collect_srcs(ctx)
    module_resolved_srcs = ctx.actions.declare_file(ctx.attr.name + ".module-srcs.tar")
    root_resolved_srcs = ctx.actions.declare_file(ctx.attr.name + ".root-srcs.tar")
    _resolve_srcs(
        ctx,
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

    # collect modules, plugins & we can finally create our TerraformModuleInfo!
    modules = _collect_deps(ctx)
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
    _create_root_bundle(ctx, ctx.outputs.out, module_info)

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
