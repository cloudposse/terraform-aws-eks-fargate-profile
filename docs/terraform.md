<!-- markdownlint-disable -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 0.12.0, < 0.14.0 |
| aws | ~> 2.0 |
| local | ~> 1.3 |
| template | ~> 2.0 |

## Providers

| Name | Version |
|------|---------|
| aws | ~> 2.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| attributes | Additional attributes (e.g. `1`) | `list(string)` | `[]` | no |
| cluster\_name | The name of the EKS cluster | `string` | n/a | yes |
| delimiter | Delimiter to be used between `namespace`, `stage`, `name` and `attributes` | `string` | `"-"` | no |
| enabled | Whether to create the resources. Set to `false` to prevent the module from creating any resources | `bool` | `true` | no |
| environment | Environment, e.g. 'prod', 'staging', 'dev', 'pre-prod', 'UAT' | `string` | `""` | no |
| kubernetes\_labels | Key-value mapping of Kubernetes labels for selection | `map(string)` | `{}` | no |
| kubernetes\_namespace | Kubernetes namespace for selection | `string` | n/a | yes |
| name | Solution name, e.g. 'app' or 'cluster' | `string` | n/a | yes |
| namespace | Namespace, which could be your organization name, e.g. 'eg' or 'cp' | `string` | `""` | no |
| stage | Stage, e.g. 'prod', 'staging', 'dev', or 'test' | `string` | `""` | no |
| subnet\_ids | Identifiers of private EC2 Subnets to associate with the EKS Fargate Profile. These subnets must have the following resource tag: kubernetes.io/cluster/CLUSTER\_NAME (where CLUSTER\_NAME is replaced with the name of the EKS Cluster) | `list(string)` | n/a | yes |
| tags | Additional tags (e.g. `{ BusinessUnit = "XYZ" }` | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| eks\_fargate\_profile\_arn | Amazon Resource Name (ARN) of the EKS Fargate Profile |
| eks\_fargate\_profile\_id | EKS Cluster name and EKS Fargate Profile name separated by a colon |
| eks\_fargate\_profile\_role\_arn | ARN of the EKS Fargate Profile IAM role |
| eks\_fargate\_profile\_role\_name | Name of the EKS Fargate Profile IAM role |
| eks\_fargate\_profile\_status | Status of the EKS Fargate Profile |

<!-- markdownlint-restore -->
