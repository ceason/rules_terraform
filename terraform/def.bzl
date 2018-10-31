load(
    "//terraform/internal:terraform.bzl",
    "terraform_plugin",
    _terraform_module = "terraform_module",
    _terraform_workspace = "terraform_workspace",
)
load("//terraform/internal:test.bzl", "terraform_integration_test")
load(
    "//terraform/internal:distribution.bzl",
    "terraform_distribution_publisher",
    "terraform_module_publisher",
    _terraform_distribution_dir = "terraform_distribution_dir",
)
load("//terraform:providers.bzl", "tf_workspace_files_prefix")

def terraform_distribution_dir(name, deps, **kwargs):
    srcs_name = "%s.srcs-list" % name
    module_name = "%s.module" % name

    # change "relative" deps to absolute deps
    deps_abs = [
        "//" + native.package_name() + dep if dep.startswith(":") else dep
        for dep in deps
    ]
    native.genquery(
        name = srcs_name,
        opts = ["--noimplicit_deps"],
        expression = """kind("source file", deps(set(%s)))""" % " ".join(deps_abs),
        scope = deps_abs,
    )

    terraform_module(
        name = module_name,
        deps = deps_abs,
    )

    _terraform_distribution_dir(
        name = name,
        srcs_list = ":" + srcs_name,
        module = ":" + module_name,
        **kwargs
    )

def _flip_modules_attr(modules):
    """
    Translate modules attr from a 'name=>label' dict to 'label=>name'
    """
    flipped = {}
    for name, label in modules.items():
        if not (label.startswith("@") or label.startswith("//") or label.startswith(":")):
            fail("Modules are now specified as 'name=>label'", attr="modules")
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
        modules = _flip_modules_attr(modules),
        **kwargs
    )

def terraform_workspace(name, modules = {}, **kwargs):
    _terraform_workspace(
        name = name,
        modules = _flip_modules_attr(modules),
        **kwargs
    )

    # create a convenient destroy target which
    # CDs to the package dir and runs terraform destroy
    native.genrule(
        name = "%s.destroy" % name,
        outs = ["%s.destroy.sh" % name],
        cmd = """echo '
            #!/bin/sh
            set -eu
            tf_workspace_dir="$$BUILD_WORKSPACE_DIRECTORY/{package}/{tf_workspace_files_prefix}"
            if [ -e "$$tf_workspace_dir" ]; then
                cd "$$tf_workspace_dir"
                exec terraform destroy "$$@" .terraform/tfroot
            else
                >&2 echo "Could not find terraform workspace dir, so there is nothing to destroy ($$tf_workspace_dir)"
            fi
            ' > $@""".format(
            package = native.package_name(),
            tf_workspace_files_prefix = tf_workspace_files_prefix(name),
        ),
        executable = True,
    )
