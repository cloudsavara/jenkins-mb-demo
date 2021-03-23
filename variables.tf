variable "aws_region" {
  default = "us-east-2"
}

variable "cluster-name" {
  default = "eks-cluster"
  type    = string
}

variable "workspace_to_environment_map" {
  type = map
  default = {
    dev     = "dev"
    qa      = "qa"
    prod    = "prod"
  }
}

variable "env" {
  description = "env: dev/qa/prod"
}
