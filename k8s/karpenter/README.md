# Karpenter

Manifiestos para el autoescalado de nodos del entorno `dev`.

- `values.yaml`: valores del chart de Karpenter. Sustituye los marcadores `<...>` con las salidas de `terraform output` del entorno `dev`.
- `ec2nodeclass.yaml`: plantilla de nodos compartida (AL2023, IMDSv2 obligatorio, volumen gp3 cifrado). Las subredes se descubren por la etiqueta `karpenter.sh/discovery`.
- `nodepool-general.yaml`: pods de uso general en spot y on-demand (familias t y m), con consolidación cuando el nodo está vacío o subutilizado.
- `nodepool-computo.yaml`: cargas intensivas en CPU (familia c, solo on-demand) con un taint para que solo entren pods que lo toleran; consolida únicamente nodos vacíos.

Instalación:

```bash
helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter \
  --version <VERSION> --namespace kube-system -f values.yaml
kubectl apply -f ec2nodeclass.yaml -f nodepool-general.yaml -f nodepool-computo.yaml
```
