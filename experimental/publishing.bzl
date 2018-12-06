load("//experimental/internal/ghrelease:publisher.bzl", "ghrelease_publisher")
load("//experimental/internal/ghrelease:assets.bzl", "ghrelease_assets")
load("//experimental/internal/ghrelease:test_suite.bzl", "ghrelease_test_suite")
load("//experimental/internal/embedding:cas_file.bzl", "file_uploader")
load("//experimental/internal/embedding:embedder.bzl", "embedded_reference")


def ghrelease(name, **kwargs):
    label = "%s//%s:%s" % (native.repository_name(), native.package_name(), name)
    print("'ghrelease' is deprecated, please update rule to 'ghrelease_publisher' (%s)" % label)
    ghrelease_publisher(name = name, **kwargs)
