load("//terraform:def.bzl", "terraform_plugin")

PLUGIN_VERSION = "v0.2.0"

[genrule(
    name = platform,
    srcs = ["terraform-provider-kubectl.tpl.sh"],
    outs = ["%s/terraform-provider-kubectl_%s" % (platform, PLUGIN_VERSION)],
    cmd = """cp $< $@""",
    executable = True,
) for platform in [
    "darwin_amd64",
    "linux_amd64",
]]

terraform_plugin(
    name = "kubectl",
    srcs = [
        ":darwin_amd64",
        ":linux_amd64",
    ],
    visibility = ["//visibility:public"],
)
