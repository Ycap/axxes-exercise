variable "aws_region" {
  description = "The region in which the resources will be deployed"
  type = string
  default = "eu-north-1"
}

variable "ami" {
  description = "ami id of ec2 instance (test)"
  type = string
  default = "ami-071878317c449ae48"
}