output "vpc_id" {
  description = "Identificador de la VPC."
  value       = aws_vpc.this.id
}

output "cidr_vpc" {
  description = "Bloque CIDR de la VPC."
  value       = aws_vpc.this.cidr_block
}

output "subredes_publicas" {
  description = "Identificadores de las subredes públicas, en el orden de las zonas."
  value       = [for z in var.zonas : aws_subnet.publica[z].id]
}

output "subredes_privadas" {
  description = "Identificadores de las subredes privadas, en el orden de las zonas."
  value       = [for z in var.zonas : aws_subnet.privada[z].id]
}
