
## Getting Started

### `WORKSPACE` file
```python
git_repository(
    name = "rules_terraform",
    commit = "aa6d6bb34be78cb6ad769eb34b03a1cdd885d485",
    remote = "https://github.com/ceason/rules_terraform.git",
)

load("@rules_terraform//terraform:dependencies.bzl", "terraform_repositories")

terraform_repositories()
```

### Usage Examples
- [`//examples`](examples/)
- [`//experimental/examples/cas/BUILD`](experimental/examples/cas/BUILD)