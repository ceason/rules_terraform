# dummy target so bazel query works (see https://github.com/bazelbuild/skydoc/issues/62)
filegroup(name = "dummy")

genrule(
    name = "generate-docs",
    srcs = [
        "//terraform/internal:docs-markdown",
        "//terraform/internal:docs-html",
    ],
    outs = ["generate-docs.sh"],
    cmd = """echo '
#!/bin/bash
set -eu

docsfile_md=$$PWD/$(location //terraform/internal:docs-markdown)
docsfile_html=$$PWD/$(location //terraform/internal:docs-html)
cd "$$BUILD_WORKSPACE_DIRECTORY"
rm -rf docs
mkdir -p docs
cd docs
unzip "$$docsfile_md"
unzip "$$docsfile_html"
git add .
' > $@""",
    executable = 1,
)
