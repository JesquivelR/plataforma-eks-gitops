provider "aws" {
  region = var.region

  default_tags {
    tags = var.etiquetas
  }
}

# Los módulos de red y de clúster se conectan aquí en los siguientes pasos.
