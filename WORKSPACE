workspace(name = "rules_terraform")

load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")

# todo: figure out the deps i _actually_ need from this and load just them in 'dependencies.bzl'
# ^- hint: maybe i only need 'containertools' ?
# ..or maybe i don't need anything at all?? because ppl would load docker/k8s anyway?
git_repository(
    name = "io_bazel_rules_docker",
    commit = "7401cb256222615c497c0dee5a4de5724a4f4cc7",
    remote = "git@github.com:bazelbuild/rules_docker.git",
)

git_repository(
    name = "io_bazel_rules_k8s",
    commit = "d6e1b65317246fe044482f9e042556c77e6893b8",
    remote = "git@github.com:bazelbuild/rules_k8s.git",
)

load("@io_bazel_rules_docker//container:container.bzl", "repositories")

repositories()

load("@io_bazel_rules_k8s//k8s:k8s.bzl", "k8s_defaults", "k8s_repositories")

k8s_repositories()

load("//terraform:dependencies.bzl", "terraform_repositories")

terraform_repositories()

k8s_defaults(
    name = "k8s_object",
    image_chroot = "{STABLE_IMAGE_CHROOT}",
)

git_repository(
    name = "io_bazel_rules_sass",
    remote = "https://github.com/bazelbuild/rules_sass.git",
    tag = "0.0.3",
)

load("@io_bazel_rules_sass//sass:sass.bzl", "sass_repositories")

sass_repositories()

git_repository(
    name = "io_bazel_skydoc",
    commit = "d34c44c3f4102eb94beaf2636c6cf532f0ec1ee8",
    remote = "https://github.com/bazelbuild/skydoc.git",
)

load("@io_bazel_skydoc//skylark:skylark.bzl", "skydoc_repositories")

skydoc_repositories()
