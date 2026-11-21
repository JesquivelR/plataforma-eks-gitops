data "aws_caller_identity" "actual" {}
data "aws_partition" "actual" {}
data "aws_region" "actual" {}

locals {
  emisor     = replace(var.oidc_issuer, "https://", "")
  cuenta     = data.aws_caller_identity.actual.account_id
  particion  = data.aws_partition.actual.partition
  region     = data.aws_region.actual.name
  arn_nodos  = aws_iam_role.nodos.arn
  arn_cola   = aws_sqs_queue.interrupciones.arn
  arn_clust  = "arn:${local.particion}:eks:${local.region}:${local.cuenta}:cluster/${var.nombre_cluster}"
  etiq_clust = "kubernetes.io/cluster/${var.nombre_cluster}"
}

# Rol que asume el controlador de Karpenter mediante IRSA. La condicion "sub"
# limita el rol a una sola ServiceAccount de un solo namespace.
data "aws_iam_policy_document" "confianza_controlador" {
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

resource "aws_iam_role" "controlador" {
  name               = "${var.nombre_cluster}-karpenter"
  assume_role_policy = data.aws_iam_policy_document.confianza_controlador.json
  tags               = var.etiquetas
}

# Rol de los nodos que Karpenter aprovisiona (distinto al del node group del sistema).
data "aws_iam_policy_document" "confianza_nodos" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "nodos" {
  name               = "${var.nombre_cluster}-karpenter-nodos"
  assume_role_policy = data.aws_iam_policy_document.confianza_nodos.json
  tags               = var.etiquetas
}

resource "aws_iam_role_policy_attachment" "nodos" {
  for_each = toset([
    "AmazonEKSWorkerNodePolicy",
    "AmazonEKS_CNI_Policy",
    "AmazonEC2ContainerRegistryReadOnly",
    "AmazonSSMManagedInstanceCore",
  ])

  role       = aws_iam_role.nodos.name
  policy_arn = "arn:${local.particion}:iam::aws:policy/${each.value}"
}

# Permite que los nodos de Karpenter se registren en el clúster.
resource "aws_eks_access_entry" "nodos" {
  cluster_name  = var.nombre_cluster
  principal_arn = aws_iam_role.nodos.arn
  type          = "EC2_LINUX"
  tags          = var.etiquetas
}

# Cola SQS con los avisos de interrupcion de instancias spot y mantenimiento.
resource "aws_sqs_queue" "interrupciones" {
  name                      = "${var.nombre_cluster}-karpenter"
  message_retention_seconds = 300
  sqs_managed_sse_enabled   = true
  tags                      = var.etiquetas
}

data "aws_iam_policy_document" "cola" {
  statement {
    sid       = "EventBridgeEnvia"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.interrupciones.arn]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com", "sqs.amazonaws.com"]
    }
  }

  statement {
    sid       = "SoloTLS"
    effect    = "Deny"
    actions   = ["sqs:*"]
    resources = [aws_sqs_queue.interrupciones.arn]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_sqs_queue_policy" "interrupciones" {
  queue_url = aws_sqs_queue.interrupciones.url
  policy    = data.aws_iam_policy_document.cola.json
}

locals {
  eventos = {
    estado-instancia = {
      source      = "aws.ec2"
      detail_type = "EC2 Instance State-change Notification"
    }
    interrupcion-spot = {
      source      = "aws.ec2"
      detail_type = "EC2 Spot Instance Interruption Warning"
    }
    rebalanceo = {
      source      = "aws.ec2"
      detail_type = "EC2 Instance Rebalance Recommendation"
    }
    salud = {
      source      = "aws.health"
      detail_type = "AWS Health Event"
    }
  }
}

resource "aws_cloudwatch_event_rule" "interrupciones" {
  for_each = local.eventos

  name = "${var.nombre_cluster}-karpenter-${each.key}"
  event_pattern = jsonencode({
    source        = [each.value.source]
    "detail-type" = [each.value.detail_type]
  })
  tags = var.etiquetas
}

