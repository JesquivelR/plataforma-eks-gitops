variable "nombre" {
  description = "Prefijo para nombrar los recursos de red."
  type        = string
}

variable "cidr_vpc" {
  description = "Bloque CIDR de la VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "zonas" {
  description = "Zonas de disponibilidad donde se crea una subred pública y una privada."
  type        = list(string)

  validation {
    condition     = length(var.zonas) >= 2
    error_message = "Se necesitan al menos dos zonas de disponibilidad."
  }
}

variable "nat_unica" {
  description = "Si es true se crea una sola NAT gateway (más barato, apto para dev); si es false, una por zona."
  type        = bool
  default     = true
}

variable "nombre_cluster" {
  description = "Nombre del clúster EKS; se usa en las etiquetas que descubren las subredes."
  type        = string
}

variable "etiquetas" {
  description = "Etiquetas adicionales para los recursos del módulo."
  type        = map(string)
  default     = {}
}

variable "retencion_logs_dias" {
  description = "Días de retención de los registros de flujo en CloudWatch Logs."
  type        = number
  default     = 365
}
