resource "aws_vpc" "main_vpc" {
  cidr_block           = var.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.name}-${var.environment}-vpc"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = element(var.private_subnets, count.index)
  availability_zone = element(var.availability_zones, count.index)
  count             = length(var.private_subnets)

  tags = {
    Name = "${var.name}-${var.environment}-private-subnet-${format("%02d", count.index + 1)}"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = element(var.public_subnets, count.index)
  availability_zone = element(var.availability_zones, count.index)
  count             = length(var.public_subnets)

  tags = {
    Name = "${var.name}-${var.environment}-public-subnet-${format("%02d", count.index + 1)}"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "${var.name}-${var.environment}-igw"
  }
}

resource "aws_eip" "natgw_eip" {
  count = length(var.private_subnets)
  vpc = true

  tags = {
    Name = "${var.name}-${var.environment}-natgw-eip-${format("%02d", count.index+1)}"
  }
}

resource "aws_nat_gateway" "natgw" {
  count         = length(var.private_subnets)
  allocation_id = element(aws_eip.natgw_eip.*.id, count.index)
  subnet_id     = element(aws_subnet.public_subnet.*.id, count.index)

  tags = {
    Name = "${var.name}-${var.environment}-natgw-${format("%02d", count.index+1)}"
  }
}

resource "aws_route_table" "private_rt" {
  count  = length(var.private_subnets)
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name        = "${var.name}-${var.environment}-private-route-table-${format("%02d", count.index+1)}"
  }
}

resource "aws_route" "private_route_1" {
  count                  = length(compact(var.private_subnets))
  route_table_id         = element(aws_route_table.private_rt.*.id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = element(aws_nat_gateway.natgw.*.id, count.index)
}

resource "aws_route_table_association" "private_rt_assoc" {
  count          = length(var.private_subnets)
  subnet_id      = element(aws_subnet.private_subnet.*.id, count.index)
  route_table_id = element(aws_route_table.private_rt.*.id, count.index)
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name        = "${var.name}-${var.environment}-public-route-table"
  }
}

resource "aws_route" "public_route_1" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_rt_assoc" {
  count          = length(var.public_subnets)
  subnet_id      = element(aws_subnet.public_subnet.*.id, count.index)
  route_table_id = aws_route_table.public_rt.id
}

output "vpc_id" {
  value = aws_vpc.main_vpc.id
}

output "public_subnet_ids" {
  value = aws_subnet.public_subnet.*.id
}

output "private_subnet_ids" {
  value = aws_subnet.private_subnet.*.id
}

output "public_subnet_ips" {
  value = var.public_subnets
}

output "private_subnet_ips" {
  value = var.private_subnets
}