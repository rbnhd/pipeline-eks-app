resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.name_prefix}-vpc"
  }
}

##### Amazon EKS requires subnets in at least two different AZs to ensure high availability of the Kubernetes control plane.
# subnet 1
resource "aws_subnet" "subnet1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true # Enable auto-assign public IP

  tags = {
    Name = "${var.name_prefix}-subnet1"
  }
  # ##### A common known issue with TF regarding eks
  # # when an EKS cluster is created, AWS implicitly creates an Elastic Network Interface (ENI).
  # # These ENIs are associated with subnets which prevents the subnets and VPC from being deleted until the ENIs are deleted. 
  # # However, Terraform is not aware of these ENIs, so it doesn't know that it needs to delete the EKS cluster before it can delete the VPC and subnets.
  # # Solution: Add explicit dependencies in Terraform code to ensure that the EKS cluster is deleted before the VPC and subnets.
  # depends_on = [
  #   aws_eks_cluster.eks_cluster,
  # ]
}

# Additional subnet in a different AZ
resource "aws_subnet" "subnet2" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.region}c"
  map_public_ip_on_launch = true # Enable auto-assign public IP

  tags = {
    Name = "${var.name_prefix}-subnet2"
  }
  # depends_on = [
  #   aws_eks_cluster.eks_cluster,
  # ]
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.name_prefix}-igw"
  }
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.name_prefix}-rt"
  }
}

resource "aws_route_table_association" "rta1" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "rta2" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_security_group" "allow_ssh" {
  name        = "${var.name_prefix}-allow-ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.name_prefix}-sg-ssh"
  }
}
