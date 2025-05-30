locals {
  karpenter_az = {
    aza = {
      name = "${var.region}a"
    }
    azb = {
      name = "${var.region}b"
    }
    azc = {
      name = "${var.region}c"
    }
  }
  karpenter_instance_family = ["t3","t3a","t4g"]
  karpenter_instance_size   = ["nano","micro","small","medium","large"]
}

resource "kubectl_manifest" "karpenter_nodepool_default" {
  count = var.eks_deploy ? 1 : 0

  yaml_body = <<YAML
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 1m
    expireAfter: 720h
  limits:
    cpu: 30
  template:
    metadata:
      labels:
        provisioner: karpenter
    spec:
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: default
      requirements:
        - key: "topology.kubernetes.io/zone"
          operator: In
          values: [${local.karpenter_az[var.vpc_primary_az].name}]
        - key: karpenter.sh/capacity-type
          operator: In
          values:
            - spot
        - key: karpenter.k8s.aws/instance-hypervisor
          operator: In
          values:
            - nitro
        - key: kubernetes.io/arch
          operator: In
          values:
            - amd64
            - arm64
        - key: karpenter.k8s.aws/instance-family
          operator: In
          values: ${jsonencode(local.karpenter_instance_family)}
        - key: karpenter.k8s.aws/instance-size
          operator: In
          values: ${jsonencode(local.karpenter_instance_size)}
        - key: kubernetes.io/os
          operator: In
          values:
            - linux
      taints:
        - effect: NoSchedule
          key: karpenter
          value: schedule
 YAML

  depends_on = [
    helm_release.karpenter[0]
  ]
}
