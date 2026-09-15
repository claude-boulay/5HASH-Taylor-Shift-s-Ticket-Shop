variable "project" {
  description = "Préfixe de toutes les ressources du module."
  type        = string
}

variable "environment" {
  description = "Environnement déployé (dev, staging ou prod)."
  type        = string
}

variable "vpc_id" {
  description = "VPC dans lequel créer les security groups."
  type        = string
}

variable "admin_cidr" {
  description = "Bloc CIDR autorisé en SSH sur les instances applicatives."
  type        = string
}

variable "tags" {
  description = "Tags communs appliqués à toutes les ressources du module."
  type        = map(string)
}
