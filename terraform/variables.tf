variable "project" {
  description = "Préfixe de toutes les ressources."
  type        = string
  default     = "taylor-shift"
}

variable "environment" {
  description = "Environnement déployé : dev, staging ou prod."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "L'environnement doit valoir dev, staging ou prod."
  }
}

variable "aws_region" {
  description = "Région AWS simulée par Floci."
  type        = string
  default     = "us-east-1"
}

variable "floci_endpoint" {
  description = "Adresse de Floci, vue depuis ce poste."
  type        = string
  default     = "http://localhost.floci.io:4566"
}

variable "vpc_cidr" {
  description = "Bloc CIDR du VPC."
  type        = string
  default     = "10.80.0.0/16"
}

variable "admin_cidr" {
  description = "Bloc CIDR autorisé en SSH sur les instances. Restreignez-le à votre IP avant de rendre le projet."
  type        = string
  default     = "0.0.0.0/0"
}

variable "instance_count" {
  description = "Nombre d'instances applicatives. Taille fixe assumée — voir README, section Trafic."
  type        = number
  default     = 2
}

variable "instance_type" {
  description = "Type des instances applicatives."
  type        = string
  default     = "t3.micro"
}

variable "db_instance_class" {
  description = "Classe de l'instance RDS."
  type        = string
  default     = "db.t3.micro"
}

variable "db_multi_az" {
  description = "Haute disponibilité RDS (coûte plus cher : réservé à prod)."
  type        = bool
  default     = false
}
