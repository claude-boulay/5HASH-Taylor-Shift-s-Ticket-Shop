output "app_url" {
  description = "Adresse publique de la boutique."
  value       = "http://${module.compute.alb_dns_name}"
}

output "instance_ids" { value = module.compute.instance_ids }
output "db_secret_name" { value = module.secrets.secret_name }
output "db_resource_id" { value = module.database.resource_id }
