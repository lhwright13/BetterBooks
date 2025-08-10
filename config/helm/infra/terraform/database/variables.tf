variable "identifier" {}
variable "username" {}
variable "password" {
  sensitive = true
}
variable "instance_class" {}
variable "subnet_ids" {
  type = list(string)
}
variable "vpc_security_group_ids" {
  type = list(string)
}
