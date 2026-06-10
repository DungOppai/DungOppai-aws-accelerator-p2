# ==========================================
# 1. VPC & Networking Definitions (formerly vpc.tf)
# ==========================================

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "k8s-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "k8s-igw"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "k8s-public-subnet-${count.index}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "k8s-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "alb_sg" {
  name        = "k8s-alb-sg"
  description = "Allow public HTTP traffic to ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic to EC2 instances"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "k8s-alb-sg"
  }
}

resource "aws_security_group" "ec2_sg" {
  name        = "k8s-ec2-sg"
  description = "Security group for Minikube EC2 host"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow SSH for troubleshooting and credentials retrieval"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description     = "Allow HTTP from ALB target group"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    description = "Allow access to Kubernetes API Server from local machine"
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "k8s-ec2-sg"
  }
}

# ==========================================
# 2. EC2 & Minikube Host Definitions (formerly ec2.tf)
# ==========================================

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "key" {
  key_name   = var.key_name
  public_key = tls_private_key.ssh_key.public_key_openssh
}

resource "local_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "${path.module}/private_key.pem"
  file_permission = "0600"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "k8s_node" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  key_name                    = aws_key_pair.key.key_name
  associate_public_ip_address = true

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data = <<-EOF
#!/usr/bin/env bash
set -euo pipefail

# Redirect stdout and stderr to a log file
exec > >(tee -i /var/log/user-data.log) 2>&1

echo "=== Wait for apt locks ==="
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
  echo "Waiting for other software managers to finish..."
  sleep 5
done

echo "=== System Update and Package Installation ==="
apt-get update -y
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release socat conntrack

echo "=== Install Docker ==="
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io

# Enable Docker and add ubuntu user to docker group
systemctl start docker
systemctl enable docker
usermod -aG docker ubuntu

echo "=== Install kubectl ==="
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/

echo "=== Install Minikube ==="
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
install minikube-linux-amd64 /usr/local/bin/minikube
rm minikube-linux-amd64

echo "=== Start Minikube ==="
# Get EC2 Public IP using IMDSv2
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
PUBLIC_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4)

# Start Minikube as ubuntu user
sudo -i -u ubuntu minikube start --driver=docker --apiserver-ips=$PUBLIC_IP

echo "=== Setup Systemd Proxies for K8s API and App ==="
# Create K8s API Proxy Service
cat <<'SERVICESETUP' > /etc/systemd/system/k8s-api-proxy.service
[Unit]
Description=Kubernetes API Server Proxy
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash -c '/usr/bin/socat TCP-LISTEN:8443,fork,reuseaddr TCP:$(sudo -u ubuntu minikube ip):8443'
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICESETUP

# Create K8s App Proxy Service
cat <<'SERVICESETUP' > /etc/systemd/system/k8s-app-proxy.service
[Unit]
Description=Kubernetes App Service Proxy
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash -c '/usr/bin/socat TCP-LISTEN:80,fork,reuseaddr TCP:$(sudo -u ubuntu minikube ip):30000'
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICESETUP

# Enable and start services
systemctl daemon-reload
systemctl enable k8s-api-proxy.service k8s-app-proxy.service
systemctl start k8s-api-proxy.service k8s-app-proxy.service

echo "=== User Data Script Completed Successfully ==="
EOF

  tags = {
    Name = "k8s-minikube-host"
  }
}

data "external" "kube_creds" {
  program = ["powershell", "-ExecutionPolicy", "Bypass", "-File", "${path.module}/get_creds.ps1"]

  query = {
    host        = aws_instance.k8s_node.public_ip
    private_key = tls_private_key.ssh_key.private_key_pem
  }
}

# ==========================================
# 3. Application Load Balancer Definitions (formerly alb.tf)
# ==========================================

resource "aws_lb" "app_alb" {
  name               = "k8s-app-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public[*].id

  tags = {
    Name = "k8s-app-alb"
  }
}

resource "aws_lb_target_group" "app_tg" {
  name        = "k8s-app-tg"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    path                = "/"
    port                = var.app_port
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = {
    Name = "k8s-app-tg"
  }
}

resource "aws_lb_target_group_attachment" "app_tg_attachment" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.k8s_node.id
  port             = var.app_port
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# ==========================================
# 4. Kubernetes Application Resources (formerly k8s.tf)
# ==========================================

resource "kubernetes_deployment" "app" {
  metadata {
    name = "hello-app"
    labels = {
      app = "hello-app"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "hello-app"
      }
    }

    template {
      metadata {
        labels = {
          app = "hello-app"
        }
      }

      spec {
        container {
          name  = "hello-container"
          image = "nginxdemos/hello:latest"

          port {
            container_port = 80
          }

          resources {
            limits = {
              cpu    = "500m"
              memory = "256Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "64Mi"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "app_service" {
  metadata {
    name = "hello-service"
  }

  spec {
    selector = {
      app = kubernetes_deployment.app.metadata[0].labels.app
    }

    port {
      port        = 80
      target_port = 80
      node_port   = var.node_port
    }

    type = "NodePort"
  }
}
