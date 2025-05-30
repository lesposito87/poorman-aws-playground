locals {
  harbor_projects_proxy_cache = {
    "docker-hub" = {
      registry_name = "docker-hub"
      provider_name = "docker-hub"
      endpoint_url  = "https://hub.docker.com"
      public        = true
    }
  }
  effective_projects_proxy_cache = var.eks_deploy ? {} : local.harbor_projects_proxy_cache
}

resource "harbor_project" "project_cache" {
  for_each = local.effective_projects_proxy_cache

  name                   = each.key
  registry_id            = harbor_registry.registry_cache[each.key].registry_id
  public                 = each.value.public
  vulnerability_scanning = false
  force_destroy          = true
  depends_on = [
    helm_release.harbor
  ]
}

resource "harbor_registry" "registry_cache" {
  for_each = local.effective_projects_proxy_cache

  provider_name = each.value.provider_name
  name          = each.value.registry_name
  endpoint_url  = each.value.endpoint_url
  depends_on = [
    helm_release.harbor
  ]
}
