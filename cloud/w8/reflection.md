# W8 Reflection

## What I Built

I built a small static web app that runs in Kubernetes through minikube and can
be exposed from AWS through an Application Load Balancer.

## Key Lessons

- A Deployment manages ReplicaSets, and ReplicaSets keep the requested number of
  Pods running.
- A NodePort Service can expose Pods on a stable port.
- An ALB does not talk to Pods directly in this design. It talks to the EC2 host
  on port `30080`, and that port is mapped into minikube.
- Terraform can wire multiple providers together in one apply.

## Provider Wiring

- `aws` creates the infrastructure.
- `tls` creates an SSH key.
- `local` writes the private key to disk.
- `null` uses the key to upload and deploy the app on EC2.

## Cleanup Reminder

Always run:

```bash
terraform destroy
```

after the AWS demo to avoid leaving paid resources running.
