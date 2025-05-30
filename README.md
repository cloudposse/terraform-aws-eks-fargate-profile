

<!-- markdownlint-disable -->
<a href="https://cpco.io/homepage"><img src="https://github.com/cloudposse/terraform-aws-eks-fargate-profile/blob/main/.github/banner.png?raw=true" alt="Project Banner"/></a><br/>
    <p align="right">
<a href="https://github.com/cloudposse/terraform-aws-eks-fargate-profile/releases/latest"><img src="https://img.shields.io/github/release/cloudposse/terraform-aws-eks-fargate-profile.svg?style=for-the-badge" alt="Latest Release"/></a><a href="https://github.com/cloudposse/terraform-aws-eks-fargate-profile/commits"><img src="https://img.shields.io/github/last-commit/cloudposse/terraform-aws-eks-fargate-profile.svg?style=for-the-badge" alt="Last Updated"/></a><a href="https://cloudposse.com/slack"><img src="https://slack.cloudposse.com/for-the-badge.svg" alt="Slack Community"/></a></p>
<!-- markdownlint-restore -->

<!--




  ** DO NOT EDIT THIS FILE
  **
  ** This file was automatically generated by the `cloudposse/build-harness`.
  ** 1) Make all changes to `README.yaml`
  ** 2) Run `make init` (you only need to do this once)
  ** 3) Run`make readme` to rebuild this file.
  **
  ** (We maintain HUNDREDS of open source projects. This is how we maintain our sanity.)
  **





-->

