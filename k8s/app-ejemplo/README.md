# Aplicación de ejemplo con Ingress

Aplicación web mínima (NGINX sin privilegios) para comprobar que el controlador de ingress enruta tráfico hacia un servicio del clúster.

## Contenido

- `namespace.yaml`: namespace `demo` con Pod Security `restricted`.
- `deployment.yaml`: 2 réplicas repartidas por zona, sin root, sistema de archivos de solo lectura y sin capacidades extra.
- `service.yaml`: Service `ClusterIP` en el puerto 80.
- `externalsecret.yaml`: `ExternalSecret` que lee `eks-gitops-dev/app-demo` de Secrets Manager (por medio de `aws-secrets-manager`) y crea el Secret `app-demo-config`.
- `ingress.yaml`: regla para `demo.ejemplo.com` con `ingressClassName: nginx`.

## Despliegue

```bash
kubectl apply -f k8s/app-ejemplo/
kubectl -n demo rollout status deployment/app-demo
```

## Secreto desde Secrets Manager

El Deployment lee la variable `API_TOKEN` del Secret `app-demo-config`, que crea External Secrets Operator a partir de `externalsecret.yaml`. El valor nunca está en Git. Requisitos:

1. Tener aplicado el `ClusterSecretStore` de `k8s/external-secrets/`.
2. Crear en Secrets Manager un secreto llamado `eks-gitops-dev/app-demo` con un JSON como `{"api_token": "valor-de-prueba"}`. El nombre debe empezar con el prefijo que permite el módulo `eso-irsa`.
3. Comprobar la sincronización:

   ```bash
   kubectl -n demo get externalsecret app-demo
   kubectl -n demo get secret app-demo-config
   ```

   El `ExternalSecret` debe mostrar `SecretSynced`. Hasta que el Secret exista, los pods quedan en `CreateContainerConfigError`.

## Prueba

Obtén el nombre DNS del NLB y llama a la aplicación con el encabezado `Host`:

```bash
NLB=$(kubectl -n ingress-nginx get svc ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl -i -H "Host: demo.ejemplo.com" "http://$NLB/"
```

Se espera `HTTP/1.1 200 OK` con la página de bienvenida de NGINX.

## Limpieza

```bash
kubectl delete -f k8s/app-ejemplo/
```
