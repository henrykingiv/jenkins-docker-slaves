resource "aws_vpc" "vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "testing-vpc"
  }
}

resource "aws_subnet" "publicsubnet1" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-west-2a"

  tags = {
    Name = "publicsubnet1"
  }
}
resource "aws_subnet" "publicsubnet2" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-west-2a"

  tags = {
    Name = "publicsubnet2"
  }
}
resource "aws_subnet" "privatesubnet1" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "eu-west-2a"

  tags = {
    Name = "privatesubnet1"
  }
}
resource "aws_subnet" "privatesubnet2" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "eu-west-2a"

  tags = {
    Name = "privatesubnet2"
  }
}
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "test-IGW"
  }
}
resource "aws_eip" "test-eip" {
  domain = "vpc"
  tags = {
    Name = "test-eip"
  }
}

resource "aws_nat_gateway" "nat-gw" {
  subnet_id         = aws_subnet.publicsubnet1.id
  connectivity_type = "public"
  allocation_id     = aws_eip.test-eip.id
  tags = {
    Name = "test-NGW"
  }
}
resource "aws_route_table" "test_pubRT" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "test_pubRT"
  }
}
resource "aws_route_table" "test_privRT" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-gw.id
  }
  tags = {
    Name = "test_privRT"
  }
}
resource "aws_route_table_association" "public1" {
  subnet_id      = aws_subnet.publicsubnet1.id
  route_table_id = aws_route_table.test_pubRT.id
}
resource "aws_route_table_association" "private1" {
  subnet_id      = aws_subnet.privatesubnet1.id
  route_table_id = aws_route_table.test_pubRT.id
}
resource "aws_route_table_association" "public2" {
  subnet_id      = aws_subnet.publicsubnet2.id
  route_table_id = aws_route_table.test_pubRT.id
}
resource "aws_route_table_association" "private2" {
  subnet_id      = aws_subnet.privatesubnet2.id
  route_table_id = aws_route_table.test_pubRT.id
}
# FRONTEND SECURITY GROUP
resource "aws_security_group" "test_SG" {
  name        = "test_SG"
  description = "test_SG"
  vpc_id      = aws_vpc.vpc.id

  # Inbound Rules
  ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS access from anywhere
  ingress {
    description = "http"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH access from anywhere
  ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #Docker containers security group
  ingress {
    description = "docker port"
    from_port   = 4243
    to_port     = 4243
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
   
  }
  ingress {
    description = "docker port"
    from_port   = 32768
    to_port     = 60999
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
   
  }
  # Outbound Rules
  # Internet access to anywhere
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "test-sg"
  }
}

resource "tls_private_key" "keypair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "keypair" {
  content         = tls_private_key.keypair.private_key_pem
  filename        = "testing-keypair.pem"
  file_permission = "600"
}
resource "aws_key_pair" "keypair" {
  key_name   = "testing-keypair"
  public_key = tls_private_key.keypair.public_key_openssh
}

#IAM role

resource "aws_iam_role" "test-ec2-role" {
  name = "test-ec2-role"
  assume_role_policy = jsonencode({
    Version= "2012-10-17"
    Statement= [
        {
            Effect= "Allow"
            Action= "sts:AssumeRole"
            Sid= ""
            Principal= {
                Service= "ec2.amazonaws.com"
            }
        },
    ]
  })
}

resource "aws_iam_instance_profile" "test-roles" {
  name = "test-profile"
  role = aws_iam_role.test-ec2-role.name
}
resource "aws_iam_role_policy_attachment" "test-role-att" {
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  role = aws_iam_role.test-ec2-role.name
}

resource "aws_instance" "jenkins-master" {
  ami = "ami-07d1e0a32156d0d21"
  instance_type = "t2.medium"
  vpc_security_group_ids = [aws_security_group.test_SG.id]
  subnet_id = aws_subnet.publicsubnet1.id
  key_name = aws_key_pair.keypair.id
  associate_public_ip_address = true
  iam_instance_profile = aws_iam_instance_profile.test-roles.id
  user_data = local.jenkins-user-data
  tags = {
    Name = "jenkins-master"
  }
}
resource "aws_instance" "docker-server" {
  ami = "ami-07c1b39b7b3d2525d"
  instance_type = "t2.medium"
  vpc_security_group_ids = [aws_security_group.test_SG.id]
  subnet_id = aws_subnet.publicsubnet1.id
  key_name = aws_key_pair.keypair.id
  associate_public_ip_address = true
  iam_instance_profile = aws_iam_instance_profile.test-roles.id
  user_data = local.docker-userdata
    tags = {
    Name = "docker"
  }
}