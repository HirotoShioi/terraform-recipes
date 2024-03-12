terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region  = "us-west-2"
  profile = "hashport-tf-dev"
}

locals {
  name             = "vpc-sample"
  region           = "us-west-2"
  availablity_zone = "us-west-2a"
  tags = {
    Project = local.name
    User    = "Hiroto"
  }
  cidr_block = "10.0.0.0/16"
  subnets = {
    public = "10.0.2.0/24"
  }
}
// vpcを作り、その中にec2を作成する
// ec2にはSSM Session Managerを使ってログインできるようにする
resource "aws_vpc" "vpc" {
  cidr_block = local.cidr_block
  tags = merge(local.tags, {
    Name = local.name
  })
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = local.subnets.public
  availability_zone = local.availablity_zone
  tags = merge(local.tags, {
    Name = "public-${local.availablity_zone}"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id
  tags = merge(local.tags, {
    Name = "${local.name}-public"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.vpc.id
  tags   = local.tags
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route" "this" {
  gateway_id             = aws_internet_gateway.this.id
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "access_to_s3" {
  statement {
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]
    resources = ["arn:aws:s3:::${aws_s3_bucket.this.bucket}"]
  }
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = ["arn:aws:s3:::${aws_s3_bucket.this.bucket}/*"]
  }
}

resource "aws_iam_policy" "access_to_s3" {
  name        = "access-to-s3"
  description = "Allow access to S3"
  policy      = data.aws_iam_policy_document.access_to_s3.json
}

// iam roleを作成する
resource "aws_iam_role" "this" {
  name               = "ec2-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    aws_iam_policy.access_to_s3.arn
  ]
}

resource "aws_iam_instance_profile" "this" {
  name = "ec2-ssm-profile"
  role = aws_iam_role.this.name
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

// public subnetにbastion hostを作成
resource "aws_security_group" "public" {
  vpc_id = aws_vpc.vpc.id
  tags   = local.tags
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "this" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public.id
  iam_instance_profile        = aws_iam_instance_profile.this.name
  vpc_security_group_ids      = [aws_security_group.public.id]
  associate_public_ip_address = true
  tags = merge(local.tags, {
    Name = "ec2-sample"
  })
}

resource "random_id" "random_id" {
  byte_length = 4
}

resource "aws_s3_bucket" "this" {
  bucket = "${local.name}-bucket-${random_id.random_id.hex}"
}

data "aws_vpc_endpoint_service" "s3" {
  service      = "s3"
  service_type = "Gateway"
}

resource "aws_vpc_endpoint" "this" {
  vpc_id            = aws_vpc.vpc.id
  service_name      = data.aws_vpc_endpoint_service.s3.service_name
  route_table_ids   = [aws_route_table.public.id]
  vpc_endpoint_type = "Gateway"
}
