resource "null_resource" "eks_kubeconfig_generator" {
  count = var.eks_deploy ? 1 : 0

  triggers = {
    always = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = "AWS_SHARED_CREDENTIALS_FILE=${var.aws_shared_credentials_file} aws eks update-kubeconfig --name ${var.eks_cluster_name} --region ${var.region} --kubeconfig ${var.kubeconfig_local_file}"
  }

  depends_on = [module.eks[0]]
}
