output "eks_oidc_provider_arn" {
  value = var.eks_deploy ? module.eks[0].oidc_provider_arn : null
}

output "k3s_iam_role_name" {
  value = local.k3s.k3s_deploy ? aws_iam_role.k3s[0].name : null
}

output "k3s_api_url" {
  value = local.k3s.k3s_deploy ? "https://${aws_instance.k3s[0].private_ip}:6443" : null
}
