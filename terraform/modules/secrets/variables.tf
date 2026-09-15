variable "project" {
  description = "Préfixe de toutes les ressources du module."
  type        = string
}

variable "environment" {
  description = "Environnement déployé (dev, staging ou prod)."
  type        = string
}

variable "tags" {
  description = "Tags communs appliqués à toutes les ressources du module."
  type        = map(string)
}
