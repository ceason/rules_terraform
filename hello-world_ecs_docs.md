## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| subnet\_ids | List of subnets for the ECS task (eg one subnet per AZ). All subnets must be in the same VPC. | list | n/a | yes |
| custom\_server\_message | The server will respond to all HTTP requests with this message | string | `"Hello, world!"` | no |
| fargate\_cpu | Fargate instance CPU units to provision (1 vCPU = 1024 CPU units) | string | `"256"` | no |
| fargate\_memory | Fargate instance memory to provision (in MiB) | string | `"512"` | no |
| replicas | Desired # of ECS replicas | string | `"1"` | no |

## Outputs

| Name | Description |
|------|-------------|
| service\_url |  |

