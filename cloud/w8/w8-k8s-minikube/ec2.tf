# Generate SSH Key pair
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "key" {
  key_name   = var.key_name
  public_key = tls_private_key.ssh_key.public_key_openssh
}

# Save private key locally for convenience
resource "local_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "${path.module}/private_key.pem"
  file_permission = "0600"
}

# Query the latest Ubuntu 22.04 LTS AMI
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

# EC2 Instance for Minikube
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

# External Data Source to fetch the certificates from the host via SSH
data "external" "kube_creds" {
  program = ["powershell", "-ExecutionPolicy", "Bypass", "-File", "${path.module}/get_creds.ps1"]

  query = {
    host        = aws_instance.k8s_node.public_ip
    private_key = tls_private_key.ssh_key.private_key_pem
  }
}
