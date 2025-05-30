resource "aws_route53_zone" "route53_private_zone" {
  name = var.route53_private_zone

  vpc {
    vpc_id     = data.aws_vpcs.vpc.ids[0]
    vpc_region = var.region
  }

  tags = {
    Name = var.route53_private_zone
  }
}
