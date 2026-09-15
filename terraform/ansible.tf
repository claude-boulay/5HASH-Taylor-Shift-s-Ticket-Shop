resource "ansible_host" "app" {
  for_each = module.compute.instance_ids

  name   = each.key
  groups = ["webservers"]

  variables = {
    floci_instance               = each.value
    ansible_user                 = "root"
    ansible_ssh_private_key_file = ".keys/taylor-shift"

    db_resource_id = module.database.resource_id
  }
}

resource "ansible_group" "webservers" {
  name = "webservers"

  variables = {
    app_environment  = var.environment
    db_name          = module.secrets.db_name
    db_secret_name   = module.secrets.secret_name
    prestashop_title = "Taylor Shift's Ticket Shop"

    alb_target_group_arn = module.compute.target_group_arn
  }
}
