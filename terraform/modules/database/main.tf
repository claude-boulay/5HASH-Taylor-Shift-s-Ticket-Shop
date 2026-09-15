resource "aws_db_instance" "this" {
  identifier     = "${var.project}-${var.environment}-db"
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = var.instance_class

  allocated_storage      = 20
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = [var.security_group_id]

  multi_az            = var.multi_az
  publicly_accessible = false
  skip_final_snapshot = true

  backup_retention_period = var.environment == "prod" ? 7 : 1

  tags = var.tags
}
