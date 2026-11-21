provider "aws" {
  region = var.region

  default_tags {
    tags = var.etiquetas
  }
}


data "aws_availability_zones" "disponibles" {
  #checkov:skip=CKV_AWS_394: el entorno toma solo las tres primeras zonas con slice, así que el resultado no crece cuando AWS agrega una zona
  state = "available"
}

locals {
  nombre_cluster = "${var.nombre}-cluster"
  zonas          = slice(data.aws_availability_zones.disponibles.names, 0, 3)
}

module "vpc" {
  source = "../../modulos/vpc"

  nombre         = var.nombre
  nombre_cluster = local.nombre_cluster
  cidr_vpc       = var.cidr_vpc
  zonas          = local.zonas
  nat_unica      = true
}

module "eks" {
  source = "../../modulos/eks"

  nombre_cluster    = local.nombre_cluster
  vpc_id            = module.vpc.vpc_id
  subredes_privadas = module.vpc.subredes_privadas
}

module "karpenter_irsa" {
  source = "../../modulos/karpenter-irsa"

  nombre_cluster    = module.eks.nombre_cluster
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer       = module.eks.oidc_issuer
}

module "eso_irsa" {
  source = "../../modulos/eso-irsa"

  nombre_cluster    = module.eks.nombre_cluster
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer       = module.eks.oidc_issuer
  prefijo_secretos  = "${var.nombre}/"
}
