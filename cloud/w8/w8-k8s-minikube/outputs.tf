output "ec2_public_ip" {
  description = "The Public IP address of the EC2 instance hosting Minikube"
  value       = aws_instance.k8s_node.public_ip
}

output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = aws_lb.app_alb.dns_name
}

output "app_url" {
  description = "The URL to access the deployed web application"
  value       = "http://${aws_lb.app_alb.dns_name}"
}
