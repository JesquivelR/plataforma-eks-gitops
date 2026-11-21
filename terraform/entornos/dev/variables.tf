variable "region" {
  description = "Región de AWS donde se despliega el entorno."
  type        = string
  default     = "us-east-1"
}

variable "nombre" {
  description = "Prefijo para nombrar los recursos del entorno."
  type        = string
  default     = "eks-gitops-dev"
}

variable "etiquetas" {
  description = "Etiquetas comunes que se aplican a todos los recursos."
  type        = map(string)
  default = {
    proyecto = "plataforma-eks-gitops"
    entorno  = "dev"
    gestion  = "terraform"
  }
}

variable "cidr_vpc" {
  description = "Bloque CIDR de la VPC del entorno."
  type        = string
  default     = "10.0.0.0/16"
}
