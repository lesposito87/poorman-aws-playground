locals {
  k3s = {
    k3s_deploy = var.eks_deploy == false

    aza = {
      name           = "k3s-aza"
      subnet_id      = data.aws_subnets.private_subnets_aza.ids[0]
    }
    azb = {
      name           = "k3s-azb"
      subnet_id      = data.aws_subnets.private_subnets_azb.ids[0]
    }
    azc = {
      name           = "k3s-azc"
      subnet_id      = data.aws_subnets.private_subnets_azc.ids[0]
    }
  }
}

# Fetch the latest Amazon Linux 2023 AMI for ARM64
data "aws_ami" "k3s" {
  count       = local.k3s.k3s_deploy ? 1 : 0
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-kernel-*-arm64"]
  }
}

resource "aws_iam_role" "k3s" {
  count = local.k3s.k3s_deploy ? 1 : 0

  name = "k3s"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_instance_profile" "k3s" {
  count = local.k3s.k3s_deploy ? 1 : 0

  name = "k3s"
  role = aws_iam_role.k3s[0].name
}

resource "aws_instance" "k3s" {
  count   = local.k3s.k3s_deploy ? 1 : 0

  ami                    = data.aws_ami.k3s[count.index].id
  instance_type          = var.ec2_k3s_instance_type
  vpc_security_group_ids = [aws_security_group.allow_all.id]
  subnet_id              = local.k3s[var.vpc_primary_az].subnet_id
  key_name               = data.terraform_remote_state.networking.outputs.aws_key_pair_name
  iam_instance_profile   = aws_iam_instance_profile.k3s[0].name

  root_block_device {
    volume_size = 50
    volume_type = "gp3"
  }

  tags = {
    Name = local.k3s[var.vpc_primary_az].name
  }

  depends_on = [ null_resource.ansible_playbook ]
}

resource "null_resource" "k3s_ansible_playbook" {
  count = local.k3s.k3s_deploy ? 1 : 0

  triggers = {
    k3s_instance_arn = aws_instance.k3s[count.index].arn
    k3s_private_ip   = aws_instance.k3s[count.index].private_ip
    sadf = "saddsf"
  }

  provisioner "local-exec" {
    command = <<EOT
  while ! nc -zv "${aws_instance.k3s[count.index].private_ip}" 22; do
    echo "Waiting for ${aws_instance.k3s[count.index].private_ip}:22 to be reachable..."
    echo "Connection to the VPN is required! Please connect if you haven't done so already!"
    sleep 5
  done

  cd ansible/playbooks/k3s && ansible-galaxy install -r requirements.yml --force && ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i "${aws_instance.k3s[count.index].private_ip}," \
    --ssh-extra-args "-o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedKeyTypes=+ssh-rsa -i ${var.aws_key_pair_private}" \
    --user ec2-user \
    --become \
    --become-method sudo \
    --become-user root \
    --extra-vars "{\"ansible_host_key_checking\": false, \"ansible_retry_files_enabled\": false, \"k3s_reconfigure\": false, \"k3s_kubeconfig_local_path\": \"${var.kubeconfig_local_file}\", \"k3s_kubeconfig_server\": \"${aws_instance.k3s[count.index].private_ip}\", \"k3s_insecure_registries\": [\"harbor.${var.route53_private_zone}:${var.k8s_nginx_http_host_port}\"]}" \
    main.yml
EOT
  }
}
