resource "helm_release" "metrics-server" {
  name       = "metrics-server"
  chart      = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  version    = "3.12.2"
  namespace  = "kube-system"
  values = [
    file("metrics-server-values.yaml"),
  ]
}
