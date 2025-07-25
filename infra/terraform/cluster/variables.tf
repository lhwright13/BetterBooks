variable "cluster_name" {}
variable "cluster_role_arn" {}
variable "node_role_arn" {}
variable "subnet_ids" {
  type = list(string)
}
