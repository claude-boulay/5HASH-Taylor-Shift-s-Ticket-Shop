variable "project" {
  description = "Préfixe de toutes les ressources du module."
  type        = string
}

variable "environment" {
  description = "Environnement déployé (dev, staging ou prod)."
  type        = string
}

variable "vpc_id" {
  description = "VPC dans lequel créer le groupe de cibles de l'ALB."
  type        = string
}

variable "public_subnet_ids" {
  description = "Sous-réseaux publics où placer l'ALB et les instances applicatives."
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group des instances applicatives."
  type        = string
}

variable "alb_security_group_id" {
  description = "Security group de l'ALB."
  type        = string
}

variable "instance_count" {
  description = "Nombre d'instances applicatives à créer."
  type        = number
}

variable "instance_type" {
  description = "Type des instances applicatives (ex. t3.micro)."
  type        = string
}

variable "ami" {
  description = "Identifiant de l'image utilisée pour les instances."
  type        = string
}

variable "public_key_path" {
  description = "Chemin vers la clé publique SSH à déposer sur les instances."
  type        = string
}

variable "tags" {
  description = "Tags communs appliqués à toutes les ressources du module."
  type        = map(string)
}
