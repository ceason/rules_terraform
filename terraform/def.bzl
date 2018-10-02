load("//terraform/internal:terraform.bzl", "terraform_module", "terraform_plugin", _terraform_workspace = "terraform_workspace")
load("//terraform/internal:test.bzl", "terraform_integration_test")
load("//terraform/internal:distribution.bzl", "terraform_distribution_publisher", "terraform_module_publisher", _terraform_distribution_dir = "terraform_distribution_dir")
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

def terraform_workspace(name, **kwargs):
    _terraform_workspace(
        name = name,
        **kwargs
    )

    # create a convenient destroy target which
    # CDs to the package dir and runs terraform destroy
    native.genrule(
        name = "%s.destroy" % name,
        outs = ["%s.destroy.sh"],
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