Terraform module to provision an [AWS Fargate Profile](https://docs.aws.amazon.com/eks/latest/userguide/fargate-profile.html) 
and Fargate Pod Execution Role for [EKS](https://aws.amazon.com/eks/).


> [!TIP]
> #### 👽 Use Atmos with Terraform
> Cloud Posse uses [`atmos`](https://atmos.tools) to easily orchestrate multiple environments using Terraform. <br/>
> Works with [Github Actions](https://atmos.tools/integrations/github-actions/), [Atlantis](https://atmos.tools/integrations/atlantis), or [Spacelift](https://atmos.tools/integrations/spacelift).
>
> <details>
> <summary><strong>Watch demo of using Atmos with Terraform</strong></summary>
> <img src="https://github.com/cloudposse/atmos/blob/main/docs/demo.gif?raw=true"/><br/>
> <i>Example of running <a href="https://atmos.tools"><code>atmos</code></a> to manage infrastructure from our <a href="https://atmos.tools/quick-start/">Quick Start</a> tutorial.</i>
> </detalis>


## Introduction

By default, this module will provision an [AWS Fargate Profile](https://docs.aws.amazon.com/eks/latest/userguide/fargate-profile.html) 
and Fargate Pod Execution Role for [EKS](https://aws.amazon.com/eks/). 

Note that in general, you only need one Fargate Pod Execution Role per AWS account, 
and it can be shared across regions. So if you are creating multiple Faragte Profiles, 
you can reuse the role created by the first one, or instantiate this module with 
`fargate_profile_enabled = false` to create the role separate from the profile. 




## Usage


For a complete example, see [examples/complete](examples/complete).

For automated tests of the complete example using [bats](https://github.com/bats-core/bats-core) and [Terratest](https://github.com/gruntwork-io/terratest)
(which tests and deploys the example on AWS), see [test](test).

```hcl
  module "label" {
    source  = "cloudposse/label/null"
    version = "0.25.0"
  
    # This is the preferred way to add attributes. It will put "cluster" last
    # after any attributes set in `var.attributes` or `context.attributes`.
    # In this case, we do not care, because we are only using this instance
    # of this module to create tags.
    attributes = ["cluster"]
  
    context = module.this.context
  }
  
  locals {
    tags = try(merge(module.label.tags, tomap("kubernetes.io/cluster/${module.label.id}", "shared")), null)
    
    eks_worker_ami_name_filter = "amazon-eks-node-${var.kubernetes_version}*"
  
    allow_all_ingress_rule = {
      key              = "allow_all_ingress"
      type             = "ingress"
      from_port        = 0
      to_port          = 0 # [sic] from and to port ignored when protocol is "-1", warning if not zero
      protocol         = "-1"
      description      = "Allow all ingress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  
    allow_http_ingress_rule = {
      key              = "http"
      type             = "ingress"
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      description      = "Allow HTTP ingress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  
    extra_policy_arn = "arn:aws:iam::aws:policy/job-function/ViewOnlyAccess"
  }
  
  module "vpc" {
    source  = "cloudposse/vpc/aws"
    version = "1.1.0"
  
    cidr_block = var.vpc_cidr_block
    tags       = local.tags
  
    context = module.this.context
  }
  
  module "subnets" {
    source  = "cloudposse/dynamic-subnets/aws"
    version = "1.0.0"
  
    availability_zones   = var.availability_zones
    vpc_id               = module.vpc.vpc_id
    igw_id               = module.vpc.igw_id
    cidr_block           = module.vpc.vpc_cidr_block
    nat_gateway_enabled  = true
    nat_instance_enabled = false
    tags                 = local.tags
  
    context = module.this.context
  }
  
  module "ssh_source_access" {
    source  = "cloudposse/security-group/aws"
    version = "1.0.1"
  
    attributes                 = ["ssh", "source"]
    security_group_description = "Test source security group ssh access only"
    create_before_destroy      = true
    allow_all_egress           = true
  
    rules = [local.allow_all_ingress_rule]
  
    vpc_id = module.vpc.vpc_id
  
    context = module.label.context
  }
  
  module "https_sg" {
    source  = "cloudposse/security-group/aws"
    version = "1.0.1"
  
    attributes                 = ["http"]
    security_group_description = "Allow http access"
    create_before_destroy      = true
    allow_all_egress           = true
  
    rules = [local.allow_http_ingress_rule]
  
    vpc_id = module.vpc.vpc_id
  
    context = module.label.context
  }
  
  module "eks_cluster" {
    source  = "cloudposse/eks-cluster/aws"
    version = "2.2.0"
  
    region                       = var.region
    vpc_id                       = module.vpc.vpc_id
    subnet_ids                   = module.subnets.public_subnet_ids
    kubernetes_version           = var.kubernetes_version
    local_exec_interpreter       = var.local_exec_interpreter
    oidc_provider_enabled        = var.oidc_provider_enabled
    enabled_cluster_log_types    = var.enabled_cluster_log_types
    cluster_log_retention_period = var.cluster_log_retention_period
  
    # data auth has problems destroying the auth-map
    kube_data_auth_enabled = false
    kube_exec_auth_enabled = true
  
    context = module.this.context
  }
  
  module "eks_node_group" {
    source  = "cloudposse/eks-node-group/aws"
    version = "2.4.0"
  
    subnet_ids                    = module.subnets.public_subnet_ids
    cluster_name                  = module.eks_cluster.eks_cluster_id
    instance_types                = var.instance_types
    desired_size                  = var.desired_size
    min_size                      = var.min_size
    max_size                      = var.max_size
    kubernetes_version            = [var.kubernetes_version]
    kubernetes_labels             = merge(var.kubernetes_labels, { attributes = coalesce(join(module.this.delimiter, module.this.attributes), "none") })
    kubernetes_taints             = var.kubernetes_taints
    ec2_ssh_key_name              = var.ec2_ssh_key_name
    ssh_access_security_group_ids = [module.ssh_source_access.id]
    associated_security_group_ids = [module.ssh_source_access.id, module.https_sg.id]
    node_role_policy_arns         = [local.extra_policy_arn]
    update_config                 = var.update_config
  
    after_cluster_joining_userdata = var.after_cluster_joining_userdata
  
    ami_type            = var.ami_type
    ami_release_version = var.ami_release_version
  
    before_cluster_joining_userdata = [var.before_cluster_joining_userdata]
  
    context = module.this.context
  
    # Ensure ordering of resource creation to eliminate the race conditions when applying the Kubernetes Auth ConfigMap.
    # Do not create Node Group before the EKS cluster is created and the `aws-auth` Kubernetes ConfigMap is applied.
    depends_on = [module.eks_cluster, module.eks_cluster.kubernetes_config_map_id]
  
    create_before_destroy = true
  
    node_group_terraform_timeouts = [{
      create = "40m"
      update = null
      delete = "20m"
    }]
  }
  
  module "eks_fargate_profile" {
    source  = "cloudposse/eks-fargate-profile/aws"
    version = "x.x.x"
  
    subnet_ids                              = module.subnets.public_subnet_ids
    cluster_name                            = module.eks_cluster.eks_cluster_id
    kubernetes_namespace                    = var.kubernetes_namespace
    kubernetes_labels                       = var.kubernetes_labels
    iam_role_kubernetes_namespace_delimiter = var.iam_role_kubernetes_namespace_delimiter
  
    context = module.this.context
  }

```

> [!IMPORTANT]
> In Cloud Posse's examples, we avoid pinning modules to specific versions to prevent discrepancies between the documentation
> and the latest released versions. However, for your own projects, we strongly advise pinning each module to the exact version
> you're using. This practice ensures the stability of your infrastructure. Additionally, we recommend implementing a systematic
> approach for updating versions to avoid unexpected changes.














## Related Projects

Check out these related projects.

- [terraform-aws-eks-cluster](https://github.com/cloudposse/terraform-aws-eks-cluster) - Terraform module to provision an EKS cluster on AWS
- [terraform-aws-eks-node-group](https://github.com/cloudposse/terraform-aws-eks-node-group) - Terraform module to provision an EKS Node Group
- [terraform-aws-eks-workers](https://github.com/cloudposse/terraform-aws-eks-workers) - Terraform module to provision an AWS AutoScaling Group, IAM Role, and Security Group for EKS Workers
- [terraform-aws-ec2-autoscale-group](https://github.com/cloudposse/terraform-aws-ec2-autoscale-group) - Terraform module to provision Auto Scaling Group and Launch Template on AWS
- [terraform-aws-ecs-container-definition](https://github.com/cloudposse/terraform-aws-ecs-container-definition) - Terraform module to generate well-formed JSON documents (container definitions) that are passed to the  aws_ecs_task_definition Terraform resource
- [terraform-aws-ecs-alb-service-task](https://github.com/cloudposse/terraform-aws-ecs-alb-service-task) - Terraform module which implements an ECS service which exposes a web service via ALB
- [terraform-aws-ecs-web-app](https://github.com/cloudposse/terraform-aws-ecs-web-app) - Terraform module that implements a web app on ECS and supports autoscaling, CI/CD, monitoring, ALB integration, and much more
- [terraform-aws-ecs-codepipeline](https://github.com/cloudposse/terraform-aws-ecs-codepipeline) - Terraform module for CI/CD with AWS Code Pipeline and Code Build for ECS
- [terraform-aws-ecs-cloudwatch-autoscaling](https://github.com/cloudposse/terraform-aws-ecs-cloudwatch-autoscaling) - Terraform module to autoscale ECS Service based on CloudWatch metrics
- [terraform-aws-ecs-cloudwatch-sns-alarms](https://github.com/cloudposse/terraform-aws-ecs-cloudwatch-sns-alarms) - Terraform module to create CloudWatch Alarms on ECS Service level metrics
- [terraform-aws-ec2-instance](https://github.com/cloudposse/terraform-aws-ec2-instance) - Terraform module for providing a general purpose EC2 instance
- [terraform-aws-ec2-instance-group](https://github.com/cloudposse/terraform-aws-ec2-instance-group) - Terraform module for provisioning multiple general purpose EC2 hosts for stateful applications


> [!TIP]
> #### Use Terraform Reference Architectures for AWS
>
> Use Cloud Posse's ready-to-go [terraform architecture blueprints](https://cloudposse.com/reference-architecture/) for AWS to get up and running quickly.
>
> ✅ We build it together with your team.<br/>
> ✅ Your team owns everything.<br/>
> ✅ 100% Open Source and backed by fanatical support.<br/>
>
> <a href="https://cpco.io/commercial-support?utm_source=github&utm_medium=readme&utm_campaign=cloudposse/terraform-aws-eks-fargate-profile&utm_content=commercial_support"><img alt="Request Quote" src="https://img.shields.io/badge/request%20quote-success.svg?style=for-the-badge"/></a>
> <details><summary>📚 <strong>Learn More</strong></summary>
>
> <br/>
>
> Cloud Posse is the leading [**DevOps Accelerator**](https://cpco.io/commercial-support?utm_source=github&utm_medium=readme&utm_campaign=cloudposse/terraform-aws-eks-fargate-profile&utm_content=commercial_support) for funded startups and enterprises.
>
> *Your team can operate like a pro today.*
>
> Ensure that your team succeeds by using Cloud Posse's proven process and turnkey blueprints. Plus, we stick around until you succeed.
> #### Day-0:  Your Foundation for Success
> - **Reference Architecture.** You'll get everything you need from the ground up built using 100% infrastructure as code.
> - **Deployment Strategy.** Adopt a proven deployment strategy with GitHub Actions, enabling automated, repeatable, and reliable software releases.
> - **Site Reliability Engineering.** Gain total visibility into your applications and services with Datadog, ensuring high availability and performance.
> - **Security Baseline.** Establish a secure environment from the start, with built-in governance, accountability, and comprehensive audit logs, safeguarding your operations.
> - **GitOps.** Empower your team to manage infrastructure changes confidently and efficiently through Pull Requests, leveraging the full power of GitHub Actions.
>
> <a href="https://cpco.io/commercial-support?utm_source=github&utm_medium=readme&utm_campaign=cloudposse/terraform-aws-eks-fargate-profile&utm_content=commercial_support"><img alt="Request Quote" src="https://img.shields.io/badge/request%20quote-success.svg?style=for-the-badge"/></a>
>
> #### Day-2: Your Operational Mastery
> - **Training.** Equip your team with the knowledge and skills to confidently manage the infrastructure, ensuring long-term success and self-sufficiency.
> - **Support.** Benefit from a seamless communication over Slack with our experts, ensuring you have the support you need, whenever you need it.
> - **Troubleshooting.** Access expert assistance to quickly resolve any operational challenges, minimizing downtime and maintaining business continuity.
> - **Code Reviews.** Enhance your team’s code quality with our expert feedback, fostering continuous improvement and collaboration.
> - **Bug Fixes.** Rely on our team to troubleshoot and resolve any issues, ensuring your systems run smoothly.
> - **Migration Assistance.** Accelerate your migration process with our dedicated support, minimizing disruption and speeding up time-to-value.
> - **Customer Workshops.** Engage with our team in weekly workshops, gaining insights and strategies to continuously improve and innovate.
>
> <a href="https://cpco.io/commercial-support?utm_source=github&utm_medium=readme&utm_campaign=cloudposse/terraform-aws-eks-fargate-profile&utm_content=commercial_support"><img alt="Request Quote" src="https://img.shields.io/badge/request%20quote-success.svg?style=for-the-badge"/></a>
> </details>

## ✨ Contributing

This project is under active development, and we encourage contributions from our community.



Many thanks to our outstanding contributors:

<a href="https://github.com/cloudposse/terraform-aws-eks-fargate-profile/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=cloudposse/terraform-aws-eks-fargate-profile&max=24" />
</a>

For 🐛 bug reports & feature requests, please use the [issue tracker](https://github.com/cloudposse/terraform-aws-eks-fargate-profile/issues).

In general, PRs are welcome. We follow the typical "fork-and-pull" Git workflow.
 1. Review our [Code of Conduct](https://github.com/cloudposse/terraform-aws-eks-fargate-profile/?tab=coc-ov-file#code-of-conduct) and [Contributor Guidelines](https://github.com/cloudposse/.github/blob/main/CONTRIBUTING.md).
 2. **Fork** the repo on GitHub
 3. **Clone** the project to your own machine
 4. **Commit** changes to your own branch
 5. **Push** your work back up to your fork
 6. Submit a **Pull Request** so that we can review your changes

**NOTE:** Be sure to merge the latest changes from "upstream" before making a pull request!

### 🌎 Slack Community

Join our [Open Source Community](https://cpco.io/slack?utm_source=github&utm_medium=readme&utm_campaign=cloudposse/terraform-aws-eks-fargate-profile&utm_content=slack) on Slack. It's **FREE** for everyone! Our "SweetOps" community is where you get to talk with others who share a similar vision for how to rollout and manage infrastructure. This is the best place to talk shop, ask questions, solicit feedback, and work together as a community to build totally *sweet* infrastructure.

### 📰 Newsletter

Sign up for [our newsletter](https://cpco.io/newsletter?utm_source=github&utm_medium=readme&utm_campaign=cloudposse/terraform-aws-eks-fargate-profile&utm_content=newsletter) and join 3,000+ DevOps engineers, CTOs, and founders who get insider access to the latest DevOps trends, so you can always stay in the know.
Dropped straight into your Inbox every week — and usually a 5-minute read.

### 📆 Office Hours <a href="https://cloudposse.com/office-hours?utm_source=github&utm_medium=readme&utm_campaign=cloudposse/terraform-aws-eks-fargate-profile&utm_content=office_hours"><img src="https://img.cloudposse.com/fit-in/200x200/https://cloudposse.com/wp-content/uploads/2019/08/Powered-by-Zoom.png" align="right" /></a>

[Join us every Wednesday via Zoom](https://cloudposse.com/office-hours?utm_source=github&utm_medium=readme&utm_campaign=cloudposse/terraform-aws-eks-fargate-profile&utm_content=office_hours) for your weekly dose of insider DevOps trends, AWS news and Terraform insights, all sourced from our SweetOps community, plus a _live Q&A_ that you can’t find anywhere else.
It's **FREE** for everyone!
## License

<a href="https://opensource.org/licenses/Apache-2.0"><img src="https://img.shields.io/badge/License-Apache%202.0-blue.svg?style=for-the-badge" alt="License"></a>

<details>
<summary>Preamble to the Apache License, Version 2.0</summary>
<br/>
<br/>

Complete license is available in the [`LICENSE`](LICENSE) file.

```text
Licensed to the Apache Software Foundation (ASF) under one
or more contributor license agreements.  See the NOTICE file
distributed with this work for additional information
regarding copyright ownership.  The ASF licenses this file
to you under the Apache License, Version 2.0 (the
"License"); you may not use this file except in compliance
with the License.  You may obtain a copy of the License at

  https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing,
software distributed under the License is distributed on an
"AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
KIND, either express or implied.  See the License for the
specific language governing permissions and limitations
under the License.
```
</details>

## Trademarks

All other trademarks referenced herein are the property of their respective owners.


---
Copyright © 2017-2025 [Cloud Posse, LLC](https://cpco.io/copyright)


<a href="https://cloudposse.com/readme/footer/link?utm_source=github&utm_medium=readme&utm_campaign=cloudposse/terraform-aws-eks-fargate-profile&utm_content=readme_footer_link"><img alt="README footer" src="https://cloudposse.com/readme/footer/img"/></a>

<img alt="Beacon" width="0" src="https://ga-beacon.cloudposse.com/UA-76589703-4/cloudposse/terraform-aws-eks-fargate-profile?pixel&cs=github&cm=readme&an=terraform-aws-eks-fargate-profile"/>
