load("//terraform:providers.bzl", "ModuleInfo", "PluginInfo")
load(":util.bzl", "merge_filemap_dict")

def _impl(ctx):
    """
    """

    # aggregate plugins/deps/etc
    files = {}
    k8s_objects = []
    transitive_k8s_objects = []
    runfiles = []
    transitive_runfiles = []
    transitive_plugins = []
    for f in ctx.files.srcs:
        label = f.owner or ctx.label
        prefix = label.package + "/"
        path = f.short_path[len(prefix):]
        files[path] = f
        runfiles.append(f)
    for dep in ctx.attr.deps:
        transitive_runfiles.append(dep.default_runfiles.files)
        if ModuleInfo in dep:
            mi = dep[ModuleInfo]
            files = merge_filemap_dict(files, mi.files)
            if mi.k8s_objects:
                transitive_k8s_objects.append(mi.k8s_objects)
            if mi.plugins:
                transitive_plugins.append(mi.plugins)
        else:
            # we assume this is a '_k8s_object'...
            l = dep.label
            k8s_executable = "%s/%s" % (l.package, l.name)
            k8s_objects.append(k8s_executable)

    return [
        ModuleInfo(
            files = files,
            plugins = depset(direct = ctx.attr.plugins, transitive = transitive_plugins),
            k8s_objects = depset(direct = k8s_objects, transitive = transitive_k8s_objects),
        ),
        DefaultInfo(
            runfiles = ctx.runfiles(
                files = runfiles,
                transitive_files = depset(transitive = transitive_runfiles),
            ),
        ),
    ]

terraform_module = rule(
    implementation = _impl,
    attrs = {
        "srcs": attr.label_list(allow_files = True),
        "deps": attr.label_list(
            # we should use "providers" instead, but "k8s_object" does not
            # currently (2018-9-8) support them
            allow_rules = [
                "_k8s_object",
                "terraform_module",
            ],
        ),
        "plugins": attr.label_list(
            providers = [PluginInfo],
        ),
    },
)
