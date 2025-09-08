module "iam_eks_role_keda" {
  count     = var.eks_deploy ? 1 : 0
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version   = "6.2.1"
  name      = "keda-operator"

  oidc_providers = {
    main = {
      provider_arn               = data.terraform_remote_state.core_infra.outputs.eks_oidc_provider_arn
      namespace_service_accounts = ["keda:keda-operator"]
    }
  }

  depends_on = [ helm_release.prometheus ]
}
