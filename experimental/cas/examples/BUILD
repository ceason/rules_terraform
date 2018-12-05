load("@io_bazel_rules_docker//container:container.bzl", "container_push")
load("@io_bazel_rules_docker//python:image.bzl", python_base_image = "DEFAULT_BASE")
load("//experimental:publishing.bzl", "embedded_reference", "file_uploader")

java_binary(
    name = "HelloWorld",
    srcs = ["HelloWorld.java"],
    main_class = "experimental.cas.examples.HelloWorld",
)

file_uploader(
    name = "published_jar",
    src = ":HelloWorld_deploy.jar",
    url_prefix = "s3://$(S3_BUCKET)/asdf/{BUILD_USER}",
)

embedded_reference(
    name = "published_artifacts",
    src = "infile.txt",
    out = "outfile.txt",
    deps = [
        ":published_jar",
        "//examples/src:push_py_image",
    ],
)
