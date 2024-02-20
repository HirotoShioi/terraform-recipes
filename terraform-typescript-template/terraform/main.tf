terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.31.0"
    }
  }

  # S3バックエンドの設定
  #   backend "s3" {
  #     bucket  = ""
  #     key     = "terraform.tfstate"
  #     region  = "ap-northeast-1"
  #     profile = vars.profile
  #     encrypt = true
  #   }
}

provider "aws" {
  region  = "ap-northeast-1"
  profile = var.profile
}

locals {
  prefix = "project-prefix"
  lambda = {
    nodejs_runtime = "nodejs20.x"
  }
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name               = "${local.prefix}-iam-role-for-lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
  ]
}

data "archive_file" "hello_world_archive" {
  type = "zip"
  source {
    content  = file("../dist/helloWorld.js")
    filename = "index.js"
  }
  source {
    content  = file("../dist/helloWorld.js.map")
    filename = "index.js.map"
  }
  output_path = "archives/hewllo_world.zip"
}

// Hello World Lambda
resource "aws_lambda_function" "hello_world_lambda" {
  filename         = data.archive_file.hello_world_archive.output_path
  function_name    = "${local.prefix}-handle-hello-world"
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.hello_world_archive.output_base64sha256
  runtime          = local.lambda.nodejs_runtime
  timeout          = 600
  memory_size      = 128
  environment {
    variables = {
      ENV1 = "VALUE1"
    }
  }
}
