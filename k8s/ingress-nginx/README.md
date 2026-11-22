# NGINX Ingress Controller

Valores del chart `ingress-nginx` para publicar el clúster de dev detrás de un NLB.

## Instalación

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  -f k8s/ingress-nginx/values.yaml
```

Requisito: el AWS Load Balancer Controller debe estar instalado, porque la anotación
`aws-load-balancer-type: external` delega la creación del NLB en él.

## Qué configura

- Servicio tipo `LoadBalancer` que crea un NLB de cara a internet.
- `nlb-target-type: ip`: el NLB apunta a las IP de los pods.
- `externalTrafficPolicy: Local`: conserva la IP de origen y evita un salto extra entre nodos.
- Balanceo entre zonas habilitado y réplicas repartidas por zona.
- Health check HTTP contra `/healthz` en el puerto 10254.

## Autoescalado y disponibilidad

- HorizontalPodAutoscaler del controlador: entre 2 y 6 réplicas, con objetivo de 70 % de CPU y 80 % de memoria sobre lo solicitado en `resources.requests`. Requiere metrics-server en el clúster.
- PodDisruptionBudget con `minAvailable: 1`: Karpenter y los drenajes de nodos nunca dejan el controlador sin réplicas.
- El mínimo de 2 réplicas, junto con la restricción de topología por zona, evita que un solo nodo sea punto único de falla.

Verificación:

```bash
kubectl -n ingress-nginx get hpa,pdb
```
