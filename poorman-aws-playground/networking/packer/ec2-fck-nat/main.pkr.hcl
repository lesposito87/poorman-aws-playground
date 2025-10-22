packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "1.6.0"
    }
  }
}

source "amazon-ebs" "fck-nat" {
  ami_name              = "fck-nat"
  instance_type         = "${var.instance_type}"
  region                = "${var.region}"
  vpc_id                = "${var.vpc_id}"
  subnet_id             = "${var.subnet_id}"
  force_deregister      = "true"
  force_delete_snapshot = "true"
  ssh_interface         = "public_ip"
  source_ami_filter {
    filters = {
      name                = "fck-nat-al2023-*arm64*"
      state               = "available"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["568608671756"]
  }
  tags          = {
    Terraform = "true"
    Name      = "fck-nat"
  }
  ssh_username  = "ec2-user"
}

build {
  sources = ["source.amazon-ebs.fck-nat"]

  provisioner "shell" {
    script = "files/provisioner.sh"
    environment_vars = [
      "SSH_PUBLIC_KEY=${var.ssh_public_key}",
      "SSH_CUSTOM_PORT=${var.ssh_custom_port}",
      "HOSTNAME=fck-nat",
      "REGION=${var.region}",
      "EKS_CLUSTER_NAME=${var.eks_cluster_name}"
    ]
  }

  provisioner "shell" {
    inline = ["sudo mv /tmp/eks-kubeconfig-update.sh /root/eks-kubeconfig-update.sh"]
  }
}

