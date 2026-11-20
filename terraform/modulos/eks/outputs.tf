output "nombre_cluster" {
  description = "Nombre del clúster EKS."
  value       = aws_eks_cluster.this.name
}

output "endpoint" {
  description = "Endpoint de la API de Kubernetes."
  value       = aws_eks_cluster.this.endpoint
}

output "oidc_issuer" {
  description = "URL del emisor OIDC del clúster."
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "oidc_provider_arn" {
  description = "ARN del proveedor OIDC para los roles IRSA."
  value       = aws_iam_openid_connect_provider.cluster.arn
}

output "kms_secretos_arn" {
  description = "ARN de la llave de KMS que cifra los secretos del clúster."
  value       = aws_kms_key.secretos.arn
}

output "rol_nodos_arn" {
  description = "ARN del rol IAM de los nodos del sistema."
  value       = aws_iam_role.nodos.arn
}
