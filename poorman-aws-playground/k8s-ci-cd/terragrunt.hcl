include "root" {
  path = find_in_parent_folders("root.hcl")
}

dependencies {
  paths = ["../k8s-core-apps"]
}
