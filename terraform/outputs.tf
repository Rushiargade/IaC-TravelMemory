output "web_public_ip" {
  description = "Public IP address of the Web Server"
  value       = aws_instance.web.public_ip
}

output "db_private_ip" {
  description = "Private IP address of the Database Server"
  value       = aws_instance.db.private_ip
}

output "ssh_command_web" {
  description = "SSH Command to access the Web Server"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${aws_instance.web.public_ip}"
}
