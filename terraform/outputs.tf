output "controller01_ip" {
  description = "Public IP of controller01"
  value       = aws_instance.controller01.public_ip
}

output "hub01_ip" {
  description = "Public IP of hub01"
  value       = aws_instance.hub01.public_ip
}

output "exec01_ip" {
  description = "Public IP of exec01"
  value       = aws_instance.exec01.public_ip
}

output "db01_ip" {
  description = "Public IP of db01"
  value       = aws_instance.db01.public_ip
}
