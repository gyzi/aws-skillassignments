# ──────────────────────────────────────────────────────────────
# VPC – Public-Only (No NAT Gateway – Cost Optimized)
# ──────────────────────────────────────────────────────────────

resource "aws_vpc" "app" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "app-stack-vpc-${local.region_suffix}" }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_internet_gateway" "app" {
  vpc_id = aws_vpc.app.id

  tags = { Name = "app-stack-igw-${local.region_suffix}" }
}

resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.app.id
  cidr_block              = cidrsubnet(aws_vpc.app.cidr_block, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = { Name = "app-stack-public-${local.region_suffix}-${count.index}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.app.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.app.id
  }

  tags = { Name = "app-stack-public-rt-${local.region_suffix}" }
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
