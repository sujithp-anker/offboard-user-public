variable "username" {
  type = string
}

resource "terraform_data" "offboard_trigger" {
  input = var.username

  provisioner "local-exec" {
    when    = create
    command = "pip install boto3 --target /tmp/lib && PYTHONPATH=/tmp/lib python3 ${path.module}/scripts/cleanup.py ${var.username}"
  }
}