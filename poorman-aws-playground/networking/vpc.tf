module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.5.0"

  name = var.vpc_name
  cidr = var.vpc_cidr

  azs             = var.vpc_azs
  public_subnets  = var.vpc_public_subnets_cidr
  private_subnets = var.vpc_private_subnets_cidr

  enable_nat_gateway            = false
  create_database_subnet_group  = false
  manage_default_route_table    = false
  manage_default_security_group = false
  map_public_ip_on_launch       = true

  private_subnet_tags = {
    "karpenter.sh/discovery" = var.eks_cluster_name
  }
}
