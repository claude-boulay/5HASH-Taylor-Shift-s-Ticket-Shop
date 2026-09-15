variable "project" {
  description = "Préfixe de toutes les ressources du module."
  type        = string
}

variable "environment" {
  description = "Environnement déployé (dev, staging ou prod)."
  type        = string
}

variable "db_subnet_group_name" {
  description = "Groupe de sous-réseaux (privés) dans lequel placer l'instance RDS."
  type        = string
}

variable "security_group_id" {
  description = "Security group autorisé à joindre la base (celui des instances applicatives)."
  type        = string
}

variable "db_username" {
  description = "Nom d'utilisateur de la base."
  type        = string
}

variable "db_password" {
  description = "Mot de passe de la base, généré par le module secrets."
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "Nom de la base de données créée sur l'instance."
  type        = string
}

variable "instance_class" {
  description = "Classe de l'instance RDS (ex. db.t3.micro)."
  type        = string
}

variable "multi_az" {
  description = "Active la haute disponibilité RDS (Multi-AZ)."
  type        = bool
}

variable "tags" {
  description = "Tags communs appliqués à toutes les ressources du module."
  type        = map(string)
}
