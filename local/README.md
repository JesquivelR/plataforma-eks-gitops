# Entorno local con kind

Reproduce la plataforma en una sola máquina: un clúster kind, NGINX Ingress, Argo CD y la aplicación de ejemplo. Reutiliza los mismos values de `k8s/` con pequeños ajustes para un solo nodo.

## Qué incluye

| Archivo | Para qué sirve |
|---------|----------------|
| `levantar.sh` | Crea el clúster, instala los charts y aplica la aplicación de ejemplo. También borra el clúster. |
| `kind-config.yaml` | Un nodo de control con los puertos 80 y 443 del host mapeados al ingress. |
| `valores-kind-ingress.yaml` | Ajustes sobre `k8s/ingress-nginx/values.yaml`: Service NodePort en lugar de NLB. |
| `valores-kind-argocd.yaml` | Dominio `argocd.localtest.me` para Argo CD. |
| `kustomize/app-ejemplo` | Overlay sobre `k8s/app-ejemplo`: una réplica, host local y Secret generado en lugar del ExternalSecret. |

## Requisitos

- Docker en ejecución.
- `kind`, `kubectl` y `helm` en el PATH.
- Los puertos 80 y 443 del equipo libres.

## Uso

```bash
./local/levantar.sh          # crea todo (equivale a ./local/levantar.sh levantar)
./local/levantar.sh borrar   # elimina el clúster
```

El script es idempotente: si el clúster `plataforma` ya existe lo reutiliza y `helm upgrade --install` actualiza los charts.

## Salida esperada

Al terminar, el script imprime algo parecido a esto (la contraseña cambia en cada instalación):

```text
Listo. Contraseña inicial de Argo CD (usuario admin):
<contraseña generada>
Interfaz: kubectl -n argocd port-forward svc/argocd-server 8080:80
Aplicación de ejemplo: curl http://demo.localtest.me
```

Estado esperado de los pods principales:

```bash
kubectl get pods -n argocd
kubectl get pods -n ingress-nginx
```

```text
NAME                                                READY   STATUS    RESTARTS   AGE
ingress-nginx-controller-xxxxxxxxxx-xxxxx           1/1     Running   0          3m
argocd-server-xxxxxxxxxx-xxxxx                      1/1     Running   0          2m
argocd-repo-server-xxxxxxxxxx-xxxxx                 1/1     Running   0          2m
argocd-application-controller-0                     1/1     Running   0          2m
argocd-applicationset-controller-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
```

Prueba de la aplicación por el ingress:

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://demo.localtest.me/
```

```text
200
```

`localtest.me` y sus subdominios resuelven a `127.0.0.1`, así que no hace falta editar `/etc/hosts`.

## Acceso a Argo CD

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:80
```

Abre `http://localhost:8080` con el usuario `admin` y la contraseña que imprimió el script. También puedes obtenerla de nuevo con:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

## Verificación en CI

El workflow `ci-local.yml` ejecuta el mismo script en un runner con Docker, espera los rollouts del ingress y de Argo CD, comprueba los CRDs de Argo CD y exige un HTTP 200 de la aplicación por el ingress. Es la comprobación de referencia de que este entorno funciona.

## Problemas frecuentes

- Puerto 80 ocupado: detén el servicio que lo usa o cambia `hostPort` en `kind-config.yaml` y consulta la aplicación con ese puerto.
- El ingress responde 404 o 503 justo después de levantar: espera unos segundos a que el Deployment de la aplicación esté listo (`kubectl -n demo rollout status deployment/app-demo`).
- Para empezar de cero: `./local/levantar.sh borrar` y vuelve a levantar.
