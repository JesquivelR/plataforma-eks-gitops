data "aws_caller_identity" "actual" {}
data "aws_partition" "actual" {}
data "aws_region" "actual" {}

locals {
  emisor    = replace(var.oidc_issuer, "https://", "")
  cuenta    = data.aws_caller_identity.actual.account_id
  particion = data.aws_partition.actual.partition
  region    = data.aws_region.actual.name
}

data "aws_iam_policy_document" "confianza" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.emisor}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.emisor}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = "${var.nombre_cluster}-external-secrets"
  assume_role_policy = data.aws_iam_policy_document.confianza.json
  tags               = var.etiquetas
}

# Solo lectura y solo sobre los secretos que empiezan con el prefijo del entorno.
data "aws_iam_policy_document" "lectura" {
  statement {
    sid = "LeerSecretos"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = [
      "arn:${local.particion}:secretsmanager:${local.region}:${local.cuenta}:secret:${var.prefijo_secretos}*",
    ]
  }
}

resource "aws_iam_policy" "lectura" {
  name   = "${var.nombre_cluster}-external-secrets"
  policy = data.aws_iam_policy_document.lectura.json
  tags   = var.etiquetas
}

resource "aws_iam_role_policy_attachment" "lectura" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.lectura.arn
}
