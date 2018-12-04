workspace(name = "rules_terraform")

load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository", "new_git_repository")

git_repository(
    name = "io_bazel_rules_docker",
    commit = "ff03d2b2800641bdd407bc89823c84b96aa0b15a",
    remote = "https://github.com/ceason/rules_docker.git",
)

load("//terraform:dependencies.bzl", "terraform_repositories")

terraform_repositories()

load("@io_bazel_rules_docker//container:container.bzl", "repositories")

repositories()

load(
    "@io_bazel_rules_docker//python:image.bzl",
    _py_image_repos = "repositories",
)

_py_image_repos()

#git_repository(
#    name = "io_bazel_rules_sass",
#    remote = "https://github.com/bazelbuild/rules_sass.git",
#    tag = "0.0.3",
#)
#
#load("@io_bazel_rules_sass//sass:sass.bzl", "sass_repositories")
#
#sass_repositories()
#
#git_repository(
#    name = "io_bazel_skydoc",
#    commit = "d34c44c3f4102eb94beaf2636c6cf532f0ec1ee8",
#    remote = "https://github.com/bazelbuild/skydoc.git",
#)
#
#load("@io_bazel_skydoc//skylark:skylark.bzl", "skydoc_repositories")
#
#skydoc_repositories()
