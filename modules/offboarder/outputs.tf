output "execution_report" {
  description = "The JSON response from the Lambda"
  value = jsondecode(data.aws_lambda_invocation.offboard_trigger.result)
}