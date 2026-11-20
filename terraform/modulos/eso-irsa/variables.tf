variable "nombre_cluster" {
  description = "Nombre del clúster EKS donde corre External Secrets Operator."
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN del proveedor OIDC del clúster."
  type        = string
}

variable "oidc_issuer" {
  description = "URL del emisor OIDC del clúster (con https://)."
  type        = string
}

variable "namespace" {
  description = "Namespace donde se instala External Secrets Operator."
  type        = string
  default     = "external-secrets"
}

variable "service_account" {
  description = "Nombre de la ServiceAccount del operador."
  type        = string
  default     = "external-secrets"
}

variable "prefijo_secretos" {
  description = "Prefijo de los nombres de secretos en Secrets Manager que el operador puede leer."
  type        = string
  default     = "eks-gitops-dev/"
}

variable "etiquetas" {
  description = "Etiquetas adicionales para los recursos del módulo."
  type        = map(string)
  default     = {}
}
