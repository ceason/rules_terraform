
# Getting Started

### `WORKSPACE` file
```python
git_repository(
    name = "rules_terraform",
    commit = "{CURRENT_COMMIT}", # {CURRENT_COMMIT_DATE}
    remote = "https://github.com/ceason/rules_terraform.git",
)

load("@rules_terraform//terraform:dependencies.bzl", "terraform_repositories")

terraform_repositories()
```

### Usage Examples
- [`//examples`](examples/)
- [`//examples/publishing/BUILD`](examples/publishing/BUILD) (experimental)

# Rules

- [terraform_module](#terraform_module)
- [terraform_workspace](#terraform_workspace)
- [terraform_integration_test](#terraform_integration_test)
- [terraform_provider](#terraform_provider)

### Experimental

- [terraform_k8s_manifest](#terraform_k8s_manifest)
- [embedded_reference](#embedded_reference)
- [file_uploader](#file_uploader)
- [ghrelease_publisher](#ghrelease_publisher)
- [ghrelease_assets](#ghrelease_assets)
- [ghrelease_test_suite](#ghrelease_test_suite)

