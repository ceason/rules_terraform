A hello-world service that is designed to run on ECS

# Terraform


## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| custom_server_message | The server will respond to all HTTP requests with this message | string | `Hello, world!` | no |
| fargate_cpu | Fargate instance CPU units to provision (1 vCPU = 1024 CPU units) | string | `256` | no |
| fargate_memory | Fargate instance memory to provision (in MiB) | string | `512` | no |
| replicas | Desired # of ECS replicas | string | `1` | no |
| subnet_ids | List of subnets for the ECS task (eg one subnet per AZ). All subnets must be in the same VPC. | list | - | yes |

## Outputs

| Name | Description |
|------|-------------|
| service_url |  |


# Latest Changes
> For full changelog see [CHANGELOG.md](CHANGELOG.md)
