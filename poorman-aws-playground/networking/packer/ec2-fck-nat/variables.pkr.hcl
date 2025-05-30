variable "instance_type" {
  type    = string
}

variable "region" {
  type    = string
}

variable "vpc_id" {
  type    = string
}

variable "subnet_id" {
  type    = string
}

variable "ssh_public_key" {
  type    = string
}

variable "ssh_custom_port" {
  type    = string
}

variable "eks_cluster_name" {
  type    = string
}
