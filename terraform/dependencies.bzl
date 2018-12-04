load("//terraform/internal:http_binary.bzl", "http_archive_binary", "http_file_binary")
load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository", "new_git_repository")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

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
    "hub": dict(
        url = "https://github.com/github/hub/releases/download/v{version}/hub-{platform}-amd64-{version}.tgz",
        path = "hub-{platform}-amd64-{version}/bin/hub",
        version = "2.6.0",
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

    _maybe(
        http_archive,
        name = "yaml",
        build_file_content = """
py_library(
    name = "yaml",
    srcs = glob(["*.py"]),
    visibility = ["//visibility:public"],
)""",
        sha256 = "592766c6303207a20efc445587778322d7f73b161bd994f227adaa341ba212ab",
        url = ("https://pypi.python.org/packages/4a/85/db5a2df477072b2902b0eb892feb37d88ac635d36245a72a6a69b23b383a/PyYAML-3.12.tar.gz"),
        strip_prefix = "PyYAML-3.12/lib/yaml",
    )
    _maybe(
        http_archive,
        name = "py_semver",
        build_file_content = """
py_library(
    name = "py_semver",
    srcs = glob(["*.py"]),
    visibility = ["//visibility:public"],
    imports = ["semver"],
)
""",
        sha256 = "5b09010a66d9a3837211bb7ae5a20d10ba88f8cb49e92cb139a69ef90d5060d8",
        url = "https://files.pythonhosted.org/packages/47/13/8ae74584d6dd33a1d640ea27cd656a9f718132e75d759c09377d10d64595/semver-2.8.1.tar.gz",
        strip_prefix = "semver-2.8.1",
    )
    _maybe(
        new_git_repository,
        name = "py_botocore",
        remote = "https://github.com/boto/botocore.git",
        tag = "1.12.57",
        build_file_content = """
py_library(
    name = "py_botocore",
    srcs = glob([ "botocore/**/*.py" ]),
    imports = [ "botocore" ],
    visibility = [ "//visibility:public" ],
    data = glob([ "botocore/data/**" ]),
)
""",
    )
    _maybe(
        new_git_repository,
        name = "py_boto3",
        remote = "https://github.com/boto/boto3.git",
        tag = "1.9.57",
        build_file_content = """
py_library(
    name = "py_boto3",
    srcs = glob([ "boto3/**/*.py" ]),
    imports = [ "boto3" ],
    deps = [ "@py_botocore" ],
    visibility = [ "//visibility:public" ],
    data = glob([ "boto3/data/**" ]),
)
""",
    )


def _maybe(rule, **kwargs):
    if kwargs["name"] not in native.existing_rules():
        rule(**kwargs)
