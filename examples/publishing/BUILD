load("@io_bazel_rules_docker//container:container.bzl", "container_push")
load("@io_bazel_rules_docker//python:image.bzl", python_base_image = "DEFAULT_BASE")
load("//experimental:publishing.bzl", "file_uploader", "embedded_reference")
#
#py_image(
#    name = "py_image",
#    srcs = ["server.py"],
#    main = "server.py",
#)

container_push(
    name = "push_image",
    format = "Docker",
    image = python_base_image,
    registry = "index.docker.io",
    repository = "netchris/py-base-image",
    stamp = True,
    tag = "dev",
)

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
        ":push_image",
    ],
)
