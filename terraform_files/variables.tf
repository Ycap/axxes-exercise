variable "aws_region" {
  description = "The region in which the resources will be deployed"
  type = string
  default = "eu-north-1"
}

variable "aws_account_id" {
  description = "id of aws account"
  type = string
  default = "654654510727"
}
variable "ami" {
  description = "ami id of ec2 instance (test)"
  type = string
  default = "ami-071878317c449ae48"
}

variable "docker_image" {
  description = "name of docker image used"
  type = string
  default = "greenfield-project"
}
variable "ecr_registry" {
  description = "URL ECR registry where container is hosted"
  type = string
  default = "654654510727.dkr.ecr.eu-central-1.amazonaws.com"
}

variable "ecr_repo" {
  description = "name of ecr repo"
  type = string
  default = "greenfield-project"
}

variable "docker_image_src_path" {
  description = "path for docker image"
  type = string
  default = "../greenfield-project-java/"
}

variable "untagged_images" {
  description = "number of untagged images allowed in ecr"
  type = number
  default = 15
}

variable "docker_image_src_sha256" {
  type = string
  default = "value"
}

variable "force_image_rebuild" {
  type = bool
  default = false
}