resource "aws_cloudwatch_event_target" "interrupciones" {
  for_each = local.eventos

  rule = aws_cloudwatch_event_rule.interrupciones[each.key].name
  arn  = aws_sqs_queue.interrupciones.arn
}

# Politica del controlador: acotada por etiquetas del clúster donde se puede.
data "aws_iam_policy_document" "controlador" {
  statement {
    sid = "LecturaEC2"
    actions = [
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeImages",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceTypeOfferings",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSpotPriceHistory",
      "ec2:DescribeSubnets",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [local.region]
    }
  }

  statement {
    sid     = "CrearInstanciasYPlantillas"
    actions = ["ec2:RunInstances", "ec2:CreateFleet", "ec2:CreateLaunchTemplate"]
    resources = [
      "arn:${local.particion}:ec2:${local.region}:*:launch-template/*",
      "arn:${local.particion}:ec2:${local.region}:*:fleet/*",
      "arn:${local.particion}:ec2:${local.region}:*:instance/*",
      "arn:${local.particion}:ec2:${local.region}:*:volume/*",
      "arn:${local.particion}:ec2:${local.region}:*:network-interface/*",
      "arn:${local.particion}:ec2:${local.region}:*:spot-instances-request/*",
    ]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/${local.etiq_clust}"
      values   = ["owned"]
    }
  }

  statement {
    sid     = "UsarRecursosExistentes"
    actions = ["ec2:RunInstances", "ec2:CreateFleet"]
    resources = [
      "arn:${local.particion}:ec2:${local.region}:*:subnet/*",
      "arn:${local.particion}:ec2:${local.region}:*:security-group/*",
      "arn:${local.particion}:ec2:${local.region}::image/*",
      "arn:${local.particion}:ec2:${local.region}::snapshot/*",
    ]
  }

  statement {
    sid       = "EtiquetarAlCrear"
    actions   = ["ec2:CreateTags"]
    resources = ["arn:${local.particion}:ec2:${local.region}:*:*/*"]
    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"
      values   = ["RunInstances", "CreateFleet", "CreateLaunchTemplate"]
    }
  }

  statement {
    sid       = "BorrarRecursosPropios"
    actions   = ["ec2:TerminateInstances", "ec2:DeleteLaunchTemplate"]
    resources = ["arn:${local.particion}:ec2:${local.region}:*:*/*"]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/${local.etiq_clust}"
      values   = ["owned"]
    }
  }

  statement {
    sid       = "PasarRolDeNodos"
    actions   = ["iam:PassRole"]
    resources = [local.arn_nodos]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ec2.amazonaws.com"]
    }
  }

  statement {
    sid       = "ColaDeInterrupciones"
    actions   = ["sqs:DeleteMessage", "sqs:GetQueueUrl", "sqs:ReceiveMessage"]
    resources = [local.arn_cola]
  }

  statement {
    sid       = "DescubrirClusterYParametros"
    actions   = ["eks:DescribeCluster"]
    resources = [local.arn_clust]
  }

  statement {
    sid       = "ParametrosSSMDeAMI"
    actions   = ["ssm:GetParameter"]
    resources = ["arn:${local.particion}:ssm:${local.region}::parameter/aws/service/*"]
  }

  statement {
    sid       = "PreciosBajoDemanda"
    actions   = ["pricing:GetProducts"]
    resources = ["*"]
  }

  statement {
    sid = "PerfilesDeInstancia"
    actions = [
      "iam:CreateInstanceProfile",
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:TagInstanceProfile",
      "iam:GetInstanceProfile",
    ]
    resources = [
      "arn:${local.particion}:iam::${local.cuenta}:instance-profile/*",
      local.arn_nodos,
    ]
  }
}

resource "aws_iam_policy" "controlador" {
  name   = "${var.nombre_cluster}-karpenter"
  policy = data.aws_iam_policy_document.controlador.json
  tags   = var.etiquetas
}

resource "aws_iam_role_policy_attachment" "controlador" {
  role       = aws_iam_role.controlador.name
  policy_arn = aws_iam_policy.controlador.arn
}
