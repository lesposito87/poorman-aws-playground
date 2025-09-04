resource "kubernetes_namespace" "grafana" {
  metadata {
    name = "grafana"
  }
}

resource "aws_route53_record" "grafana" {
  name    = "grafana.${var.route53_private_zone}"
  type    = "CNAME"
  ttl     = "300"
  records = [data.terraform_remote_state.k8s_core_apps.outputs.nginx_ingress_controller_fqdn]
  zone_id = data.aws_route53_zone.route53_private_zone.zone_id
}

resource "helm_release" "grafana" {
  name       = "grafana"
  namespace  = kubernetes_namespace.grafana.metadata[0].name
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  version    = "9.4.4"

  set_sensitive {
    name  = "adminPassword"
    value = var.grafana_admin_pwd
  }

  values = [templatefile("${path.module}/grafana-values.tpl.yaml",
    {
      grafana_hostname   = aws_route53_record.grafana.fqdn
      grafana_admin_user = "admin"
      storage_class      = var.eks_deploy ? "gp3" : "local-path"
    }
  )]
}

resource "grafana_data_source" "prometheus" {
  type = "prometheus"
  name = "prometheus"
  url  = "http://prometheus-server.prometheus.svc.cluster.local"
  uid  = "prometheus"

  depends_on = [
    helm_release.grafana,
    helm_release.prometheus
  ]
}

locals {
  grafana_folders = [
    "K8s"
  ]
  grafana_dashboards = {
    k8s_overview = {
      folder      = "K8s"
      config_json = file("${path.module}/files/grafana/dashboards/k8s-overview.json")
    }
  }
}

resource "grafana_folder" "folders" {
  for_each = toset(local.grafana_folders)

  title = each.key

  depends_on = [
    helm_release.grafana
  ]
}

resource "grafana_dashboard" "dashboards" {
  for_each = { for d, values in local.grafana_dashboards : d => values }

  folder      = grafana_folder.folders[each.value.folder].id
  config_json = each.value.config_json
}
