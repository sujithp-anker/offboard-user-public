provider "aws" {
  region = var.Region
}

locals {
  user_list = var.Users_To_Offboard == "" ? [] : [
    for u in split(",", Users_To_Offboard) : trimspace(u)
  ]
}

module "offboarder" {
  source   = "./modules/offboarder"
  for_each = toset(local.user_list)

  username = each.value
}