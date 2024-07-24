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
# code used from https://www.linkedin.com/pulse/how-upload-docker-images-aws-ecr-using-terraform-hendrix-roa/
resource "aws_ecr_repository" "greenfield_project" {
  name = "greenfield-project"

  image_scanning_configuration {
	scan_on_push = true
  }
}

#useful to automatically remove 15 deployments if not used or needed, cost effective
resource "aws_ecr_lifecycle_policy" "lifecycle_policy" {
  repository = aws_ecr_repository.greenfield_project.name

  policy = <<EOF
	{
	    "rules": [
	        {
	            "rulePriority": 1,
	            "description": "Keep only the last ${var.untagged_images} untagged images.",
	            "selection": {
	                "tagStatus": "untagged",
	                "countType": "imageCountMoreThan",
	                "countNumber": ${var.untagged_images}
	            },
	            "action": {
	                "type": "expire"
	            }
	        }
	    ]
	}
	EOF
}

resource "null_resource" "build_push_docker_image" {
	#TODO: fix null_resource trigger so docker image gets pushed to ecr
	/*triggers = {
		detect_docker_source_changes = var.force_image_rebuild == true ? timestamp() : sha256(join("", [for f in fileset(".", "${var.docker_image_src_path}/**") : file(f)]))
	}*/
  provisioner "local-exec" {
	command = <<EOT
	aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin 654654510727.dkr.ecr.eu-central-1.amazonaws.com
	docker tag greenfield-project:latest 654654510727.dkr.ecr.eu-central-1.amazonaws.com/greenfield-project:latest
	docker push 654654510727.dkr.ecr.eu-central-1.amazonaws.com/greenfield-project:latest
	EOT
  }
}
