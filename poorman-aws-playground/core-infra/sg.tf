data "http" "home_ip" {
  url = "https://ifconfig.me/ip"
}

locals {
  home_ip = trimspace(data.http.home_ip.response_body)
}

resource "aws_security_group" "allow_all" {
  name        = "${var.account_name}-allow-all"
  description = "Allow All inbound traffic from VPC, specific traffic from Home IP and All outbound traffic"
  vpc_id      = data.aws_vpcs.vpc.ids[0]
  tags = {
    Name = "${var.account_name}-allow-all"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh_home" {
  security_group_id = aws_security_group.allow_all.id
  cidr_ipv4         = "${local.home_ip}/32"
  from_port         = var.fck_nat_ssh_custom_port
  to_port           = var.fck_nat_ssh_custom_port
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "allow_vpn_tcp_home" {
  security_group_id = aws_security_group.allow_all.id
  cidr_ipv4         = "${local.home_ip}/32"
  from_port         = "1194"
  to_port           = "1194"
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "allow_vpn_udp_home" {
  security_group_id = aws_security_group.allow_all.id
  cidr_ipv4         = "${local.home_ip}/32"
  from_port         = "1194"
  to_port           = "1194"
  ip_protocol       = "udp"
}

resource "aws_vpc_security_group_ingress_rule" "allow_all_vpc" {
  security_group_id = aws_security_group.allow_all.id
  cidr_ipv4         = var.vpc_cidr
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "allow_all" {
  security_group_id = aws_security_group.allow_all.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
