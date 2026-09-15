resource "aws_security_group" "alb" {
  name        = "${var.project}-${var.environment}-alb"
  description = "Entrée publique HTTP"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.project}-${var.environment}-alb" })
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP public"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_all" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "app" {
  name        = "${var.project}-${var.environment}-app"
  description = "Instances applicatives : HTTP depuis l'ALB, SSH depuis l'admin"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.project}-${var.environment}-app" })
}

resource "aws_vpc_security_group_ingress_rule" "app_http_from_alb" {
  security_group_id            = aws_security_group.app.id
  description                  = "HTTP depuis l'ALB uniquement"
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "app_ssh" {
  security_group_id = aws_security_group.app.id
  description       = "SSH, pour Ansible"
  cidr_ipv4         = var.admin_cidr
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "app_all" {
  security_group_id = aws_security_group.app.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "database" {
  name        = "${var.project}-${var.environment}-database"
  description = "RDS : accessible uniquement depuis les instances applicatives"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.project}-${var.environment}-database" })
}

resource "aws_vpc_security_group_ingress_rule" "database_from_app" {
  security_group_id            = aws_security_group.database.id
  description                  = "MySQL depuis les instances applicatives uniquement"
  referenced_security_group_id = aws_security_group.app.id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
}
