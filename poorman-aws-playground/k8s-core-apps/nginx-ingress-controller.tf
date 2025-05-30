resource "kubernetes_namespace" "nginx_ingress_controller" {
  metadata {
    name = "nginx-ingress-controller"
  }
}

resource "helm_release" "nginx_ingress_chart" {
  name       = kubernetes_namespace.nginx_ingress_controller.metadata[0].name
  chart      = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  version    = "4.12.2"
  namespace  = kubernetes_namespace.nginx_ingress_controller.metadata[0].name
  values = [templatefile("${path.module}/nginx-ingress-controller-values.tpl.yaml",
    {
      vpc_cidr                  = var.vpc_cidr
      k8s_nginx_https_host_port = var.k8s_nginx_https_host_port
      k8s_nginx_http_host_port  = var.k8s_nginx_http_host_port
    }
  )]
}

data "kubernetes_resources" "nginx_ingress_controller_pod" {
  api_version    = "v1"
  namespace      = kubernetes_namespace.nginx_ingress_controller.metadata[0].name
  kind           = "Pod"
  label_selector = "app.kubernetes.io/component=controller,app.kubernetes.io/instance=nginx-ingress-controller"

  depends_on = [helm_release.nginx_ingress_chart]
}

resource "aws_route53_record" "nginx_ingress_controller" {
  name    = "k8s-nginx-ingress-controller.${var.route53_private_zone}"
  type    = "A"
  ttl     = "300"
  records = [data.kubernetes_resources.nginx_ingress_controller_pod.objects[0].status.hostIP]
  zone_id = data.aws_route53_zone.route53_private_zone.zone_id
}
