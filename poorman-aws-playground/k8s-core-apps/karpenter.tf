### Add SQS => https://medium.com/@rphilogene/installing-karpenter-lessons-learned-from-our-experience-2f2cfb9bea9a

resource "aws_iam_service_linked_role" "spot" {
  count = var.eks_deploy ? 1 : 0

  aws_service_name = "spot.amazonaws.com"
}

resource "helm_release" "karpenter_crd" {
  count = var.eks_deploy ? 1 : 0

  chart      = "oci://public.ecr.aws/karpenter/karpenter-crd"
  name       = "karpenter-crd"
  namespace  = "kube-system"
  version    = "1.8.1"
  depends_on = [aws_iam_service_linked_role.spot[0]]
}

resource "helm_release" "karpenter" {
  count = var.eks_deploy ? 1 : 0

  chart     = "oci://public.ecr.aws/karpenter/karpenter"
  name      = "karpenter"
  namespace = "kube-system"
  version   = "1.8.1"

  values = [templatefile("${path.module}/karpenter-values.tpl.yaml",
    {
      iam_role_arn = module.iam_eks_role_karpenter_controller[0].arn
      cluster_name = var.eks_cluster_name
    }
  )]

  depends_on = [
    helm_release.karpenter_crd[0]
  ]
}
