<<<<<<< HEAD
output "vpc_id" {
  description = "ID da VPC"
  value       = aws_vpc.poc.id
}

output "public_subnet_ids" {
  description = "IDs das subnets públicas"
  value       = aws_subnet.subnet_publica[*].id
}

output "private_subnet_ids" {
  description = "IDs das subnets privadas"
  value       = aws_subnet.subnet_privada[*].id
}
=======
# output "vpc_id" {
#   description = "ID da VPC"
#   value       = aws_vpc.poc.id
# }

# output "public_subnet_ids" {
#   description = "IDs das subnets públicas"
#   value       = aws_subnet.subnet_publica[*].id
# }

# output "private_subnet_ids" {
#   description = "IDs das subnets privadas"
#   value       = aws_subnet.subnet_privada[*].id
# }
>>>>>>> develop

output "IP_Python_app" {
    description = "IP Publico da instancia Python_app"
    value       = aws_eip.app_python_ip_fixo.public_ip
}

output "elastic_beanstalk_endpoint" {
  value = aws_elastic_beanstalk_environment.env.endpoint_url
}

# output "api_gateway_endpoint" {
#   value = aws_api_gateway_deployment.deployment.invoke_url
# }