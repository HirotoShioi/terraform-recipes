resource "aws_vpc" "vpc" {
  cidr_block           = local.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = merge(local.tags, {
    Name = local.name
  })
}

// private subnet
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = local.subnets.private
  availability_zone = local.availablity_zone
  tags = merge(local.tags, {
    Name = "private-${local.availablity_zone}"
  })
}

// public subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.vpc.id
  map_public_ip_on_launch = true
  cidr_block              = local.subnets.public
  availability_zone       = local.availablity_zone
  tags = merge(local.tags, {
    Name = "public-${local.availablity_zone}"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.vpc.id
  tags   = local.tags
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id
  tags = merge(local.tags, {
    Name = "${local.name}-public"
  })
}

resource "aws_route" "this" {
  gateway_id             = aws_internet_gateway.this.id
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route_table_association" "this" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id
  tags = merge(local.tags, {
    Name = "${local.name}-private"
  })
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

// public subnetにbastion hostを作成
resource "aws_security_group" "public" {
  vpc_id = aws_vpc.vpc.id
  tags   = local.tags
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_key_pair" "this" {
  key_name   = "ssh"
  public_key = file("./key/id_rsa.pub")
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_instance" "public" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public.id
  key_name               = aws_key_pair.this.key_name
  vpc_security_group_ids = [aws_security_group.public.id]
  tags = merge(local.tags, {
    Name = "public-ec2"
  })
}

resource "terraform_data" "scp_file" {
  depends_on = [aws_instance.public, aws_key_pair.this]

  provisioner "local-exec" {
    command = <<-EOT
      scp -i ./key/id_rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ./key/id_rsa ec2-user@${aws_instance.public.public_ip}:/home/ec2-user/.ssh/id_rsa
    EOT
  }
}

// private subnetにEC2インスタンスを作成
// このEC2インスタンスはpublic subnetのbastion hostを経由してアクセスする
resource "aws_security_group" "private" {
  vpc_id = aws_vpc.vpc.id
  tags   = local.tags
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.public.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "private" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private.id
  key_name               = aws_key_pair.this.key_name
  vpc_security_group_ids = [aws_security_group.private.id]
  tags = merge(local.tags, {
    Name = "private-ec2"
  })
}
