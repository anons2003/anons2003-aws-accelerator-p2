#!/bin/bash

# Dừng script ngay khi có lỗi, in lệnh đang chạy, và bắt lỗi trong pipeline.
set -euxo pipefail

# Ghi toàn bộ log bootstrap ra file để dễ debug sau khi EC2 khởi động.
exec > >(tee /var/log/k8s-web-demo-bootstrap.log) 2>&1

# Cập nhật hệ điều hành và cài các gói cần cho Docker, minikube và thao tác file.
dnf update -y --allowerasing
dnf install -y docker git tar gzip conntrack

# Bật Docker ngay lập tức và tự động bật lại khi EC2 reboot.
systemctl enable --now docker

# Cho user ec2-user quyền chạy Docker không cần sudo ở các lần đăng nhập sau.
usermod -aG docker ec2-user

# Tải kubectl bản stable mới nhất để Terraform có thể apply manifest Kubernetes.
curl -fsSL -o /usr/local/bin/kubectl \
  "https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x /usr/local/bin/kubectl

# Tải minikube để tạo cụm Kubernetes local chạy bằng Docker driver trên EC2.
curl -fsSL -o /usr/local/bin/minikube \
  https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
chmod +x /usr/local/bin/minikube

# Biến môi trường hỗ trợ minikube khi chạy trong môi trường bootstrap/SSH.
cat >/etc/profile.d/minikube.sh <<'EOF'
export CHANGE_MINIKUBE_NONE_USER=true
EOF

# Tạo file marker để Terraform biết EC2 đã bootstrap xong và có thể deploy app.
touch /var/log/k8s-web-demo-bootstrap.done
