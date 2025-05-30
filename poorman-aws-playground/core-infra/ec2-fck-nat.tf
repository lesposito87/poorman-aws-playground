locals {
  fck_nat = {
    aza = {
      name           = "fck-nat-aza"
      subnet_id      = data.aws_subnets.public_subnets_aza.ids[0]
      route_table_id = data.aws_route_tables.rtb_aza.ids[0]
    }
    azb = {
      name           = "fck-nat-azb"
      subnet_id      = data.aws_subnets.public_subnets_azb.ids[0]
      route_table_id = data.aws_route_tables.rtb_azb.ids[0]
    }
    azc = {
      name           = "fck-nat-azc"
      subnet_id      = data.aws_subnets.public_subnets_azc.ids[0]
      route_table_id = data.aws_route_tables.rtb_azc.ids[0]
    }
  }
}

data "aws_ami" "fck_nat" {
  filter {
    name   = "name"
    values = ["fck-nat"]
  }
  most_recent = true
  owners      = [data.aws_caller_identity.current.account_id]
}

module "fck_nat" {
  source = "github.com/RaJiska/terraform-aws-fck-nat"

  name                          = local.fck_nat[var.vpc_primary_az].name
  ami_id                        = data.aws_ami.fck_nat.id
  use_default_security_group    = false
  additional_security_group_ids = [aws_security_group.allow_all.id]
  use_cloudwatch_agent          = false
  vpc_id                        = data.aws_vpcs.vpc.ids[0]
  subnet_id                     = local.fck_nat[var.vpc_primary_az].subnet_id
  instance_type                 = var.ec2_fck_nat_instance_type
  ha_mode                       = false
  ebs_root_volume_size          = "8"

  update_route_table = true
  route_table_id     = local.fck_nat[var.vpc_primary_az].route_table_id
  tags = {
    Name = local.fck_nat[var.vpc_primary_az].name
  }
}

resource "aws_iam_policy" "eks_read_access" {
  name        = "${var.account_name}-eks-read-access"
  description = "EKS Read Access"

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "eks:DescribeCluster",
                "eks:ListClusters"
            ],
            "Resource": "arn:aws:eks:${var.region}:${data.aws_caller_identity.current.account_id}:cluster/${var.eks_cluster_name}"
        }
    ]
  })

  tags = {
    Name = "${var.account_name}-eks-read-access"
  }
}

resource "aws_iam_role_policy_attachment" "eks_read_access_fck_nat" {
  role       = basename(module.fck_nat.role_arn)
  policy_arn = aws_iam_policy.eks_read_access.arn

  depends_on = [module.fck_nat]
}

resource "null_resource" "ansible_playbook" {
  triggers = {
    fck_nat_instance_arn       = module.fck_nat.instance_arn
    fck_nat_instance_public_ip = module.fck_nat.instance_public_ip
  }

  provisioner "local-exec" {
    command = <<EOT
  while ! nc -zv "${module.fck_nat.instance_public_ip}" ${var.fck_nat_ssh_custom_port}; do
    echo "Waiting for ${module.fck_nat.instance_public_ip}:${var.fck_nat_ssh_custom_port} to be reachable..."
    sleep 5
  done

  cd ansible/playbooks/openvpn && ansible-galaxy install -r requirements.yml --force && ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i "${module.fck_nat.instance_public_ip}," \
    --ssh-extra-args "-o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedKeyTypes=+ssh-rsa -p ${var.fck_nat_ssh_custom_port} -i ${var.aws_key_pair_private}" \
    --user ec2-user \
    --become \
    --become-method sudo \
    --become-user root \
    --extra-vars "{\"ansible_host_key_checking\": false, \"ansible_retry_files_enabled\": false, \"ssh_port\": \"${var.fck_nat_ssh_custom_port}\", \"openvpn_server_ip\": \"${module.fck_nat.instance_public_ip}\", \"openvpn_client_bundle_copy_locally\": {\"local_copy\": true, \"client_dir\": \"${var.ansible_openvpn_client_dir}\"}}" \
    main.yml
EOT
  }
}
