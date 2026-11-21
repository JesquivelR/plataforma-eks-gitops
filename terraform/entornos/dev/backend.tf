# Backend remoto en S3 con bloqueo nativo (use_lockfile): no hace falta una tabla de DynamoDB.
# El bucket y la región se pasan al inicializar para no dejarlos fijos en el código:
#   terraform init \
#     -backend-config="bucket=<bucket-de-estado>" \
#     -backend-config="region=us-east-1"
terraform {
  backend "s3" {
    key          = "plataforma-eks-gitops/dev/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
