#load("@io_bazel_skydoc//skylark:skylark.bzl", "skylark_doc")
#
## dummy target so bazel query works (see https://github.com/bazelbuild/skydoc/issues/62)
#filegroup(name = "dummy")
#
#DOC_SRCS = [
#    "//terraform/internal:distribution.bzl",
#    "//terraform/internal:test.bzl",
#    "//terraform/internal:terraform.bzl",
#]
#
#skylark_doc(
#    name = "docs-html",
#    srcs = DOC_SRCS,
#    format = "html",
#    strip_prefix = "terraform/internal",
#    site_root = "/rules_terraform",
#)
#
#genrule(
#    name = "generate-docs",
#    srcs = [
#        ":docs-html",
#    ],
#    outs = ["generate-docs.sh"],
#    cmd = """echo '
##!/bin/bash
#set -eu
#
#
#docsfile_html=$$PWD/$(location :docs-html)
#cd "$$BUILD_WORKSPACE_DIRECTORY"
#rm -rf docs
#mkdir -p docs
#cd docs
#unzip "$$docsfile_html"
#git add .
#' > $@""",
#    executable = 1,
#)
