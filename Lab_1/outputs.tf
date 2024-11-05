# Terraform output
output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "The ID of the public subnet"
  value       = aws_subnet.public.id
}

output "private_subnet_id" {
  description = "The ID of the private subnet"
  value       = aws_subnet.private.id
}

output "public_ec2_id" {
  description = "The ID of the public subnet"
  value       = aws_instance.public_instance.id
}

output "private_ec2_id" {
  description = "The ID of the private subnet"
  value       = aws_instance.private_instance.id
}