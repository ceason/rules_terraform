load("@io_bazel_skydoc//skylark:skylark.bzl", "skylark_doc")
load("@io_bazel_skydoc//stardoc:stardoc.bzl", "stardoc")
load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

# tldr:
#   grep --include='*.bzl' -r '= rule('|awk -F'[ :]' '{print  "\"" $2 "\":" " \"//" $1 "\"," }'
DOC_SYMBOL_MAP = {
    "terraform_module": "//terraform/internal:module.bzl",
    "terraform_workspace": "//terraform/internal:workspace.bzl",
    "terraform_integration_test": "//terraform/internal:integration_test.bzl",
    "terraform_provider": "//terraform/internal:terraform.bzl",
    "terraform_k8s_manifest": "//experimental/internal/k8s:k8s_manifest.bzl",
    "embedded_reference": "//experimental/internal/embedding:embedder.bzl",
    "file_uploader": "//experimental/internal/embedding:cas_file.bzl",
    "ghrelease_publisher": "//experimental/internal/ghrelease:publisher.bzl",
    "ghrelease_assets": "//experimental/internal/ghrelease:assets.bzl",
    "ghrelease_test_suite": "//experimental/internal/ghrelease:test_suite.bzl",
}

bzl_library(
    name = "bzlfiles",
    srcs = [
        "//experimental:container.bzl",
        "//experimental/internal/embedding:cas_file.bzl",
        "//experimental/internal/embedding:content_publisher.bzl",
        "//experimental/internal/embedding:embedder.bzl",
        "//experimental/internal/ghrelease:assets.bzl",
        "//experimental/internal/ghrelease:publisher.bzl",
        "//experimental/internal/ghrelease:test_suite.bzl",
        "//experimental/internal/k8s:k8s_manifest.bzl",
        "//experimental/internal:providers.bzl",
        "//experimental:k8s.bzl",
        "//experimental:publishing.bzl",
        "//terraform:def.bzl",
        "//terraform:dependencies.bzl",
        "//terraform/internal:http_binary.bzl",
        "//terraform/internal:integration_test.bzl",
        "//terraform/internal:launcher.bzl",
        "//terraform/internal:module.bzl",
        "//terraform/internal:providers.bzl",
        "//terraform/internal:terraform.bzl",
        "//terraform/internal:terraform_lib.bzl",
        "//terraform/internal:workspace.bzl",
        # grep -ro --include='*.bzl' '^load("@.*' *|cut -d'"' -f2|sort -u
        "@io_bazel_rules_docker//container:providers.bzl",
        "@bazel_tools//tools/build_defs/hash:hash.bzl",
    ],
)

[sh_binary(
    name = f[:-len(".sh")],
    srcs = [f],
) for f in glob(["*.sh"])]

[stardoc(
    name = symbol,
    out = symbol + ".md",
    input = file,
    symbol_names = [symbol],
    deps = [":bzlfiles"],
) for symbol, file in DOC_SYMBOL_MAP.items()]

genrule(
    name = "docs",
    srcs = [
        "preamble.md",
    ] + DOC_SYMBOL_MAP.keys(),
    outs = ["docs.sh"],
    cmd = """cat <<'EOF' > $@
#!/usr/bin/env bash
set -euo pipefail
tmpfile=$$(mktemp)
trap "rm -rf '$$tmpfile'" EXIT
cd $$BUILD_WORKSPACE_DIRECTORY
(cd $$(bazel info execution_root) && cat $(SRCS) > "$$tmpfile")
sed "s,{CURRENT_COMMIT},$$(git rev-parse HEAD),g;
     s,{CURRENT_COMMIT_DATE},$$(git show -s --format=%ci HEAD),g
" "$$tmpfile" > README.md
git add README.md
EOF
""",
    executable = True,
)
