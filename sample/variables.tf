variable "product" {
  type    = string
  default = "roadsync"
}

variable "env" {
  type = string
}

variable "region" {
  type    = string
  default = "ap-northeast-1"
}

# ---------------------------------------------------------
# Network
# ---------------------------------------------------------
variable "vpc_cidr_block" {
  type = string
}

variable "azs" {
  type = list(string)
}

variable "public_subnets" {
  type = list(string)
}

variable "private_subnets" {
  type = list(string)
}

variable "main_domain_name" {
  type = string
}
