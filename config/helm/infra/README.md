# Infrastructure

This directory contains the Terraform and Helm configurations used to deploy the
BetterBooks platform.

## Terraform

Terraform provisions the AWS resources such as the EKS Kubernetes cluster and
RDS database. Example usage:

```bash
cd terraform
terraform init
terraform apply
```

Set the necessary variables (e.g. `aws_region`, `subnet_ids`, credentials) via
a `terraform.tfvars` file or environment variables before applying.

## Helm

Once the cluster is available, each service can be deployed using its Helm
chart. From the `helm` directory run:

```bash
helm upgrade --install api-gateway ./api_gateway
helm upgrade --install context-service ./context_service
helm upgrade --install llm-gateway ./llm_gateway
helm upgrade --install tts-service ./tts_service
```

Customise the image tags or other values with `--set` or a custom values file.
