## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| attributes | Additional attributes (e.g. `1`) | list(string) | `<list>` | no |
| cluster_name | The name of the EKS cluster | string | - | yes |
| delimiter | Delimiter to be used between `namespace`, `stage`, `name` and `attributes` | string | `-` | no |
| enabled | Whether to create the resources. Set to `false` to prevent the module from creating any resources | bool | `true` | no |
| kubernetes_labels | Key-value mapping of Kubernetes labels for selection | map(string) | `<map>` | no |
| kubernetes_namespace | Kubernetes namespace for selection | string | - | yes |
| name | Solution name, e.g. 'app' or 'cluster' | string | - | yes |
| namespace | Namespace, which could be your organization name, e.g. 'eg' or 'cp' | string | `` | no |
| stage | Stage, e.g. 'prod', 'staging', 'dev', or 'test' | string | `` | no |
| subnet_ids | Identifiers of private EC2 Subnets to associate with the EKS Fargate Profile. These subnets must have the following resource tag: kubernetes.io/cluster/CLUSTER_NAME (where CLUSTER_NAME is replaced with the name of the EKS Cluster) | list(string) | - | yes |
| tags | Additional tags (e.g. `{ BusinessUnit = "XYZ" }` | map(string) | `<map>` | no |

## Outputs

| Name | Description |
|------|-------------|
| eks_fargate_profile_arn | Amazon Resource Name (ARN) of the EKS Fargate Profile |
| eks_fargate_profile_id | EKS Cluster name and EKS Fargate Profile name separated by a colon |
| eks_fargate_profile_role_arn | ARN of the EKS Fargate Profile IAM role |
| eks_fargate_profile_role_name | Name of the EKS Fargate Profile IAM role |
| eks_fargate_profile_status | Status of the EKS Fargate Profile |

