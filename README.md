# anons2003-aws-accelerator-p2

Personal AWS Accelerator Phase 2 repository.

This repo is organized by week and day. The main deliverable for the Kubernetes
on AWS challenge is in `cloud/w8/lab/k8s-web-demo`.

## Structure

```text
cloud/
  w8/
    day-a/          # Terraform
    day-b/          # K8s Container/Orchestration
    day-c/          # K8s Scaling + Networking
    lab/            # Minimal K8s platform
      k8s-web-demo/ # EC2 + Docker + minikube + ALB demo
    reflection.md
  w9/
  w10/
capstone/
  w11/
  w12/
```

## Main Lab

Go to the lab folder:

```bash
cd cloud/w8/lab/k8s-web-demo
```

Run locally with Docker:

```bash
docker build -t k8s-web-demo:local .
docker run --rm -p 8080:80 k8s-web-demo:local
```

Run locally with minikube:

```bash
docker build -t k8s-web-demo:local .
minikube image load k8s-web-demo:local
kubectl apply -f k8s/
minikube service web-demo --url
```

Deploy to AWS with Terraform:

```bash
cd cloud/w8/lab/k8s-web-demo/terraform
terraform init
terraform plan
terraform apply
terraform output -raw app_url
```

Destroy AWS resources after the demo:

```bash
terraform destroy
```

## Commit Convention

Use the course format:

```text
[W8-D1] <short topic>
```

Example:

```text
[W8-D1] add k8s web demo terraform stack
```
