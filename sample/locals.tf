data "aws_availability_zones" "available" {}

module "roadsync" {
  source = "../../modules/roadsync"

  env             = "dev"
  azs             = [data.aws_availability_zones.available.names[0], data.aws_availability_zones.available.names[1]]
  vpc_cidr_block  = "172.16.0.0/16"
  public_subnets  = ["172.16.0.0/24", "172.16.1.0/24"]
  private_subnets = ["172.16.10.0/24", "172.16.11.0/24"]

  main_domain_name = "rs-test.honda-mrs.com"
}
