output "rol_arn" {
  description = "ARN del rol IAM que asume External Secrets Operator (anotación de la ServiceAccount)."
  value       = aws_iam_role.this.arn
}
