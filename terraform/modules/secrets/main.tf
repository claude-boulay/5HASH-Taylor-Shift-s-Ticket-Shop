resource "random_password" "db" {
  length  = 20
  special = false
}

resource "aws_secretsmanager_secret" "db" {
  name                    = "${var.project}/${var.environment}/db-credentials"
  description             = "Identifiants de la base PrestaShop"
  recovery_window_in_days = 0
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = "prestashop"
    password = random_password.db.result
    dbname   = "prestashop"
  })
}
