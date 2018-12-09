load("//terraform/internal:http_binary.bzl", "http_archive_binary", "http_file_binary")
load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository", "new_git_repository")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

_EXTERNAL_BINARIES = {
    "terraform-provider-kubectl": dict(
        url = "https://github.com/ceason/terraform-provider-kubectl/releases/download/v{version}/terraform-provider-kubectl-{platform}-amd64",
        version = "0.3.1",
    ),
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
        version = "0.11.10",
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

def _pip_package(name, urls = None, sha256 = None, path = None, deps = []):
    """
    """
    srcs = """glob(["**/*.py", "*.py"])"""
    data = """glob(["**"], exclude=["**/*.py"])"""
    if not name.startswith("py_"):
        fail("'pip_package' must start with 'py_' (got '%s')" % name, attr = "name")
    if not urls[0].endswith(".tar.gz"):
        fail("Expected URL ending in '.tar.gz'", attr = "urls")
    basename = urls[0].split("/")[-1]
    strip_prefix = basename[:-len(".tar.gz")]
    if path:
        strip_prefix += "/%s" % path
    build_file_content = """
py_library(
    name = "{name}",
    srcs = {srcs},
    data = {data},
    visibility = [ "//visibility:public" ],
    deps = {deps},
)
""".format(
        name = name,
        srcs = srcs,
        data = data,
        deps = "[%s]" % ", ".join([
            '"%s"' % dep
            for dep in sorted(deps)
        ]),
    )
    http_archive(
        name = name,
        urls = urls,
        sha256 = sha256,
        strip_prefix = strip_prefix,
        build_file_content = build_file_content,
    )

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
        _pip_package,
        name = "py_yaml",
        sha256 = "592766c6303207a20efc445587778322d7f73b161bd994f227adaa341ba212ab",
        urls = ["https://pypi.python.org/packages/4a/85/db5a2df477072b2902b0eb892feb37d88ac635d36245a72a6a69b23b383a/PyYAML-3.12.tar.gz"],
        path = "lib",
    )
    _maybe(
        _pip_package,
        name = "py_semver",
        sha256 = "5b09010a66d9a3837211bb7ae5a20d10ba88f8cb49e92cb139a69ef90d5060d8",
        urls = ["https://files.pythonhosted.org/packages/47/13/8ae74584d6dd33a1d640ea27cd656a9f718132e75d759c09377d10d64595/semver-2.8.1.tar.gz"],
    )
    _maybe(
        _pip_package,
        name = "py_certifi",
        sha256 = "47f9c83ef4c0c621eaef743f133f09fa8a74a9b75f037e8624f83bd1b6626cb7",
        urls = ["https://files.pythonhosted.org/packages/55/54/3ce77783acba5979ce16674fc98b1920d00b01d337cfaaf5db22543505ed/certifi-2018.11.29.tar.gz"],
    )
    _maybe(
        _pip_package,
        name = "py_boto3",
        urls = ["https://files.pythonhosted.org/packages/fe/ea/3f0dedaf1b733908a171c2aa24d322ad18c1aee171afff88a7b9e843d845/boto3-1.9.60.tar.gz"],
        sha256 = "6e9f48f3cd16f4b4e1e2d9c49c0644568294f67cda1a93f84315526cbd7e70ae",
        deps = ["@py_botocore"],
    )
    _maybe(
        _pip_package,
        name = "py_botocore",
        sha256 = "e298eaa3883d5aa62a21e84b68a3b4d47b582fffdb93efefe53144d2ed9a824c",
        urls = ["https://files.pythonhosted.org/packages/ec/52/992d721d2dab6e0b6ce1a92b892ca75d48e4200de7adc7af0eb65a3141ae/botocore-1.12.60.tar.gz"],
        deps = [
            "@py_dateutil",
            "@py_jmespath",
            "@py_s3transfer",
            "@py_urllib3",
            "@py_certifi",
        ],
    )
    _maybe(
        _pip_package,
        name = "py_dateutil",
        sha256 = "88f9287c0174266bb0d8cedd395cfba9c58e87e5ad86b2ce58859bc11be3cf02",
        urls = ["https://files.pythonhosted.org/packages/0e/01/68747933e8d12263d41ce08119620d9a7e5eb72c876a3442257f74490da0/python-dateutil-2.7.5.tar.gz"],
        deps = ["@py_six"],
    )
    _maybe(
        _pip_package,
        name = "py_jmespath",
        sha256 = "6a81d4c9aa62caf061cb517b4d9ad1dd300374cd4706997aff9cd6aedd61fc64",
        urls = ["https://files.pythonhosted.org/packages/e5/21/795b7549397735e911b032f255cff5fb0de58f96da794274660bca4f58ef/jmespath-0.9.3.tar.gz"],
    )
    _maybe(
        _pip_package,
        name = "py_s3transfer",
        sha256 = "90dc18e028989c609146e241ea153250be451e05ecc0c2832565231dacdf59c1",
        urls = ["https://files.pythonhosted.org/packages/9a/66/c6a5ae4dbbaf253bd662921b805e4972451a6d214d0dc9fb3300cb642320/s3transfer-0.1.13.tar.gz"],
        deps = ["@py_futures"],
    )
    _maybe(
        _pip_package,
        name = "py_urllib3",
        sha256 = "de9529817c93f27c8ccbfead6985011db27bd0ddfcdb2d86f3f663385c6a9c22",
        urls = ["https://files.pythonhosted.org/packages/b1/53/37d82ab391393565f2f831b8eedbffd57db5a718216f82f1a8b4d381a1c1/urllib3-1.24.1.tar.gz"],
        path = "src",
    )
    _maybe(
        _pip_package,
        name = "py_six",
        sha256 = "70e8a77beed4562e7f14fe23a786b54f6296e34344c23bc42f07b15018ff98e9",
        urls = ["https://files.pythonhosted.org/packages/16/d8/bc6316cf98419719bd59c91742194c111b6f2e85abac88e496adefaf7afe/six-1.11.0.tar.gz"],
    )
    _maybe(
        _pip_package,
        name = "py_futures",
        sha256 = "9ec02aa7d674acb8618afb127e27fde7fc68994c0437ad759fa094a574adb265",
        urls = ["https://files.pythonhosted.org/packages/1f/9e/7b2ff7e965fc654592269f2906ade1c7d705f1bf25b7d469fa153f7d19eb/futures-3.2.0.tar.gz"],
    )
    _maybe(
        git_repository,
        name = "io_bazel_rules_docker",
        commit = "5eb0728594013d746959c4bd21aa4b0c3e3848d8",
        remote = "https://github.com/bazelbuild/rules_docker.git",
    )

def _maybe(rule, **kwargs):
    if kwargs["name"] not in native.existing_rules():
        rule(**kwargs)
