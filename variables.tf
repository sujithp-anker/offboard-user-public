variable "Users_To_Offboard" {
  type        = string
  description = "Enter usernames separated by commas (e.g., user1@company.com, user2@company.com)"
  default     = ""
}

variable "Region" {
  type    = string
  default = "us-east-1"
}