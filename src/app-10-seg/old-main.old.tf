resource "aws_vpc" "poc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.env}-vpc"
  }
}
# Subnets Publicas
resource "aws_subnet" "subnet_publica" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.poc.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.env}-public-subnet-${count.index + 1}"
  }
}
# Subnets Privadas
resource "aws_subnet" "subnet_privada" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.poc.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]
  tags = {
    Name = "${var.env}-private-subnet-${count.index + 1}"
  }
}
# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.poc.id
  tags = {
    Name = "${var.env}-igw"
  }
}
# Elastic IP do NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags = {
    Name = "${var.env}-nat-eip"
  }
}
# NAT Gateway
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.subnet_publica[0].id
  tags = {
    Name = "${var.env}-nat-gw"
  }
}
# Route Table Publica
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.poc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "${var.env}-public-rt"
  }
}
# Associação das Subnets publicas ao Route Table publica
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.subnet_publica[count.index].id
  route_table_id = aws_route_table.public.id
}
# Route Table Privada
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.poc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = {
    Name = "${var.env}-private-rt"
  }
}
# Associação das Subnets privadas ao Route Table privada
resource "aws_route_table_association" "private" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = aws_subnet.subnet_privada[count.index].id
  route_table_id = aws_route_table.private.id
}
##############################################################

# Criação dos recursos para suportar as aplicações

resource "aws_security_group" "sg_aplicacoes" {
  name        = "sg_aplicacoes"
  description = "HTTP, HTTPS e Redis"
  vpc_id      = aws_vpc.poc.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # Saida
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg-aplicacoes"
  }
}

# criacao da funcao IAM
resource "aws_iam_role" "ssm_role" {
  name = "ssm-to-aplicacoes"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}
# Colocando a política do AWS Systems Manager na funcao
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Criar um perfil da EC2
resource "aws_iam_instance_profile" "ssm_instance_profile" {
  name = "ssm-app-ec2-python"
  role = aws_iam_role.ssm_role.name
}

#Criando IP fixo para as EC2
resource "aws_eip" "app_python_ip_fixo" {
  domain = "vpc"
  tags = {
    Name = "app-python-ip_fixo"
  }
}

#Servidores
resource "aws_instance" "app_python" {
  ami = "ami-04b4f1a9cf54c11d0"
  instance_type = "t3.micro"
  subnet_id = aws_subnet.subnet_publica[0].id
  security_groups = [aws_security_group.sg_aplicacoes.id]
  iam_instance_profile = aws_iam_instance_profile.ssm_instance_profile.name
root_block_device {
    volume_size = 8
    volume_type = "gp2"
  }

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y python3 python3-pip
              apt install python3-flask python3-flask-caching python3-redis -y

              mkdir -p /app/python-app/app-10-seg
              mkdir -p /app/python-app/app-10-seg/templates


              echo "${filebase64("${path.module}/../app-10-seg/main.py")}" | base64 --decode > /app/python-app/app-10-seg/main.py
              echo "${filebase64("${path.module}/../app-10-seg//routes.py")}" | base64 --decode > /app/python-app/app-10-seg/routes.py
              echo "${filebase64("${path.module}/../app-10-seg//templates/datetime.html")}" | base64 --decode > /app/python-app/app-10-seg/templates/datetime.html
              echo "${filebase64("${path.module}/../app-10-seg//templates/index.html")}" | base64 --decode > /app/python-app/app-10-seg/templates/index.html

              cd /app/python-app/app-10-seg/
              nohup python3 main.py > app-10-seg.log 2>&1 &

              EOF
  tags = {
    Name = "PythonApp"
  }
}

#Attachando IP fixo a EC2 python
resource "aws_eip_association" "app_python_eip_assoc" {
  instance_id   = aws_instance.app_python.id
  allocation_id = aws_eip.app_python_ip_fixo.id
}