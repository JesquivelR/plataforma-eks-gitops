# Las subredes se calculan a partir del CIDR de la VPC: las públicas usan los
# bloques /24 desde el índice 0 y las privadas desde el índice 100.
locals {
  zonas = { for i, z in var.zonas : z => i }
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr_vpc
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.etiquetas, { Name = var.nombre })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.etiquetas, { Name = var.nombre })
}

# Subredes públicas: reciben los balanceadores de cara a internet.
resource "aws_subnet" "publica" {
  for_each = local.zonas

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = cidrsubnet(var.cidr_vpc, 8, each.value)
  map_public_ip_on_launch = false

  tags = merge(var.etiquetas, {
    Name                                          = "${var.nombre}-publica-${each.key}"
    "kubernetes.io/role/elb"                      = "1"
    "kubernetes.io/cluster/${var.nombre_cluster}" = "shared"
  })
}

# Subredes privadas: nodos y balanceadores internos.
resource "aws_subnet" "privada" {
  for_each = local.zonas

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = cidrsubnet(var.cidr_vpc, 8, each.value + 100)

  tags = merge(var.etiquetas, {
    Name                                          = "${var.nombre}-privada-${each.key}"
    "kubernetes.io/role/internal-elb"             = "1"
    "kubernetes.io/cluster/${var.nombre_cluster}" = "shared"
    "karpenter.sh/discovery"                      = var.nombre_cluster
  })
}

resource "aws_eip" "nat" {
  for_each = var.nat_unica ? { (var.zonas[0]) = 0 } : local.zonas

  domain = "vpc"

  tags = merge(var.etiquetas, { Name = "${var.nombre}-nat-${each.key}" })
}

resource "aws_nat_gateway" "this" {
  for_each = aws_eip.nat

  allocation_id = each.value.id
  subnet_id     = aws_subnet.publica[each.key].id

  tags = merge(var.etiquetas, { Name = "${var.nombre}-${each.key}" })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route_table" "publica" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(var.etiquetas, { Name = "${var.nombre}-publica" })
}

resource "aws_route_table_association" "publica" {
  for_each = aws_subnet.publica

  subnet_id      = each.value.id
  route_table_id = aws_route_table.publica.id
}

# Una tabla de rutas privada por zona; con NAT única todas salen por la misma.
resource "aws_route_table" "privada" {
  for_each = local.zonas

  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = var.nat_unica ? aws_nat_gateway.this[var.zonas[0]].id : aws_nat_gateway.this[each.key].id
  }

  tags = merge(var.etiquetas, { Name = "${var.nombre}-privada-${each.key}" })
}

resource "aws_route_table_association" "privada" {
  for_each = aws_subnet.privada

  subnet_id      = each.value.id
  route_table_id = aws_route_table.privada[each.key].id
}

# El grupo de seguridad por defecto se deja sin reglas para que nada lo use por accidente.
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.etiquetas, { Name = "${var.nombre}-default-sin-reglas" })
}

# Registros de flujo de la VPC hacia CloudWatch Logs.
resource "aws_cloudwatch_log_group" "flow_logs" {
  #checkov:skip=CKV_AWS_158: los registros de flujo de dev usan el cifrado por defecto de CloudWatch; la llave KMS propia se evalúa junto con el módulo de EKS
  name              = "/vpc/${var.nombre}/flow-logs"
  retention_in_days = var.retencion_logs_dias

  tags = var.etiquetas
}

data "aws_iam_policy_document" "flow_logs_confianza" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "flow_logs_permisos" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]
    resources = ["${aws_cloudwatch_log_group.flow_logs.arn}:*"]
  }
}

resource "aws_iam_role" "flow_logs" {
  name               = "${var.nombre}-flow-logs"
  assume_role_policy = data.aws_iam_policy_document.flow_logs_confianza.json

  tags = var.etiquetas
}

resource "aws_iam_role_policy" "flow_logs" {
  name   = "escritura-de-logs"
  role   = aws_iam_role.flow_logs.id
  policy = data.aws_iam_policy_document.flow_logs_permisos.json
}

resource "aws_flow_log" "this" {
  vpc_id          = aws_vpc.this.id
  traffic_type    = "ALL"
  log_destination = aws_cloudwatch_log_group.flow_logs.arn
  iam_role_arn    = aws_iam_role.flow_logs.arn

  tags = merge(var.etiquetas, { Name = var.nombre })
}
