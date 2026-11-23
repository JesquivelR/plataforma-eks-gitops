# External Secrets Operator

Sincroniza secretos de AWS Secrets Manager hacia `Secret` de Kubernetes sin guardar valores en Git.

## Piezas

- `apps/external-secrets.yaml` (en `k8s/argocd/`): instala el chart del operador con la cuenta de servicio anotada con el rol IRSA.
- `clustersecretstore.yaml`: `ClusterSecretStore` llamado `aws-secrets-manager` que usa la API `external-secrets.io/v1`.

## Autenticación

El store usa `auth.jwt.serviceAccountRef`, es decir, el token proyectado de la cuenta de servicio `external-secrets` del namespace `external-secrets`. El rol IAM que asume viene del módulo `terraform/modulos/eso-irsa`, que limita la lectura a los secretos con un prefijo concreto. No hay llaves de acceso en el repositorio.

## Cómo probarlo

1. Despliega el entorno `dev` de Terraform y copia el ARN del rol en `<ARN_ROL_ESO>` de la aplicación de Argo CD.
2. Aplica `clustersecretstore.yaml` (o deja que Argo CD lo sincronice).
3. Verifica que el store quede válido:

   ```bash
   kubectl get clustersecretstore aws-secrets-manager
   ```

   La columna `READY` debe mostrar `True`.

## Región

La región `us-east-1` es un ejemplo; cámbiala para que coincida con la del clúster y la de los secretos.
