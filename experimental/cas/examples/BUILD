load("@io_bazel_rules_docker//container:container.bzl", "container_push")
load("@io_bazel_rules_docker//python:image.bzl", python_base_image = "DEFAULT_BASE")
load("//experimental:cas.bzl", "content_addressable_file", "embedded_reference")
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

content_addressable_file(
    name = "big_file_url",
    srcs = ["some-really-big-file"],
    url_prefix = "s3://whatever-bucket-name/",
)

embedded_reference(
    name = "published_artifacts",
    srcs = ["infile.txt"],  # must be single file
    outs = ["outfile.txt"],  # must be single file
    deps = [
        # can be ':<target>' syntax if this target in same package as infile,
        # or '//<package>:<target>' if this tgt in same repo as infile,
        # but must be '@<repo>//<package>:<target>' otherwise
        ":big_file_url",
        ":push_image",
        # gives a compile error if not all replacements found
    ],
)

#cas_embedder(
#    name = "artifacts.manifest",
#    src = "infile.txt",
#    out = "outfile.txt",
#    replacements = {
#        "%{my-cool-image}": ":my_cool_image",
#        "%{big-jar}": ":big_library_url",
#    },
#)
#
#cas_embedder(
#    name = "artifacts.manifest",
#    srcs = ["infile.txt"],  # must be single file
#    outs = ["outfile.txt"],  # must be single file
#    deps = {
#        "%{my-cool-image}": ":my_cool_image",
#        "%{big-jar}": ":big_library_url",
#    },
#)
#
#cas_embedder(
#    name = "artifacts.manifest",
#    srcs = ["infile.txt"],  # must be single file
#    outs = ["outfile.txt"],  # must be single file
#    deps = {
#        ":my_cool_image": "%{my-cool-image}",
#        ":big_library_url": "%{big-jar}",
#    },
#)

#
#
#cas_embedder(
#    name = "artifacts.manifest",
#    output = "outfile.txt",
#    substitutions = {
#        "%{my-cool-image}": ":my_cool_image",
#        "%{big-jar}": ":big_library_url",
#    },
#    template = "infile.txt",
#)
