locals {
  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

module "network" {
  source      = "./modules/network"
  project     = var.project
  environment = var.environment
  vpc_cidr    = var.vpc_cidr
  tags        = local.tags
}

module "security" {
  source      = "./modules/security"
  project     = var.project
  environment = var.environment
  vpc_id      = module.network.vpc_id
  admin_cidr  = var.admin_cidr
  tags        = local.tags
}

module "secrets" {
  source      = "./modules/secrets"
  project     = var.project
  environment = var.environment
  tags        = local.tags
}

module "database" {
  source               = "./modules/database"
  project              = var.project
  environment          = var.environment
  db_subnet_group_name = module.network.db_subnet_group_name
  security_group_id    = module.security.database_security_group_id
  db_username          = module.secrets.db_username
  db_password          = module.secrets.db_password
  db_name              = module.secrets.db_name
  instance_class       = var.db_instance_class
  multi_az             = var.db_multi_az
  tags                 = local.tags
}

module "compute" {
  source                = "./modules/compute"
  project               = var.project
  environment           = var.environment
  vpc_id                = module.network.vpc_id
  public_subnet_ids     = module.network.public_subnet_ids
  security_group_id     = module.security.app_security_group_id
  alb_security_group_id = module.security.alb_security_group_id
  instance_count        = var.instance_count
  instance_type         = var.instance_type
  ami                   = "ami-debian12"
  public_key_path       = "${path.module}/../.keys/taylor-shift.pub"
  tags                  = local.tags
}
