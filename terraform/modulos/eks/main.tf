data "aws_partition" "actual" {}

# Llave de KMS para cifrar los Secrets de Kubernetes en etcd.
resource "aws_kms_key" "secretos" {
  #checkov:skip=CKV2_AWS_64: se usa la política por defecto de la llave, que delega el acceso en IAM de la cuenta; una política propia se evalúa cuando haya más de un administrador
  description             = "Cifrado de secretos de Kubernetes del clúster ${var.nombre_cluster}"
  enable_key_rotation     = true
  deletion_window_in_days = 7

  tags = var.etiquetas
}

resource "aws_kms_alias" "secretos" {
  name          = "alias/${var.nombre_cluster}-secretos"
  target_key_id = aws_kms_key.secretos.key_id
}

resource "aws_cloudwatch_log_group" "cluster" {
  #checkov:skip=CKV_AWS_158: los registros del plano de control de dev usan el cifrado por defecto de CloudWatch; la llave propia encarece el laboratorio sin cambiar el diseño
  name              = "/aws/eks/${var.nombre_cluster}/cluster"
  retention_in_days = var.retencion_logs_dias

  tags = var.etiquetas
}

data "aws_iam_policy_document" "confianza_cluster" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${var.nombre_cluster}-plano-control"
  assume_role_policy = data.aws_iam_policy_document.confianza_cluster.json

  tags = var.etiquetas
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:${data.aws_partition.actual.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_security_group" "cluster" {
  name_prefix = "${var.nombre_cluster}-cluster-"
  description = "Trafico adicional del plano de control de EKS"
  vpc_id      = var.vpc_id

  tags = merge(var.etiquetas, { Name = "${var.nombre_cluster}-cluster" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_eks_cluster" "this" {
  name     = var.nombre_cluster
  role_arn = aws_iam_role.cluster.arn
  version  = var.version_kubernetes

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  vpc_config {
    subnet_ids              = var.subredes_privadas
    security_group_ids      = [aws_security_group.cluster.id]
    endpoint_private_access = true
    endpoint_public_access  = length(var.cidrs_acceso_api) > 0
    public_access_cidrs     = length(var.cidrs_acceso_api) > 0 ? var.cidrs_acceso_api : null
  }

  encryption_config {
    resources = ["secrets"]

    provider {
      key_arn = aws_kms_key.secretos.arn
    }
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  tags = var.etiquetas

  depends_on = [
    aws_iam_role_policy_attachment.cluster,
    aws_cloudwatch_log_group.cluster,
  ]
}

# Proveedor OIDC del clúster: lo usan los roles IRSA (Karpenter, External Secrets).
data "tls_certificate" "oidc" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "cluster" {
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.oidc.certificates[0].sha1_fingerprint]

  tags = var.etiquetas
}

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
  name               = "${var.nombre_cluster}-nodos-sistema"
  assume_role_policy = data.aws_iam_policy_document.confianza_nodos.json

  tags = var.etiquetas
}

resource "aws_iam_role_policy_attachment" "nodos" {
  for_each = toset([
    "AmazonEKSWorkerNodePolicy",
    "AmazonEKS_CNI_Policy",
    "AmazonEC2ContainerRegistryReadOnly",
    "AmazonSSMManagedInstanceCore",
  ])

  role       = aws_iam_role.nodos.name
  policy_arn = "arn:${data.aws_partition.actual.partition}:iam::aws:policy/${each.key}"
}

# Node group mínimo para los componentes del sistema; el resto lo aprovisiona Karpenter.
resource "aws_eks_node_group" "sistema" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "sistema"
  node_role_arn   = aws_iam_role.nodos.arn
  subnet_ids      = var.subredes_privadas
  instance_types  = var.tipos_instancia_sistema
  ami_type        = "AL2023_x86_64_STANDARD"

  scaling_config {
    min_size     = var.nodos_sistema.minimo
    desired_size = var.nodos_sistema.deseado
    max_size     = var.nodos_sistema.maximo
  }

  labels = {
    "rol" = "sistema"
  }

  taint {
    key    = "CriticalAddonsOnly"
    value  = "true"
    effect = "NO_SCHEDULE"
  }

  tags = var.etiquetas

  depends_on = [aws_iam_role_policy_attachment.nodos]

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}
