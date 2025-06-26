# Local values for computed subnets and tags
locals {
  # Function 3: cidrsubnet for calculating subnets automatically
  public_subnets = [
    cidrsubnet(aws_vpc.main.cidr_block, 8, 1),  # 10.0.1.0/24
    cidrsubnet(aws_vpc.main.cidr_block, 8, 4)   # 10.0.4.0/24
  ]
  
  private_subnets = [
    cidrsubnet(aws_vpc.main.cidr_block, 8, 2),  # 10.0.2.0/24
    cidrsubnet(aws_vpc.main.cidr_block, 8, 3)   # 10.0.3.0/24
  ]

  # Function 4: merge for combining tags
  common_tags = merge(
    var.default_tags,
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Project     = "mercado-scraper"
    }
  )
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  
  tags = merge(local.common_tags, {
    Name = "${var.environment}-mercado-vpc"
  })
}

resource "aws_db_subnet_group" "rds" {
  name       = "${var.environment}-rds-subnet-group"
  subnet_ids = [aws_subnet.private.id, aws_subnet.private2.id]
  tags = merge(local.common_tags, {
    Name = "${var.environment}-rds-subnet-group"
  })
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  
  tags = merge(local.common_tags, {
    Name = "${var.environment}-mercado-igw"
  })
}

# Public subnets using computed CIDR blocks
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_subnets[0]
  map_public_ip_on_launch = true
  availability_zone       = var.availability_zones[0]
  
  tags = merge(local.common_tags, {
    Name = "${var.environment}-public-subnet-1"
    Type = "Public"
  })
}

resource "aws_subnet" "public2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_subnets[1]
  map_public_ip_on_launch = true
  availability_zone       = var.availability_zones[1]
  
  tags = merge(local.common_tags, {
    Name = "${var.environment}-public-subnet-2"
    Type = "Public"
  })
}

# Private subnets using computed CIDR blocks
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_subnets[0]
  availability_zone = var.availability_zones[0]
  
  tags = merge(local.common_tags, {
    Name = "${var.environment}-private-subnet-1"
    Type = "Private"
  })
}

resource "aws_subnet" "private2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_subnets[1]
  availability_zone = var.availability_zones[1]
  
  tags = merge(local.common_tags, {
    Name = "${var.environment}-private-subnet-2"
    Type = "Private"
  })
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
  
  tags = merge(local.common_tags, {
    Name = "${var.environment}-nat-gateway"
  })
}

resource "aws_eip" "nat" {
  domain = "vpc"
  
  tags = merge(local.common_tags, {
    Name = "${var.environment}-nat-eip"
  })
}

# Route table for public subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.environment}-public-route-table"
  })
}

# Associate route table with public subnets
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.public.id
}

# Route table for private subnets
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.environment}-private-route-table"
  })
}

# Associate route table with private subnets
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private2" {
  subnet_id      = aws_subnet.private2.id
  route_table_id = aws_route_table.private.id
}

# Outputs
output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}

output "public_subnet_ids" {
  value = [aws_subnet.public.id, aws_subnet.public2.id]
}

output "private_subnet_id" {
  value = aws_subnet.private.id
}

output "private2_subnet_id" {
  value = aws_subnet.private2.id
}

output "db_subnet_group" {
  value = aws_db_subnet_group.rds.name
}

output "private_subnet_ids" {
  value = [aws_subnet.private.id, aws_subnet.private2.id]
}

output "private_subnet_cidrs" {
  description = "CIDR blocks of private subnets"
  value       = local.private_subnets
}