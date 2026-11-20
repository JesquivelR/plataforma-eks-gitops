variable "nombre_cluster" {
  description = "Nombre del clúster EKS."
  type        = string
}

variable "version_kubernetes" {
  description = "Versión de Kubernetes del plano de control."
  type        = string
  default     = "1.31"
}

variable "vpc_id" {
  description = "Identificador de la VPC donde se crea el clúster."
  type        = string
}

variable "subredes_privadas" {
  description = "Subredes privadas para el plano de control y los nodos."
  type        = list(string)
}

variable "cidrs_acceso_api" {
  description = "CIDRs que pueden llegar al endpoint público de la API. Con lista vacía solo se usa el endpoint privado."
  type        = list(string)
  default     = []
}

variable "tipos_instancia_sistema" {
  description = "Tipos de instancia del node group del sistema."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "nodos_sistema" {
  description = "Tamaño mínimo, deseado y máximo del node group del sistema."
  type = object({
    minimo  = number
    deseado = number
    maximo  = number
  })
  default = {
    minimo  = 2
    deseado = 2
    maximo  = 3
  }
}

variable "retencion_logs_dias" {
  description = "Días de retención de los logs del plano de control."
  type        = number
  default     = 365
}

variable "etiquetas" {
  description = "Etiquetas adicionales para los recursos del módulo."
  type        = map(string)
  default     = {}
}
