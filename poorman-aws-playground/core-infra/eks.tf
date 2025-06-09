module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.37.0"

  count = var.eks_deploy ? 1 : 0

  cluster_name    = var.eks_cluster_name
  cluster_version = "1.32"

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = false

  create_kms_key            = false
  cluster_encryption_config = {}

  cluster_addons = {
    coredns = {
      most_recent       = true
      resolve_conflicts = "OVERWRITE"
      configuration_values = jsonencode({
        "tolerations" : [
          {
            "key" : "role",
            "operator" : "Equal",
            "value" : "core",
            "effect" : "NoSchedule"
          }
        ],
        "nodeSelector" : {
          "role" : "core"
        }
      })
    }
    kube-proxy = {
      most_recent       = true
      resolve_conflicts = "OVERWRITE"
    }
    vpc-cni = {
      most_recent              = true
      resolve_conflicts        = "OVERWRITE"
      service_account_role_arn = module.vpc_cni_irsa[0].iam_role_arn
    }
  }

  vpc_id     = data.aws_vpcs.vpc.ids[0]
  subnet_ids = concat(data.aws_subnets.private_subnets_aza.ids, data.aws_subnets.private_subnets_azb.ids, data.aws_subnets.private_subnets_azc.ids)

  node_security_group_tags = {
    "kubernetes.io/cluster/${var.eks_cluster_name}"  = null
    "karpenter.sh/discovery" = var.eks_cluster_name
  }

  cluster_security_group_additional_rules = {
    ingress_api_access_https_tcp = {
      description = "Allow access to API"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      cidr_blocks = [var.vpc_cidr]
      type        = "ingress"
    }
    egress_all = {
      description = "All egress"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "egress"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  node_security_group_additional_rules = {
    ingress_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    egress_all = {
      description = "All egress"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "egress"
      cidr_blocks = ["0.0.0.0/0"]
    }
    nginx_http = {
      description = "Whitelist http NGINX Ingress controller port from within VPC"
      protocol    = "tcp"
      from_port   = var.k8s_nginx_http_host_port
      to_port     = var.k8s_nginx_http_host_port
      type        = "ingress"
      cidr_blocks = [var.vpc_cidr]
    }
    nginx_https = {
      description = "Whitelist https NGINX Ingress controller port from within VPC"
      protocol    = "tcp"
      from_port   = var.k8s_nginx_https_host_port
      to_port     = var.k8s_nginx_https_host_port
      type        = "ingress"
      cidr_blocks = [var.vpc_cidr]
    }
    vault_injector = {
      description = "Whitelist port 8080 required by Vault Injector"
      protocol    = "tcp"
      from_port   = "8080"
      to_port     = "8080"
      type        = "ingress"
      cidr_blocks = [var.vpc_cidr]
    }
  }

  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    instance_types             = var.eks_core_instance_type
    iam_role_attach_cni_policy = true
  }

  eks_managed_node_groups = {
    core = {
      # Change this based on which AZ fck-nat is deployed #
      subnet_ids      = data.aws_subnets.private_subnets_aza.ids
      ami_type        = "AL2_ARM_64"
      min_size        = 1
      max_size        = 1
      desired_size    = 1
      capacity_type   = "ON_DEMAND"
      labels = {
        role = "core"
      }
      taints = [
        {
          key    = "role"
          value  = "core"
          effect = "NO_SCHEDULE"
        }
      ]
    }

  }

  # Cluster access entry
  enable_cluster_creator_admin_permissions = true

  authentication_mode = "API_AND_CONFIG_MAP"

  access_entries = {
    root_iam_principal_access = {
      kubernetes_groups = []
      principal_arn     = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      policy_associations = {
        example = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
    fck_nat_read_access = {
      kubernetes_groups = []
      principal_arn     = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/fck-nat-${var.vpc_primary_az}"
      policy_associations = {
        example = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }

  }

  depends_on = [ null_resource.ansible_playbook ]
}

# https://docs.aws.amazon.com/eks/latest/userguide/managing-vpc-cni.html #
module "vpc_cni_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.55"
  
  count = var.eks_deploy ? 1 : 0

  role_name_prefix      = "VPC-CNI-IRSA"
  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks[0].oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }
  tags = {
    Name = "${var.account_name}-vpc-cni-irsa"
  }
}
