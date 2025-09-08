module "iam_eks_role_vault" {
  count     = var.eks_deploy ? 1 : 0
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version   = "6.2.1"
  role_name = "vault"

  oidc_providers = {
    main = {
      provider_arn               = data.terraform_remote_state.core_infra.outputs.eks_oidc_provider_arn
      namespace_service_accounts = ["vault:vault"]
    }
  }
}

resource "aws_iam_role_policy" "vault" {
  name = "vault"
  #role = module.iam_eks_role_vault.iam_role_name
  role = var.eks_deploy ? module.iam_eks_role_vault[0].iam_role_name : data.terraform_remote_state.core_infra.outputs.k3s_iam_role_name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "VaultKMSUnseal"
        Effect    = "Allow"
        Action    = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource  = [aws_kms_key.vault.arn]
      }
    ]
  })
}
