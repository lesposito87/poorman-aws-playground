resource "helm_release" "kube_state_metrics" {
  name       = "kube-state-metrics"
  chart      = "kube-state-metrics"
  repository = "https://prometheus-community.github.io/helm-charts"
  version    = "5.33.2"
  namespace  = "kube-system"
  values = [
    file("kube-state-metrics-values.yaml"),
  ]
}
