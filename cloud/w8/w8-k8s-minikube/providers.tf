provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

provider "kubernetes" {
  host                   = "https://${aws_instance.k8s_node.public_ip}:8443"
  client_certificate     = data.external.kube_creds.result["cert"]
  client_key             = data.external.kube_creds.result["key"]
  cluster_ca_certificate = data.external.kube_creds.result["ca"]
}
