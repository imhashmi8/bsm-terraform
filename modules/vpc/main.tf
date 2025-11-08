resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = merge(var.tags, { Name = "${var.name}-vpc" })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-igw" })
}

# Subnets
resource "aws_subnet" "public" {
  for_each                = { for i, cidr in var.public_subnet_cidrs : i => { cidr = cidr, az = var.azs[i] } }
  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true
  tags                    = merge(var.tags, { Name = "${var.name}-public-${each.key}" })
}

resource "aws_subnet" "private" {
  for_each          = { for i, cidr in var.private_subnet_cidrs : i => { cidr = cidr, az = var.azs[i] } }
  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az
  tags              = merge(var.tags, { Name = "${var.name}-private-${each.key}" })
}

# Route tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-public-rt" })
}

resource "aws_route" "public_inet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_assoc" {
  for_each       = aws_subnet.public
  route_table_id = aws_route_table.public.id
  subnet_id      = each.value.id
}

# NAT per AZ
resource "aws_eip" "nat" {
  for_each = aws_subnet.public
  domain   = "vpc"
  tags     = merge(var.tags, { Name = "${var.name}-eip-${each.key}" })
}

resource "aws_nat_gateway" "nat" {
  for_each      = aws_subnet.public
  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id
  tags          = merge(var.tags, { Name = "${var.name}-nat-${each.key}" })
  depends_on    = [aws_internet_gateway.igw]
}

resource "aws_route_table" "private" {
  for_each = aws_subnet.private
  vpc_id   = aws_vpc.this.id
  tags     = merge(var.tags, { Name = "${var.name}-private-rt-${each.key}" })
}

resource "aws_route" "private_nat_route" {
  for_each               = aws_route_table.private
  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat[each.key].id
}

resource "aws_route_table_association" "private_assoc" {
  for_each       = aws_subnet.private
  route_table_id = aws_route_table.private[each.key].id
  subnet_id      = each.value.id
}
