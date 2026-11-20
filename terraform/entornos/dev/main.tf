provider "aws" {
  region = var.region

  default_tags {
    tags = var.etiquetas
  }
}


data "aws_availability_zones" "disponibles" {
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
