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

output "nombre_cluster" {
  description = "Nombre del clúster EKS."
  value       = module.eks.nombre_cluster
}

output "oidc_provider_arn" {
  description = "ARN del proveedor OIDC del clúster, base de los roles IRSA."
  value       = module.eks.oidc_provider_arn
}
