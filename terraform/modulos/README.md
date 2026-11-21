# Módulos de Terraform

Cada carpeta de este directorio es un módulo reutilizable que se consume desde los entornos en `terraform/entornos/`.

| Módulo | Contenido | Estado |
|--------|-----------|--------|
| `vpc` | VPC con subredes públicas y privadas por zona de disponibilidad | Disponible |
| `eks` | Clúster EKS, node group del sistema, proveedor OIDC y cifrado de secretos con KMS | Disponible |

Convenciones: cada módulo tiene `main.tf`, `variables.tf`, `outputs.tf` y `versions.tf`, y no declara el bloque `provider`.
