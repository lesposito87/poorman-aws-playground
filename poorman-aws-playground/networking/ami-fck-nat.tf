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

data "aws_ami_ids" "fck_nat" {
  owners = [data.aws_caller_identity.current.account_id]

  filter {
    name   = "name"
    values = ["fck-nat"]
  }

  depends_on = [ module.vpc ]
}

data "aws_key_pair" "key" {
  key_name           = aws_key_pair.key.id
  include_public_key = true
}

resource "aws_key_pair" "key" {
  key_name   = "${var.account_name}-key"
  public_key = trimspace(file(var.aws_key_pair_public))
  tags = {
    Name = "${var.account_name}-key"
  }
}

resource "local_file" "ami_fck_nat_vars" {
  count = var.packer_build_ami ? 1 : 0

  filename = "${path.module}/packer/ec2-fck-nat/values.auto.pkrvars.hcl"
  content = <<-EOT
instance_type="${var.ec2_fck_nat_instance_type}"
region="${var.region}"
vpc_id="${data.aws_vpcs.vpc.ids[0]}"
subnet_id="${local.fck_nat[var.vpc_primary_az].subnet_id}"
ssh_custom_port="${var.fck_nat_ssh_custom_port}"
ssh_public_key="${trimspace(data.aws_key_pair.key.public_key)}"
eks_cluster_name="${var.eks_cluster_name}"
  EOT

  depends_on = [ module.vpc ]
}

resource "null_resource" "ami_fck_nat" {
  count = var.packer_build_ami ? 1 : 0

  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = "cd ${path.module}/packer/ec2-fck-nat && packer init . && AWS_SHARED_CREDENTIALS_FILE='${var.aws_shared_credentials_file}' packer build ."
  }

  depends_on = [local_file.ami_fck_nat_vars]
}
