# Set this to true if you want to deploy the dummy keda scaledobject
locals {
  keda_deploy_dummy_scaledobject = false
}

resource "kubectl_manifest" "keda_nginx_defaultbackend_scaledobject" {
  count = local.keda_deploy_dummy_scaledobject ? 1 : 0
  yaml_body = <<YAML
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: defaultbackend-scaledobject
  namespace: nginx-ingress-controller
  labels:
    deploymentName: nginx-ingress-controller-ingress-nginx-defaultbackend
spec:
  scaleTargetRef:
    kind: Deployment
    name: nginx-ingress-controller-ingress-nginx-defaultbackend 
  minReplicaCount: 1
  maxReplicaCount: 5
  pollingInterval: 5
  triggers:
  - type: prometheus
    metadata:
      serverAddress: http://prometheus-server.prometheus.svc.cluster.local
      metricName: nginx_ingress_controller_requests
      threshold: '1'
      query: sum(rate(nginx_ingress_controller_requests[2m]))
 YAML

  depends_on = [
    helm_release.keda,
    helm_release.prometheus
  ]
}
