resource "aws_iam_role" "karpenter_nodes" {
  count = var.eks_deploy ? 1 : 0

  name = "karpenter-nodes"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_eks_access_entry" "karpenter_nodes" {
  count = var.eks_deploy ? 1 : 0

  cluster_name  = var.eks_cluster_name
  principal_arn = aws_iam_role.karpenter_nodes[0].arn
  type          = "EC2_LINUX"
}

resource "aws_iam_role_policy_attachment" "amazon-eks-worker-node-policy" {
  count = var.eks_deploy ? 1 : 0

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.karpenter_nodes[0].name
}

resource "aws_iam_role_policy_attachment" "amazon-eks-cni-policy" {
  count = var.eks_deploy ? 1 : 0

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.karpenter_nodes[0].name
}

resource "aws_iam_role_policy_attachment" "amazon-ec2-container-registry-read-only" {
  count = var.eks_deploy ? 1 : 0

  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.karpenter_nodes[0].name
}

resource "aws_iam_role_policy_attachment" "amazon-ssm-managed-instance-core" {
  count = var.eks_deploy ? 1 : 0

  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.karpenter_nodes[0].name
}

module "iam_eks_role_karpenter_controller" {
  count    = var.eks_deploy ? 1 : 0
  source   = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version  = "6.2.1"
  role_name = "karpenter-controller"

  oidc_providers = {
    main = {
      provider_arn               = data.terraform_remote_state.core_infra.outputs.eks_oidc_provider_arn
      namespace_service_accounts = ["kube-system:karpenter"]
    }
  }
}

resource "aws_iam_role_policy" "karpenter_controller" {
  count = var.eks_deploy ? 1 : 0

  name = "karpenter-controller"
  role = module.iam_eks_role_karpenter_controller[0].iam_role_name
  policy = jsonencode({
    "Statement" : [
      {
        "Action" : [
          "ssm:GetParameter",
          "ec2:DescribeImages",
          "ec2:RunInstances",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DeleteLaunchTemplate",
          "ec2:CreateTags",
          "ec2:CreateLaunchTemplate",
          "ec2:CreateFleet",
          "ec2:DescribeSpotPriceHistory",
          "pricing:GetProducts"
        ],
        "Effect" : "Allow",
        "Resource" : "*",
        "Sid" : "Karpenter"
      },
      {
        "Action" : "ec2:TerminateInstances",
        "Condition" : {
          "StringLike" : {
            "ec2:ResourceTag/karpenter.sh/nodepool" : "*"
          }
        },
        "Effect" : "Allow",
        "Resource" : "*",
        "Sid" : "ConditionalEC2Termination"
      },
      {
        "Effect" : "Allow",
        "Action" : "iam:PassRole",
        "Resource" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${aws_iam_role.karpenter_nodes[0].name}",
        "Sid" : "PassNodeIAMRole"
      },
      {
        "Effect" : "Allow",
        "Action" : "eks:DescribeCluster",
        "Resource" : "arn:aws:eks:${var.region}:${data.aws_caller_identity.current.account_id}:cluster/${var.eks_cluster_name}",
        "Sid" : "EKSClusterEndpointLookup"
      },
      {
        "Sid" : "AllowScopedInstanceProfileCreationActions",
        "Effect" : "Allow",
        "Resource" : "*",
        "Action" : [
          "iam:CreateInstanceProfile"
        ],
        "Condition" : {
          "StringEquals" : {
            "aws:RequestTag/kubernetes.io/cluster/${var.eks_cluster_name}" : "owned",
            "aws:RequestTag/topology.kubernetes.io/region" : "${var.region}"
          },
          "StringLike" : {
            "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass" : "*"
          }
        }
      },
      {
        "Sid" : "AllowScopedInstanceProfileTagActions",
        "Effect" : "Allow",
        "Resource" : "*",
        "Action" : [
          "iam:TagInstanceProfile"
        ],
        "Condition" : {
          "StringEquals" : {
            "aws:ResourceTag/kubernetes.io/cluster/${var.eks_cluster_name}" : "owned",
            "aws:ResourceTag/topology.kubernetes.io/region" : "${var.region}",
            "aws:RequestTag/kubernetes.io/cluster/${var.eks_cluster_name}" : "owned",
            "aws:RequestTag/topology.kubernetes.io/region" : "${var.region}"
          },
          "StringLike" : {
            "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass" : "*",
            "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass" : "*"
          }
        }
      },
      {
        "Sid" : "AllowScopedInstanceProfileActions",
        "Effect" : "Allow",
        "Resource" : "*",
        "Action" : [
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:DeleteInstanceProfile"
        ],
        "Condition" : {
          "StringEquals" : {
            "aws:ResourceTag/kubernetes.io/cluster/${var.eks_cluster_name}" : "owned",
            "aws:ResourceTag/topology.kubernetes.io/region" : "${var.region}"
          },
          "StringLike" : {
            "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass" : "*"
          }
        }
      },
      {
        "Sid" : "AllowInstanceProfileReadActions",
        "Effect" : "Allow",
        "Resource" : "*",
        "Action" : "iam:GetInstanceProfile"
      }
    ],
    "Version" : "2012-10-17"
  })
}
