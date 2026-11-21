variable "nombre_cluster" {
  description = "Nombre del clúster EKS donde corre Karpenter."
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
  description = "Namespace donde se instala Karpenter."
  type        = string
  default     = "karpenter"
}

variable "service_account" {
  description = "Nombre de la ServiceAccount del controlador de Karpenter."
  type        = string
  default     = "karpenter"
}

variable "etiquetas" {
  description = "Etiquetas adicionales para los recursos del módulo."
  type        = map(string)
  default     = {}
}
