resource "aws_db_instance" "this" {
  identifier        = var.identifier
  engine            = "postgres"
  instance_class    = var.instance_class
  allocated_storage = 20
  db_subnet_group_name = aws_db_subnet_group.db.name
  username          = var.username
  password          = var.password
  vpc_security_group_ids = var.vpc_security_group_ids
  skip_final_snapshot = true
}

resource "aws_db_subnet_group" "db" {
  name       = "${var.identifier}-subnets"
  subnet_ids = var.subnet_ids
}

output "endpoint" {
  value = aws_db_instance.this.endpoint
}
