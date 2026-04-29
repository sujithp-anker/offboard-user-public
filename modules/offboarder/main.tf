resource "terraform_data" "offboard_trigger" {
  input = var.username

  provisioner "local-exec" {
    command = "echo 'Triggering offboarding for ${var.username}'"
  }
}

data "aws_lambda_invocation" "offboard_trigger" {
  depends_on    = [terraform_data.offboard_trigger]
  function_name = "GlobalUserOffboarder"
  input = jsonencode({
    username = var.username
  })
}