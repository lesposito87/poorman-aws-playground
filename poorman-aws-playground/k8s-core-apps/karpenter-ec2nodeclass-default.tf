resource "kubectl_manifest" "karpenter_ec2nodeclass_default" {
  count = var.eks_deploy ? 1 : 0

  yaml_body = <<YAML
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
spec:
  amiFamily: AL2023
  role: "${aws_iam_role.karpenter_nodes[0].name}"
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "${var.eks_cluster_name}"
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: "${var.eks_cluster_name}"
  amiSelectorTerms:
    - alias: al2023@latest # Amazon Linux 2023
 YAML

  depends_on = [
    kubectl_manifest.karpenter_nodepool_default[0]
  ]
}

