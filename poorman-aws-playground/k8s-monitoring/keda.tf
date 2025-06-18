resource "helm_release" "keda" {
  name             = "keda"
  repository       = "https://kedacore.github.io/charts"
  chart            = "keda"
  version          = "2.17.2"
  namespace        = "keda"
  create_namespace = true

  values = [
    templatefile("${path.module}/keda-values.tpl.yaml", {
      keda_operator_role_arn = var.eks_deploy ? module.iam_eks_role_keda[0].iam_role_arn : "placeholder"
    })
  ]
}
