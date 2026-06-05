locals {
  tags = merge(
    {
      Project = var.project_name
      Managed = "terraform"
    },
    var.tags
  )
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default_public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_sensitive_file" "ssh_private_key" {
  content         = tls_private_key.ssh.private_key_pem
  filename        = "${path.module}/.generated/${var.project_name}.pem"
  file_permission = "0400"
}

resource "aws_key_pair" "demo" {
  key_name   = "${var.project_name}-key"
  public_key = tls_private_key.ssh.public_key_openssh
  tags       = local.tags
}

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Allow HTTP from the Internet to the demo ALB"
  vpc_id      = data.aws_vpc.default.id
  tags        = local.tags

  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-ec2-sg"
  description = "Allow SSH and ALB traffic to the minikube NodePort"
  vpc_id      = data.aws_vpc.default.id
  tags        = local.tags

  ingress {
    description = "SSH for Terraform bootstrap and debugging"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_cidr_blocks
  }

  ingress {
    description     = "ALB to Kubernetes NodePort"
    from_port       = 30080
    to_port         = 30080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "k8s" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnets.default_public.ids[0]
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  key_name                    = aws_key_pair.demo.key_name
  associate_public_ip_address = true
  user_data                   = file("${path.module}/user_data.sh")

  root_block_device {
    encrypted   = true
    volume_size = 30
    volume_type = "gp3"
  }

  tags = merge(local.tags, {
    Name = "${var.project_name}-minikube"
  })
}

resource "aws_lb" "app" {
  name               = "${var.project_name}-alb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb.id]
  subnets            = slice(data.aws_subnets.default_public.ids, 0, 2)
  tags               = local.tags
}

resource "aws_lb_target_group" "app" {
  name        = "${var.project_name}-tg"
  port        = 30080
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = data.aws_vpc.default.id
  tags        = local.tags

  health_check {
    enabled             = true
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_target_group_attachment" "app" {
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.k8s.id
  port             = 30080
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "null_resource" "deploy_app" {
  depends_on = [
    aws_instance.k8s,
    local_sensitive_file.ssh_private_key
  ]

  triggers = {
    dockerfile_sha = filesha256("${path.module}/../Dockerfile")
    index_sha      = filesha256("${path.module}/../index.html")
    styles_sha     = filesha256("${path.module}/../styles.css")
    nginx_conf_sha = filesha256("${path.module}/../nginx.conf")
    deployment_sha = filesha256("${path.module}/../k8s/deployment.yaml")
    service_sha    = filesha256("${path.module}/../k8s/service.yaml")
    instance_id    = aws_instance.k8s.id
  }

  connection {
    type        = "ssh"
    user        = "ec2-user"
    host        = aws_instance.k8s.public_ip
    private_key = tls_private_key.ssh.private_key_pem
    timeout     = "10m"
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p /home/ec2-user/app/k8s",
      "while [ ! -f /var/log/k8s-web-demo-bootstrap.done ]; do echo 'waiting for EC2 bootstrap...'; sleep 5; done"
    ]
  }

  provisioner "file" {
    source      = "${path.module}/../Dockerfile"
    destination = "/home/ec2-user/app/Dockerfile"
  }

  provisioner "file" {
    source      = "${path.module}/../index.html"
    destination = "/home/ec2-user/app/index.html"
  }

  provisioner "file" {
    source      = "${path.module}/../styles.css"
    destination = "/home/ec2-user/app/styles.css"
  }

  provisioner "file" {
    source      = "${path.module}/../nginx.conf"
    destination = "/home/ec2-user/app/nginx.conf"
  }

  provisioner "file" {
    source      = "${path.module}/../k8s/deployment.yaml"
    destination = "/home/ec2-user/app/k8s/deployment.yaml"
  }

  provisioner "file" {
    source      = "${path.module}/../k8s/service.yaml"
    destination = "/home/ec2-user/app/k8s/service.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "set -euxo pipefail",
      "cd /home/ec2-user/app",
      "minikube status || minikube start --driver=docker --ports=30080:30080 --cpus=2 --memory=2600",
      "docker build -t k8s-web-demo:local .",
      "minikube image load k8s-web-demo:local",
      "kubectl apply -f k8s/",
      "kubectl rollout status deploy/web-demo --timeout=180s",
      "kubectl get deploy,svc,pods -l app=web-demo"
    ]
  }
}
