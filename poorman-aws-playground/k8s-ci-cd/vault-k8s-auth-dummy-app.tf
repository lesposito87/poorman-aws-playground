resource "kubernetes_namespace" "dummy_vault_app" {
  metadata {
    name = "dummy-vault-app"
  }
  depends_on = [ null_resource.vault_init_check ]
}

resource "kubernetes_service_account" "dummy_vault_app" {
  metadata {
    name      = "dummy-vault-app"
    namespace = kubernetes_namespace.dummy_vault_app.metadata[0].name
  }
}

resource "kubernetes_secret" "dummy_vault_app" {
  metadata {
    name      = "dummy-vault-app"
    namespace = kubernetes_namespace.dummy_vault_app.metadata[0].name
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.dummy_vault_app.metadata.0.name
    }
  }

  type = "kubernetes.io/service-account-token"
}

resource "vault_policy" "dummy_vault_app" {
  name   = "dummy-vault-app-policy"
  policy = <<EOF
path "secret/data/dummy-vault-app" {
  capabilities = ["read", "list"]
}

path "secret/metadata/dummy-vault-app" {
  capabilities = ["read", "list"]
}
EOF
  depends_on = [ null_resource.vault_init_check ]
}

resource "vault_kubernetes_auth_backend_role" "dummy_vault_app" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "dummy-vault-app-role"
  bound_service_account_names      = [kubernetes_service_account.dummy_vault_app.metadata.0.name]
  bound_service_account_namespaces = [kubernetes_namespace.dummy_vault_app.metadata[0].name]
  token_policies                   = [vault_policy.dummy_vault_app.name]
  token_ttl                        = 3600
}

# Set this to true if you want to deploy the dummy app to test Vault Secrets Injection.
# Make sure to create the vault secret "dummy-vault-app" (on "secret" kvv2 engine) before deploying the app!
locals {
  vault_deploy_dummy_app = false
}

resource "kubernetes_deployment" "dummy_vault_app" {
  count = local.vault_deploy_dummy_app ? 1 : 0
  metadata {
    name      = "dummy-vault-app"
    namespace = kubernetes_namespace.dummy_vault_app.metadata[0].name
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "nginx"
      }
    }
    template {
      metadata {
        labels = {
          app = "nginx"
        }
        annotations = {
          "vault.hashicorp.com/agent-inject"                       = "true"
          "vault.hashicorp.com/role"                               = "dummy-vault-app-role"
          "vault.hashicorp.com/agent-inject-secret-appsecrets.yaml"   = "secret/dummy-vault-app"
          "vault.hashicorp.com/agent-inject-template-appsecrets.yaml" = <<EOT
{{- with secret "secret/dummy-vault-app" -}}
{{ range $k, $v := .Data.data -}}
{{ $k }}: {{ $v }}
{{ end -}}
{{- end -}}
EOT
        }
      }
      spec {
        service_account_name = kubernetes_service_account.dummy_vault_app.metadata.0.name
        toleration {
          key      = "karpenter"
          operator = "Equal"
          value    = "schedule"
          effect   = "NoSchedule"
        }
        toleration {
          key      = "role"
          operator = "Equal"
          value    = "core"
          effect   = "NoSchedule"
        }
        container {
          name  = "nginx"
          image = "nginx:latest"
          port {
            container_port = 80
          }
        }
      }
    }
  }
  depends_on = [ vault_kubernetes_auth_backend_role.dummy_vault_app ]
}
