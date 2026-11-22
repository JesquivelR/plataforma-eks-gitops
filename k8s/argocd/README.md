# Argo CD y app-of-apps

Argo CD sincroniza la plataforma desde este repositorio con el patrón app-of-apps: una aplicación raíz apunta a `apps/` y cada archivo de esa carpeta es una `Application` de un componente.

```
bootstrap/raiz.yaml  ->  apps/ingress-nginx.yaml        (chart + values de k8s/ingress-nginx)
                         apps/karpenter-nodepools.yaml  (EC2NodeClass y NodePools de k8s/karpenter)
                         apps/external-secrets.yaml     (chart de External Secrets Operator)
                         apps/otel-collector.yaml       (Collector en modo Deployment)
```

- `values.yaml`: valores del chart `argo-cd` para el entorno `dev`.
- `bootstrap/raiz.yaml`: aplicación raíz con `prune` y `selfHeal`.
- `apps/`: una `Application` por componente; el orden lo marcan las anotaciones `sync-wave` (ingress y ESO primero, NodePools después, Collector al final).

## Instalación

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm upgrade --install argocd argo/argo-cd --version <VERSION> \
  --namespace argocd --create-namespace -f values.yaml
kubectl apply -f bootstrap/raiz.yaml
```

A partir de ahí, un cambio en `apps/` o en los manifiestos que referencian se aplica con un merge a `main`; no hace falta ejecutar `kubectl apply` a mano.

## Notas

- El chart de Karpenter se instala fuera de Argo CD (junto con el clúster) porque el controlador tiene que existir antes de que haya nodos donde corra Argo CD.
- Sustituye `<ARN_ROL_ESO>` con la salida del módulo `eso-irsa` de Terraform.
- Las versiones de los charts están fijadas; súbelas con un PR para que el cambio quede revisado.
