data "http" "aws_ebs_csi_driver_iam_policy" {
  count = var.eks_deploy ? 1 : 0
  url   = "https://raw.githubusercontent.com/kubernetes-sigs/aws-ebs-csi-driver/v1.5.1/docs/example-iam-policy.json"
}

module "iam_eks_role_aws_ebs_csi_driver" {
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version   = "5.58.0"

  count = var.eks_deploy ? 1 : 0

  role_name = "eks-aws-ebs-csi-driver"

  oidc_providers = {
    main = {
      provider_arn               = data.terraform_remote_state.core_infra.outputs.eks_oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

resource "aws_iam_role_policy" "eks_aws_ebs_csi_driver" {
  count = var.eks_deploy ? 1 : 0

  name   = "eks-aws-ebs-csi-driver"
  role   = module.iam_eks_role_aws_ebs_csi_driver[0].iam_role_name
  policy = data.http.aws_ebs_csi_driver_iam_policy[0].response_body
}

resource "helm_release" "aws_ebs_csi_driver_controller" {
  count = var.eks_deploy ? 1 : 0

  name       = "aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  namespace  = "kube-system"
  version    = "2.45.1"

  values = [
    templatefile("${path.module}/aws-ebs-csi-driver-values.tpl.yaml", {
      role_arn   = module.iam_eks_role_aws_ebs_csi_driver[0].iam_role_arn
      cluster_id = var.eks_cluster_name
    })
  ]
}
