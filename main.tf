locals {
  user_list = var.Users_To_Offboard == "" ? [] : [
    for u in split(",", var.Users_To_Offboard) : trimspace(u)
  ]
}

module "offboarder" {
  source   = "./modules/offboarder"
  for_each = toset(local.user_list) 
  username = each.value
}

output "offboarding_results" {
  value = {
    for u, mod in module.offboarder : u => mod.execution_report
  }
}