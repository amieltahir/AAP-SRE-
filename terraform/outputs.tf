output "vpc_id" {
  value = aws_vpc.aap_vpc.id
}

output "subnet_id" {
  value = aws_subnet.aap_subnet.id
}

output "controller01_ip" {
  value = aws_instance.instances["controller01"].public_ip
}

output "hub01_ip" {
  value = aws_instance.instances["hub01"].public_ip
}

output "exec01_ip" {
  value = aws_instance.instances["exec01"].public_ip
}

output "db01_ip" {
  value = aws_instance.instances["db01"].public_ip
}
