terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_instance" "first_test" {
  ami = var.ami
  instance_type = "t2.micro"
  tags = {
    Name = "first_test"
  }
}
