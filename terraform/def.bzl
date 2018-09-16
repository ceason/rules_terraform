load("//terraform/internal:plugin.bzl", "terraform_plugin")
load("//terraform/internal:module.bzl", "terraform_module")
load("//terraform/internal:workspace.bzl", "terraform_workspace")
load("//terraform/internal:integration_test.bzl", "terraform_integration_test")
load("//terraform/internal:distribution_dir.bzl", terraform_distribution_dir = "terraform_distribution_dir_macro")
load("//terraform/internal:distribution_publisher.bzl", "terraform_distribution_publisher")

#
#
# Targets need to propagate this info..
# - list of "output file generator executables" (eg k8s_object which generates files when run)
# - map of target filename => File (aggregated from `src` and `deps`)
# - list of provider labels
# - map of module Label => name (validate 1:1 relationship between label/name)
#   - ^ these will show up under the root module at `modules/{name}`
#
#
