output "controller01_ip" { value = aws_instance.controller01.public_ip }
output "hub01_ip"        { value = aws_instance.hub01.public_ip }
output "exec01_ip"       { value = aws_instance.exec01.public_ip }
output "db01_ip"         { value = aws_instance.db01.public_ip }
