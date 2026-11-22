# Decisiones de Karpenter e ingress

Registro corto de por qué se eligió cada opción en `k8s/`. Los ejemplos usan nombres genéricos del entorno dev.

## NLB con `target-type: ip`

- Con `ip`, el AWS Load Balancer Controller registra en el grupo de destino las IP de los pods del controlador. El tráfico llega directo al pod, sin pasar por un NodePort ni por kube-proxy.
- Con `instance`, el NLB envía al NodePort de un nodo y kube-proxy reenvía a un pod que puede estar en otro nodo: un salto extra, más latencia y una segunda NAT.
- Los nodos de Karpenter cambian con frecuencia por la consolidación. Registrar pods en lugar de nodos reduce la cantidad de cambios en el grupo de destino cuando un nodo se reemplaza.
- Requisito: el CNI de la VPC asigna IP de la VPC a los pods, y por eso el modo `ip` funciona en EKS sin configuración adicional.

## `externalTrafficPolicy: Local`

- Conserva la IP de origen del cliente, útil para registros, límites por IP y listas de acceso en el controlador.
- Evita que un nodo reenvíe tráfico a otro nodo, así que no hay salto extra ni pérdida de la IP por SNAT.
- Costo: solo los nodos con un pod del controlador reciben tráfico sano. Por eso hay al menos 2 réplicas repartidas por zona y un health check propio del controlador (`/healthz`, puerto 10254).
- Con `target-type: ip` el NLB ya apunta a pods, así que `Local` es coherente: nunca se envía tráfico a un nodo sin réplica.

## Balanceo entre zonas

- `cross-zone-load-balancing-enabled: "true"` reparte tráfico aunque una zona tenga menos réplicas. Cuesta algo de transferencia entre zonas, pero evita desbalance en un clúster pequeño de dev.

## HPA y PodDisruptionBudget del controlador

- El HPA absorbe picos sin sobredimensionar de entrada (de 2 a 6 réplicas).
- El PDB con `minAvailable: 1` evita que la consolidación de Karpenter o un drenaje deje al controlador sin réplicas.

## Karpenter: dos NodePools

- Uno de uso general y otro de cómputo, para separar cargas con distintos requisitos de instancia.
- La consolidación reemplaza nodos infrautilizados; el PDB y la política de topología limitan el impacto sobre el ingress.

## Qué falta decidir

- Si en producción conviene un NLB interno detrás de un WAF o un ALB para reglas L7.
- Certificados TLS: se agregan junto con External Secrets Operator en una parte posterior.
