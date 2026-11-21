# Plataforma EKS con GitOps

Plataforma en Amazon EKS con Terraform, Karpenter, NGINX Ingress, External Secrets Operator y Argo CD. Este repositorio se construye por partes; esta primera parte cubre la red, el clúster y los roles de identidad que necesitarán los componentes siguientes.

## Alcance de la parte 1

- Estructura de Terraform con módulos reutilizables y un entorno `dev`.
- VPC con subredes públicas y privadas en tres zonas de disponibilidad.
- Clúster EKS con un node group mínimo para el sistema y cifrado de secretos con KMS.
- Roles IRSA para Karpenter y External Secrets Operator.
- CI de validación sin credenciales de AWS.

## Arquitectura

```
                     Internet
                        |
                 Internet Gateway
                        |
   +--------------- VPC 10.0.0.0/16 ----------------+
   |                                                |
   |  Subredes públicas (3 zonas)                   |
   |    - balanceadores (etiquetas para ELB)        |
   |    - NAT Gateway (una sola en dev)             |
   |                       |                        |
   |  Subredes privadas (3 zonas)                   |
   |    - plano de datos de EKS                     |
   |    - node group del sistema (t3.medium)        |
   +------------------------------------------------+

   EKS (plano de control administrado)
     - secretos cifrados con una llave KMS
     - proveedor OIDC para IRSA
         |-- rol del controlador de Karpenter (+ cola SQS y reglas de EventBridge)
         |-- rol de External Secrets Operator (lectura de Secrets Manager por prefijo)
```

## Estructura

```
terraform/
  modulos/
    vpc/             red con subredes públicas y privadas por zona
    eks/             clúster, node group del sistema, OIDC y KMS
    karpenter-irsa/  rol del controlador, rol de nodos, access entry, SQS y EventBridge
    eso-irsa/        rol de External Secrets Operator acotado por prefijo
  entornos/
    dev/             composición de los módulos para desarrollo
```

## Requisitos

- Terraform 1.10 o superior (el backend usa `use_lockfile`).
- Una cuenta de AWS y credenciales con permisos para crear VPC, EKS, IAM, KMS y SQS.
- Un bucket de S3 para el estado remoto.

## Despliegue

```bash
cd terraform/entornos/dev
terraform init \
  -backend-config="bucket=<bucket-de-estado>" \
  -backend-config="region=us-east-1"
terraform plan -out=plan.tfplan
terraform apply plan.tfplan
```

El estado usa bloqueo nativo de S3, así que no hace falta una tabla de DynamoDB. Para actualizar el kubeconfig después del despliegue:

```bash
aws eks update-kubeconfig --name eks-gitops-dev-cluster --region us-east-1
```

Para destruir el entorno: `terraform destroy` en el mismo directorio.

## Validación en CI

El workflow `ci-terraform.yml` corre en cada cambio de `terraform/` y no necesita credenciales de AWS:

- `terraform fmt -check -recursive`
- `terraform init -backend=false` y `terraform validate` sobre el entorno `dev`
- `tflint` con descarga recursiva de los módulos
- Checkov sobre todo el directorio `terraform/`

Las acciones están fijadas por SHA.

## Omisiones de Checkov

Ninguna se aplica con `soft_fail` global; cada una está en el código con su motivo.

| Regla | Dónde | Motivo |
|-------|-------|--------|
| CKV_AWS_394 | `entornos/dev/main.tf` | El entorno toma solo las tres primeras zonas con `slice`, así que el resultado no crece si AWS agrega una zona. |
| CKV_AWS_158 | `modulos/eks/main.tf` | Los registros del plano de control de dev usan el cifrado por defecto de CloudWatch; una llave propia encarece el laboratorio sin cambiar el diseño. |
| CKV_AWS_158 | `modulos/vpc/main.tf` | Los registros de flujo de dev usan el cifrado por defecto de CloudWatch. |
| CKV2_AWS_64 | `modulos/eks/main.tf` | La llave KMS usa la política por defecto, que delega el acceso en IAM de la cuenta. |

## Costos aproximados

Estimación de referencia en us-east-1, con el entorno `dev` encendido todo el mes (precios de lista, pueden variar):

| Recurso | Aproximado mensual |
|---------|--------------------|
| Plano de control de EKS | 73 USD |
| NAT Gateway (una) | 33 USD más el tráfico procesado |
| Nodos del sistema (t3.medium, según `nodos_sistema`) | 30 USD por nodo |
| Llave KMS, SQS y registros de CloudWatch | pocos USD |

El total ronda los 140 a 180 USD al mes con un par de nodos. Para un laboratorio conviene aplicar, probar y ejecutar `terraform destroy` al terminar: un día encendido cuesta alrededor de 5 USD.

## Siguientes partes

La instalación de Karpenter, el ingress, Argo CD y External Secrets Operator se agregan en PRs posteriores sobre esta base.
