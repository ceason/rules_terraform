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
        "//experimental:bzl",
        "//experimental/internal:bzl",
        "//experimental/internal/embedding:bzl",
        "//experimental/internal/ghrelease:bzl",
        "//experimental/internal/k8s:bzl",
        "//terraform:bzl",
        "//terraform/internal:bzl",
        # grep -ro --include='*.bzl' '^load("@.*' *|cut -d'"' -f2|sort -u
        "@io_bazel_rules_docker//container:providers.bzl",
        "@bazel_tools//tools/build_defs/hash:hash.bzl",
    ],
)

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
cat $(SRCS) > "$$tmpfile"
cd $$BUILD_WORKSPACE_DIRECTORY
sed "s,{CURRENT_COMMIT},$$(git rev-parse HEAD),g;
     s,{CURRENT_COMMIT_DATE},$$(git show -s --format=%ci HEAD),g
" "$$tmpfile" > README.md
git add README.md
EOF
""",
    executable = True,
)
