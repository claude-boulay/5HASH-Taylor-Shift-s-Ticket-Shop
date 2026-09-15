output "db_username" { value = "prestashop" }
output "db_name" { value = "prestashop" }
output "db_password" {
  value     = random_password.db.result
  sensitive = true
}
output "secret_name" { value = aws_secretsmanager_secret.db.name }
output "secret_arn" { value = aws_secretsmanager_secret.db.arn }
