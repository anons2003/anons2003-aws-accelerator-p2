# Final Project: Deploy a Web App on AWS

This Terraform project builds the architecture from the final project slide:

- VPC with public and private subnets.
- EC2 web server in a public subnet.
- RDS MySQL database in private subnets.
- Private S3 bucket for static assets.
- Security groups that allow only required traffic.
- S3 backend with DynamoDB locking for Terraform state.

## Layout

```text
terraform/
  bootstrap-state/   # Creates the S3 backend bucket and DynamoDB lock table.
  modules/vpc/       # Reusable VPC module.
  templates/         # EC2 user data and generated static page.
```

## 1. Create Remote State Resources

Run this once with local state:

```bash
cd terraform/bootstrap-state
terraform init
terraform apply
terraform output backend_config
```

Copy the output values into `terraform/backend.hcl`. The file should match `backend.hcl.example`.

## 2. Deploy the Web App Stack

```bash
cd ..
cp terraform.tfvars.example terraform.tfvars
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

After apply completes, open the `web_url` output in a browser.

## Security Notes

- RDS is not publicly accessible and only accepts MySQL traffic from the EC2 security group.
- The S3 assets bucket blocks public access, enables server-side encryption, and keeps object versioning on.
- The EC2 instance can read only the project assets bucket through its instance profile.
- SSH is disabled by default. Set `ssh_cidr_blocks` to your public IP CIDR only if you need debugging access.
- The generated database password is sensitive, but it is still stored in Terraform state. Protect backend access carefully.

## Default Cost Estimate

For the default `us-east-1` dev settings, current AWS On-Demand pricing is approximately:

- EC2 `t3.micro` Linux: `$0.0104/hour`, about `$7.59/month` at 730 hours.
- RDS MySQL `db.t3.micro` Single-AZ: `$0.017/hour`, about `$12.41/month` at 730 hours.
- S3 Standard storage: `$0.023/GB-month` for the first 50 TB.
- RDS and EBS storage, backup storage, data transfer, requests, taxes, and any non-default changes are extra.

Expect the default always-on stack to be roughly low tens of dollars per month before free-tier credits or usage-specific charges.

## Cleanup

```bash
cd terraform
terraform destroy

cd bootstrap-state
terraform destroy
```
