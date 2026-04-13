output "final_offboarding_status" {
  description = "Detailed report of user deletions across all accounts"
  
  value = {
    for user, mod in module.offboarder : user => mod.execution_report
  }
}