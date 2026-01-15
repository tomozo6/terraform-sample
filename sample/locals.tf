data "aws_region" "current" {}
data "aws_availability_zones" "available" {}

locals {
  product         = "sasaki"
  env             = "dev"
  region          = data.aws_region.current.region
  azs             = [data.aws_availability_zones.available.names[0], data.aws_availability_zones.available.names[1]]
  vpc_cidr_block  = "172.16.0.0/16"
  public_subnets  = ["172.16.0.0/24", "172.16.1.0/24"]
  private_subnets = ["172.16.10.0/24", "172.16.11.0/24"]

  # rs-test.honda-mrs.com
  base_fqdn    = "rs-test.honda-mrs.com"
  product_fqdn = "${local.product}.${local.base_fqdn}"
}
