variable "username" {
  type = string
}

resource "terraform_data" "offboard_trigger" {
  input = var.username

  provisioner "local-exec" {
    when    = create
    command = "sh ${path.module}/scripts/cleanup.sh ${var.username}"
  }
}