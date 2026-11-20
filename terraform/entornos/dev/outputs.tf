output "region" {
  description = "Región del entorno."
  value       = var.region
}

output "vpc_id" {
  description = "Identificador de la VPC."
  value       = module.vpc.vpc_id
}

output "subredes_privadas" {
  description = "Subredes privadas donde correrán los nodos."
  value       = module.vpc.subredes_privadas
}

output "subredes_publicas" {
  description = "Subredes públicas para los balanceadores."
  value       = module.vpc.subredes_publicas
}
