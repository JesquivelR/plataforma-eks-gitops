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

output "rol_karpenter_arn" {
  description = "Rol IRSA del controlador de Karpenter."
  value       = module.karpenter_irsa.rol_controlador_arn
}

output "rol_nodos_karpenter" {
  description = "Rol IAM de los nodos que aprovisiona Karpenter."
  value       = module.karpenter_irsa.rol_nodos_nombre
}

output "cola_interrupciones_karpenter" {
  description = "Cola SQS de interrupciones de Karpenter."
  value       = module.karpenter_irsa.cola_interrupciones
}

output "rol_external_secrets_arn" {
  description = "Rol IRSA de External Secrets Operator."
  value       = module.eso_irsa.rol_arn
}
