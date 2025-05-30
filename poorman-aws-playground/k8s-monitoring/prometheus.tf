resource "kubernetes_namespace" "prometheus" {
  metadata {
    name = "prometheus"
  }
}

resource "aws_route53_record" "prometheus" {
  name    = "prometheus.${var.route53_private_zone}"
  type    = "CNAME"
  ttl     = "300"
  records = [data.terraform_remote_state.k8s_core_apps.outputs.nginx_ingress_controller_fqdn]
  zone_id = data.aws_route53_zone.route53_private_zone.zone_id
}

resource "helm_release" "prometheus" {
  name       = "prometheus"
  namespace  = kubernetes_namespace.prometheus.metadata[0].name
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  version    = "27.16.0"
  values = [templatefile("${path.module}/prometheus-values.tpl.yaml",
    {
      prometheus_hostname = aws_route53_record.prometheus.fqdn
      storage_class       = var.eks_deploy ? "gp3" : "local-path"
    }
  )]
}
