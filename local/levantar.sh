#!/usr/bin/env bash
# Levanta la plataforma en local: clúster kind, NGINX Ingress y Argo CD.
# Uso: ./local/levantar.sh [levantar|borrar]
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAIZ="$(dirname "$DIR")"
CLUSTER="plataforma"
INGRESS_CHART_VERSION="4.11.3"
ARGOCD_CHART_VERSION="7.7.5"

requiere() {
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || {
      echo "Falta la herramienta: $cmd" >&2
      exit 1
    }
  done
}

levantar() {
  requiere kind kubectl helm

  if kind get clusters | grep -qx "$CLUSTER"; then
    echo "El clúster $CLUSTER ya existe, se reutiliza."
  else
    kind create cluster --config "$DIR/kind-config.yaml"
  fi
  kubectl config use-context "kind-$CLUSTER" >/dev/null

  # NGINX Ingress con los mismos values del entorno dev, más un parche para kind:
  # el Service es NodePort (no hay balanceador) y el controlador corre en el nodo con puertos mapeados.
  helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null
  helm repo update >/dev/null
  helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
    --version "$INGRESS_CHART_VERSION" \
    --namespace ingress-nginx --create-namespace \
    --values "$RAIZ/k8s/ingress-nginx/values.yaml" \
    --values "$DIR/valores-kind-ingress.yaml" \
    --wait --timeout 5m

  # Argo CD con sus values del entorno dev y un parche con el dominio local.
  helm repo add argo https://argoproj.github.io/argo-helm >/dev/null
  helm repo update >/dev/null
  helm upgrade --install argocd argo/argo-cd \
    --version "$ARGOCD_CHART_VERSION" \
    --namespace argocd --create-namespace \
    --values "$RAIZ/k8s/argocd/values.yaml" \
    --values "$DIR/valores-kind-argocd.yaml" \
    --wait --timeout 5m

  # Aplicación de ejemplo: overlay de Kustomize sobre k8s/app-ejemplo.
  kubectl apply -k "$DIR/kustomize/app-ejemplo"
  kubectl -n demo rollout status deployment/app-demo --timeout=120s

  echo
  echo "Listo. Contraseña inicial de Argo CD (usuario admin):"
  kubectl -n argocd get secret argocd-initial-admin-secret \
    -o jsonpath='{.data.password}' | base64 -d
  echo
  echo "Interfaz: kubectl -n argocd port-forward svc/argocd-server 8080:80"
  echo "Aplicación de ejemplo: curl http://demo.localtest.me"
}

borrar() {
  requiere kind
  kind delete cluster --name "$CLUSTER"
}

case "${1:-levantar}" in
  levantar) levantar ;;
  borrar) borrar ;;
  *)
    echo "Uso: $0 [levantar|borrar]" >&2
    exit 2
    ;;
esac
