load("//terraform/internal:terraform.bzl", _terraform_workspace = "terraform_workspace", "terraform_plugin", "terraform_module")
load("//terraform/internal:test.bzl", "terraform_integration_test")
load("//terraform/internal:distribution.bzl", "terraform_distribution_publisher", _terraform_distribution_dir = "terraform_distribution_dir", "terraform_module_publisher")

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
        cmd = """
            echo '#!/bin/sh
cd $$BUILD_WORKSPACE_DIRECTORY/{package}
exec terraform destroy "$$@" .terraform/tfroot
' > $@
        """.format(package = native.package_name()),
        executable = True,
    )
