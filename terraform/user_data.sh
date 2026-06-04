#!/bin/bash
set -euxo pipefail

exec > >(tee /var/log/k8s-web-demo-bootstrap.log) 2>&1

dnf update -y --allowerasing
dnf install -y docker git tar gzip conntrack

systemctl enable --now docker
usermod -aG docker ec2-user

curl -fsSL -o /usr/local/bin/kubectl \
  "https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x /usr/local/bin/kubectl

curl -fsSL -o /usr/local/bin/minikube \
  https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
chmod +x /usr/local/bin/minikube

cat >/etc/profile.d/minikube.sh <<'EOF'
export CHANGE_MINIKUBE_NONE_USER=true
EOF

touch /var/log/k8s-web-demo-bootstrap.done
