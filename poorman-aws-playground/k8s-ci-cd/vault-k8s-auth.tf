resource "kubernetes_secret" "vault" {
  metadata {
    name      = "vault"
    namespace = kubernetes_namespace.vault.metadata[0].name
    annotations = {
      "kubernetes.io/service-account.name" = "vault"
    }
  }

  type = "kubernetes.io/service-account-token"
  depends_on = [ helm_release.vault ]
}

resource "kubernetes_cluster_role_binding" "vault_auth_token_review" {
  metadata {
    name = "vault-auth-token-review"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "system:auth-delegator"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "vault"
    namespace = kubernetes_namespace.vault.metadata[0].name
  }
  depends_on = [ helm_release.vault ]
}

resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
  depends_on = [ null_resource.vault_init_check ]
}

resource "vault_kubernetes_auth_backend_config" "cluster" {
  backend                = vault_auth_backend.kubernetes.path
  #kubernetes_host        = data.aws_eks_cluster.cluster.endpoint
  kubernetes_host        = var.eks_deploy ? data.aws_eks_cluster.cluster[0].endpoint : data.terraform_remote_state.core_infra.outputs.k3s_api_url
  token_reviewer_jwt     = kubernetes_secret.vault.data["token"]
  kubernetes_ca_cert     = kubernetes_secret.vault.data["ca.crt"]
  disable_iss_validation = true
  disable_local_ca_jwt   = true
}
