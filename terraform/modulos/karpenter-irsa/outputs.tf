output "rol_controlador_arn" {
  description = "ARN del rol IAM que asume el controlador de Karpenter (anotación de la ServiceAccount)."
  value       = aws_iam_role.controlador.arn
}

output "rol_nodos_nombre" {
  description = "Nombre del rol IAM para los nodos que aprovisiona Karpenter (campo role del EC2NodeClass)."
  value       = aws_iam_role.nodos.name
}

output "cola_interrupciones" {
  description = "Nombre de la cola SQS de interrupciones (ajuste interruptionQueue de Karpenter)."
  value       = aws_sqs_queue.interrupciones.name
}
