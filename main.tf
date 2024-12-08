# VPC
resource "aws_vpc" "stella-vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "stella-vpc"
  }
}

resource "aws_subnet" "PublicSubnet" {
  vpc_id = aws_vpc.stella-vpc.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone      = var.zones[0]
}

# Create a subnet in each availability zone in the VPC. 
resource "aws_subnet" "PrivateSubnet" {
  count             = length(var.zones)
  vpc_id            = aws_vpc.stella-vpc.id
  
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.zones[count.index]

  tags = {
    Name = "private-subnet-${count.index}"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.stella-vpc.id
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"
  depends_on = [aws_internet_gateway.igw]
}

# NAT Gateway
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.PublicSubnet.id

  tags = {
    Name = "Stella NAT Gateway"
  }
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "stella-public-rt" {
  vpc_id = aws_vpc.stella-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.stella-vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "Private Route Table"
  }
}

resource "aws_route_table_association" "private_rta" {
  count = length(var.zones)
  subnet_id      = aws_subnet.PrivateSubnet[count.index].id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.PublicSubnet.id
  route_table_id = aws_route_table.stella-public-rt.id
}

# Generate new RSA Key
resource "tls_private_key" "instance_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "stella-key-pair" {
  key_name   = "stella-key-pair"
  public_key = tls_private_key.instance_key.public_key_openssh

  # Save private key to a local file
  provisioner "local-exec" {
    command = "echo '${tls_private_key.instance_key.private_key_pem}' > ./stella-key.pem"
  }

  # Set correct permissions on private key file
  provisioner "local-exec" {
    command = "chmod 400 ./stella-key.pem"
  }
}

## Security Group
resource "aws_security_group" "ssh_sg" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.stella-vpc.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # For production, restrict to your IP
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_ssh"
  }
}

resource "aws_security_group" "stella_cluster_sg" {
  name        = "stella-cluster-sg"
  description = "Security group for Stella cluster internal communication"
  vpc_id      = aws_vpc.stella-vpc.id

  # Allow all internal traffic within the security group
  ingress {
    description = "Allow all internal traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true  # This enables internal communication
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "stella_workers" {
  count         = var.worker_count
  ami           = "ami-000e04a00165cf1cc"  # AMI is Region specific
  instance_type = var.instance_type
  key_name      = aws_key_pair.stella-key-pair.key_name

  subnet_id                   = aws_subnet.PrivateSubnet[0].id
  vpc_security_group_ids      = [aws_security_group.ssh_sg.id, aws_security_group.stella_cluster_sg.id]

  private_ip = cidrhost(var.private_subnet_cidrs[0], 10 + count.index) # 10.2.0.10 + i

  tags = {
    Name = "Stella-Worker-${count.index}"
  }

  user_data = templatefile("${path.module}/scripts/init.sh", {
  master_ip    = cidrhost(var.public_subnet_cidr, 10)  # Master IP
  my_ip        = cidrhost(var.private_subnet_cidrs[0], 10 + count.index)
  world_size   = "${var.worker_count + 1}"  # n Worker + 1 Master
  num_gpus     = "2"
  rank         = "${count.index + 1}"
  })
}

resource "aws_instance" "stella_master" {
  count         = 1
  ami           = "ami-000e04a00165cf1cc"  # Deep Learning Proprietary Nvidia Driver (Amazon Linux 2) 20240606 for P3 support See https://docs.aws.amazon.com/dlami/latest/devguide/important-changes.html
  instance_type = var.instance_type
  key_name      = aws_key_pair.stella-key-pair.key_name

  subnet_id                   = aws_subnet.PublicSubnet.id
  vpc_security_group_ids      = [aws_security_group.ssh_sg.id, aws_security_group.stella_cluster_sg.id]
  associate_public_ip_address = true
  private_ip = cidrhost(var.public_subnet_cidr, 10) # 10.0.0.10

  tags = {
    Name = "Stella-Master"
  }

  root_block_device {
    volume_size = 200       # Disk size in GB
    volume_type = "gp3"     # General Purpose SSD
  }

  user_data = templatefile("${path.module}/scripts/init.sh", {
    master_ip    = cidrhost(var.public_subnet_cidr, 10) # Master IP
    my_ip        = cidrhost(var.public_subnet_cidr, 10)
    world_size   = "${var.worker_count + 1}"
    num_gpus     = "2"
    rank         = "0"
  })
}