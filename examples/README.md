

### `src/BUILD`
```python
load("//terraform:def.bzl", "terraform_module")
load("@io_bazel_rules_docker//python:image.bzl", "py_image")
load("@io_bazel_rules_k8s//k8s:object.bzl", "k8s_object")

# First we build a docker image from our app's source
py_image(
    name = "py_image",
    srcs = ["server.py"],
    main = "server.py",
)

# Next, we create a Kubernetes Deployment which references the
# image we just created. Also note:
# - We have specified an 'image_chroot' which allows us to change where the image is published to
# - The actual image_chroot is determined at build time based on the output of './tools/print-workspace-status.sh'
k8s_object(
    name = "deployment",
    image_chroot = "{STABLE_IMAGE_CHROOT}",
    images = {
        "hello-world-server:dev": ":py_image",
    },
    template = "server.yaml",
)

# We combine our terraform files with the Kubernetes Deployment
# to create a terraform module
terraform_module(
    name = "hello-world",
    srcs = glob(["*.tf"]),
    description = "This is an example terraform module, built with bazel!",
    embed = [
        ":deployment",
    ],
    visibility = ["//visibility:public"],
)

```

### `test/BUILD`
```python
load("//terraform:def.bzl", "terraform_integration_test", "terraform_workspace")

# We create a terraform workspace which uses the module we created and
# provides our module with any inputs it requires.
# - Running `bazel run :test-workspace` will run terraform init+apply
# - Running `bazel run :test-workspace.destroy` will tear down the workspace
terraform_workspace(
    name = "test-workspace",
    srcs = ["test_ws.tf"],
    modules = {
        "module": "//examples/src:hello-world",
    },
)

# Now that our workspace is up and running we can create an end-to-end
# test for it and quickly iterate on the test (without having to recreate
# all of the infrastructure) until we're happy with it. This test does require
# infrastructure though, so we tag it as 'manual' to exclude it from wildcard
# target patterns like `bazel test //...`
sh_test(
    name = "e2e_test",
    srcs = ["e2e.sh"],
    tags = [
        "manual",
    ],
)

# ..But we still want an easy-to-run test that doesn't require manually spinning up
# infrastructure, so we create a 'terraform_integration_test' which will
# spin up the specified 'terraform_workspace', run the 'srctest' and then
# clean up with terraform destroy
terraform_integration_test(
    name = "e2e_integration_test",
    timeout = "short",
    flaky = 1,
    srctest = ":e2e_test",
    tags = [
        "manual",
    ],
    terraform_workspace = ":test-workspace",
)


```

### `test/BUILD`
```python
load("//terraform:def.bzl", "terraform_module_publisher")

# To make our terraform module available to others we configure a
# 'terraform_module_publisher' which will
# - Run configured tests
# - Publish relevant docker images (note that we're overriding the image_chroot)
# - Output each module into its own subdirectory in this repo (note that we can optionally output to a different repo)
terraform_module_publisher(
    name = "publish",
    env = {
        "IMAGE_CHROOT": "index.docker.io/netchris",
    },
    prepublish_tests = [
        "//...",
        "//examples/test:e2e_integration_test",
    ],
    published_modules = {
        "mymodule": "//examples/src:hello-world",
    },
    # remote = "git@github.com:my-org-terraform-modules/terraform-myproject-modules.git",
    # remote_path = "modules",
)

---