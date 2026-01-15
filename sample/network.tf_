# ----------------------------------------------------------
# VPC & Internet Gateway
# ----------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block = local.vpc_cidr_block

  tags = {
    "Name" = "${local.product}-${local.env}-main-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    "Name" = "${local.product}-${local.env}-main-igw"
  }
}

# ----------------------------------------------------------
# Subnet (Public)
# ----------------------------------------------------------
resource "aws_subnet" "public" {
  count = length(local.azs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = local.public_subnets[count.index]
  availability_zone = local.azs[count.index]

  tags = {
    Name = "${local.product}-${local.env}-main-subnet-public-${format("%02d", count.index)}"
  }
}

# Public Subnetは1つのルートテーブルを共有
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.product}-${local.env}-main-rtb-public"
  }
}

resource "aws_route" "public_default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public[*])

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ----------------------------------------------------------
# Subnet (Private)
# ----------------------------------------------------------
resource "aws_subnet" "private" {
  count = length(local.azs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_subnets[count.index]
  availability_zone = local.azs[count.index]

  tags = {
    Name = "${local.product}-${local.env}-main-subnet-private-${format("%02d", count.index)}"
  }
}

resource "aws_route_table" "private" {
  count = length(aws_subnet.private[*])

  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.product}-${local.env}-main-rtb-private-${format("%02d", count.index)}"
  }
}

resource "aws_route" "private_default" {
  count = length(aws_subnet.private[*])

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[count.index].id
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private[*])

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# ----------------------------------------------------------
# NAT Gateway
# ----------------------------------------------------------
resource "aws_eip" "main" {
  count = length(aws_subnet.public[*])

  domain = "vpc"

  tags = {
    Name = "${local.product}-${local.env}-main-natgw-eip-${format("%02d", count.index)}"
  }
}

resource "aws_nat_gateway" "main" {
  count = length(aws_subnet.public[*])

  allocation_id = aws_eip.main[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${local.product}-${local.env}-main-natgw-${format("%02d", count.index)}"
  }
}

# ----------------------------------------------------------
# VPC Endpoint
# ----------------------------------------------------------
# s3
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${local.region}.s3"

  tags = {
    Name = "${local.product}-${local.env}-main-vpce-s3"
  }
}

resource "aws_vpc_endpoint_route_table_association" "s3" {
  count = length(aws_route_table.private[*])

  vpc_endpoint_id = aws_vpc_endpoint.s3.id
  route_table_id  = aws_route_table.private[count.index].id
}

# dynamodb
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${local.region}.dynamodb"

  tags = {
    Name = "${local.product}-${local.env}-main-vpce-dynamodb"
  }
}

resource "aws_vpc_endpoint_route_table_association" "dynamodb" {
  count = length(aws_route_table.private[*])

  vpc_endpoint_id = aws_vpc_endpoint.dynamodb.id
  route_table_id  = aws_route_table.private[count.index].id
}

