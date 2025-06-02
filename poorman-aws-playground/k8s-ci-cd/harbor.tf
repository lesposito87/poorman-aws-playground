resource "kubernetes_namespace" "harbor" {
  metadata {
    name = "harbor"
  }
}

resource "aws_route53_record" "harbor" {
  name     = "harbor.${var.route53_private_zone}"
  type     = "CNAME"
  ttl      = "300"
  records  = [data.terraform_remote_state.k8s_core_apps.outputs.nginx_ingress_controller_fqdn]
  zone_id  = data.aws_route53_zone.route53_private_zone.zone_id
}

resource "helm_release" "harbor" {
  name       = "harbor"
  chart      = "harbor"
  repository = "https://helm.goharbor.io"
  version    = "1.17.1"
  namespace  = kubernetes_namespace.harbor.metadata[0].name
  values = [
    templatefile("harbor-values.tpl.yaml", {
      domain                    = var.route53_private_zone
      k8s_nginx_http_host_port = var.k8s_nginx_http_host_port
    })
  ]
  set_sensitive {
    name  = "harborAdminPassword"
    value = var.harbor_admin_pwd
  }
}
