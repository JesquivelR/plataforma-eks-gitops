# Aplicación de ejemplo con Ingress

Aplicación web mínima (NGINX sin privilegios) para comprobar que el controlador de ingress enruta tráfico hacia un servicio del clúster.

## Contenido

- `namespace.yaml`: namespace `demo` con Pod Security `restricted`.
- `deployment.yaml`: 2 réplicas repartidas por zona, sin root, sistema de archivos de solo lectura y sin capacidades extra.
- `service.yaml`: Service `ClusterIP` en el puerto 80.
- `ingress.yaml`: regla para `demo.ejemplo.com` con `ingressClassName: nginx`.

## Despliegue

```bash
kubectl apply -f k8s/app-ejemplo/
kubectl -n demo rollout status deployment/app-demo
```

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
