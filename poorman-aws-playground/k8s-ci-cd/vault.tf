resource "aws_kms_key" "vault" {
  enable_key_rotation = true
}

resource "kubernetes_namespace" "vault" {
  metadata {
    name = "vault"
  }
}

resource "aws_route53_record" "vault" {
  name     = "vault.${var.route53_private_zone}"
  type     = "CNAME"
  ttl      = "300"
  records  = [data.terraform_remote_state.k8s_core_apps.outputs.nginx_ingress_controller_fqdn]
  zone_id  = data.aws_route53_zone.route53_private_zone.zone_id
}

resource "helm_release" "vault" {
  name       = "vault"
  chart      = "vault"
  repository = "https://helm.releases.hashicorp.com"
  version    = "0.30.1"
  namespace  = kubernetes_namespace.vault.metadata[0].name
  values = [
    templatefile("vault-values.tpl.yaml", {
        vault_hostname = aws_route53_record.vault.fqdn
        region         = var.region
        kms_key_id     = aws_kms_key.vault.key_id
        role_arn       = var.eks_deploy ? module.iam_eks_role_vault[0].iam_role_arn : "placeholder"
    })
  ]
}

resource "null_resource" "vault_init_check" {
  triggers = {
    values_md5 = filemd5("${path.module}/vault-values.tpl.yaml")
  }

  provisioner "local-exec" {
    command = <<EOT
      while [ "$(AWS_SHARED_CREDENTIALS_FILE='${var.aws_shared_credentials_file}' \
                KUBECONFIG='${var.kubeconfig_local_file}' \
                kubectl get pod vault-0 -n ${kubernetes_namespace.vault.metadata[0].name} -o jsonpath='{.status.phase}')" != "Running" ]; do
        echo "Waiting for vault-0 pod to be in Running state..."
        sleep 5
      done
      echo "Vault pod is now Running, executing initialization check..."

      AWS_SHARED_CREDENTIALS_FILE='${var.aws_shared_credentials_file}' \
      KUBECONFIG='${var.kubeconfig_local_file}' \
      kubectl exec vault-0 -n ${kubernetes_namespace.vault.metadata[0].name} -- /bin/sh -c "
        if vault status -format=json | grep -q '\"initialized\": false'; then
          echo 'Vault is not initialized, running command...';
          vault operator init | tee /vault/data/vault-init-keys.txt;
        else
          echo 'Vault is already initialized.';
        fi
      "

      AWS_SHARED_CREDENTIALS_FILE='${var.aws_shared_credentials_file}' \
      KUBECONFIG='${var.kubeconfig_local_file}' \
      kubectl exec vault-0 -n ${kubernetes_namespace.vault.metadata[0].name} -- /bin/sh -c "
        grep 'Initial Root Token' /vault/data/vault-init-keys.txt | awk '{print \$NF}'
      " > ${var.vault_root_token}

      chmod 600 ${var.vault_root_token}

      echo "Vault Root token saved to ${var.vault_root_token}"
    EOT
  }

  depends_on = [helm_release.vault]
}

resource "vault_mount" "kvv2" {
  path        = "secret"
  type        = "kv"
  options     = { version = "2" }
  description = "KV Version 2 secret engine mount"
  depends_on = [ null_resource.vault_init_check ]
}
