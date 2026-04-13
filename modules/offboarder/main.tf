variable "username" {
  type = string
}

data "aws_lambda_invocation" "offboard_trigger" {
  function_name = "GlobalUserOffboarder"
  input = jsonencode({
    username = var.username
  })
}

output "execution_report" {
  value = jsondecode(data.aws_lambda_invocation.offboard_trigger.result)
}