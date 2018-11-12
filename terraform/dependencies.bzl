load("//terraform/internal:http_binary.bzl", "http_archive_binary", "http_file_binary")
load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")

_EXTERNAL_BINARIES = {
    "kubectl": dict(
        path = "kubernetes/client/bin/kubectl",
        url = "https://dl.k8s.io/v{version}/kubernetes-client-{platform}-amd64.tar.gz",
        version = "1.11.1",
    ),
    "terraform-docs": dict(
        url = "https://github.com/segmentio/terraform-docs/releases/download/{version}/terraform-docs-{version}-{platform}-amd64",
        version = "v0.5.0",
    ),
    "terraform": dict(
        url = "https://releases.hashicorp.com/terraform/{version}/terraform_{version}_{platform}_amd64.zip",
        path = "terraform",
        version = "0.11.7",
    ),
    "yq": dict(
        url = "https://github.com/mikefarah/yq/releases/download/{version}/yq_{platform}_amd64",
        version = "2.1.1",
    ),
    "stern": dict(
        url = "https://github.com/wercker/stern/releases/download/{version}/stern_{platform}_amd64",
        version = "1.8.0",
    ),
}

def _repository_name(s):
    prefix = "tool_"
    return prefix + s.replace("-", "_")

def terraform_repositories():
    for tool, rule_args in _EXTERNAL_BINARIES.items():
        name = _repository_name(tool)
        if name not in native.existing_rules():
            rule_fn = http_archive_binary if "path" in rule_args else http_file_binary
            rule_fn(name = name, **rule_args)

    if "yaml" not in native.existing_rules():
        native.new_http_archive(
            name = "yaml",
            build_file_content = """
py_library(
    name = "yaml",
    srcs = glob(["*.py"]),
    visibility = ["//visibility:public"],
)""",
            sha256 = "592766c6303207a20efc445587778322d7f73b161bd994f227adaa341ba212ab",
            url = ("https://pypi.python.org/packages/4a/85/" +
                   "db5a2df477072b2902b0eb892feb37d88ac635d36245a72a6a69b23b383a" +
                   "/PyYAML-3.12.tar.gz"),
            strip_prefix = "PyYAML-3.12/lib/yaml",
        )
