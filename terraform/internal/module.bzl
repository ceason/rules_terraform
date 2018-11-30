load("//terraform:providers.bzl", "ModuleInfo", "PluginInfo", "WorkspaceInfo", "tf_workspace_files_prefix")

def _module_impl(ctx, bundle_file = None):
    """
    """
    runfiles = []
    transitive_runfiles = []

    transitive_plugins = []
    bundle_inputs = []

    #bundle_file = ctx.actions.declare_file(ctx.attr.name + ".bundle.tar")
    bundle_file = ctx.outputs.out
    bundle_args = ctx.actions.args()
    bundle_args.add("--output", bundle_file)

    # aggregate files
    for f in ctx.files.srcs:
        label = f.owner or ctx.label
        prefix = label.package + "/"
        path = f.short_path[len(prefix):]
        bundle_args.add_all("--file", [path, f])
        bundle_inputs.append(f)

    for dep in ctx.attr.embed:
        mi = dep[ModuleInfo]
        if hasattr(mi, "plugins"):
            transitive_plugins.append(mi.plugins)
        if hasattr(mi, "tar"):
            bundle_inputs.append(mi.tar)
            bundle_args.add_all("--embed", [".", mi.tar])

    for m, module_name in ctx.attr.modules.items():
        mi = m[ModuleInfo]
        if hasattr(mi, "plugins"):
            transitive_plugins.append(mi.plugins)
        if hasattr(mi, "tar"):
            bundle_inputs.append(mi.tar)
            bundle_args.add_all("--embed", [module_name, mi.tar])

    ctx.actions.run(
        inputs = bundle_inputs,
        outputs = [bundle_file],
        arguments = [bundle_args],
        executable = ctx.executable._bundle_tool,
    )

    # todo: validate that no files (src or embedded) collide with 'modules' attribute (eg module is
    # only thing allowed to populate its subpath)

    module_info = ModuleInfo(
        tar = bundle_file,
        plugins = depset(direct = ctx.attr.plugins or [], transitive = transitive_plugins),
    )

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

    return struct(
        terraform_module_info = module_info,
        providers = [
            module_info,
            DefaultInfo(files = depset(direct = [ctx.outputs.out])),
            OutputGroupInfo(docs = [ctx.outputs.docs_md]),
        ],
    )

def _module_attrs(aspects = []):
    return {
        "srcs": attr.label_list(
            allow_files = True,
            aspects = aspects,
        ),
        "embed": attr.label_list(
            doc = "Merge the content of other <terraform_module>s (or other 'ModuleInfo' providing deps) into this one.",
            providers = [ModuleInfo],
            aspects = aspects,
        ),
        "modules": attr.label_keyed_string_dict(
            providers = [ModuleInfo],
            aspects = aspects,
        ),
        "plugins": attr.label_list(
            doc = "Custom Terraform plugins that this module requires.",
            providers = [PluginInfo],
        ),
        "_bundle_tool": attr.label(
            default = Label("//terraform/internal:bundle"),
            executable = True,
            cfg = "host",
        ),
        "_terraform_docs": attr.label(
            default = Label("@tool_terraform_docs"),
            executable = True,
            cfg = "host",
        ),
    }

module = struct(
    implementation = _module_impl,
    attributes = _module_attrs,
    outputs = {
        "out": "%{name}.tar",
        "docs_md": "%{name}_docs.md",
        "docs_json": "%{name}_docs.json",
    },
)

_terraform_module = rule(
    implementation = module.implementation,
    attrs = module.attributes(),
    outputs = module.outputs,
)

def flip_modules_attr(modules):
    """
    Translate modules attr from a 'name=>label' dict to 'label=>name'
    """
    flipped = {}
    for name, label in modules.items():
        if not (label.startswith("@") or label.startswith("//") or label.startswith(":")):
            fail("Modules are now specified as 'name=>label'", attr = "modules")

        # append package path & workspace name as necessary
        abs_label = "//" + native.package_name() + label if label.startswith(":") else label
        abs_label = native.repository_name() + abs_label if abs_label.startswith("//") else abs_label
        if abs_label in flipped:
            fail("Modules may only be specified once (%s)" % label, attr = "modules")
        flipped[abs_label] = name
    return flipped

def terraform_module(name, modules = {}, **kwargs):
    _terraform_module(
        name = name,
        modules = flip_modules_attr(modules),
        **kwargs
    )
