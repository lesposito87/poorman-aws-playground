output "nginx_ingress_controller_fqdn" {
  value = aws_route53_record.nginx_ingress_controller.fqdn
}
