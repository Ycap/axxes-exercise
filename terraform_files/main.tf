terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
	docker = {
	  source = "kreuzwerker/docker"
	  version = "~> 3.0"
	}
  }
}

provider "aws" {
  region = var.aws_region
}
provider "docker" {
  registry_auth {
    address = data.aws_ecr_authorization_token.auth_token_ecr.proxy_endpoint
    username = data.aws_ecr_authorization_token.auth_token_ecr.user_name
    password  = data.aws_ecr_authorization_token.auth_token_ecr.password
  }
}

data "aws_ecr_authorization_token" "auth_token_ecr" {}

# code used from https://www.linkedin.com/pulse/how-upload-docker-images-aws-ecr-using-terraform-hendrix-roa/
resource "aws_ecr_repository" "greenfield_project" {
  name = "greenfield-project"

  image_scanning_configuration {
	scan_on_push = true
  }
}
#build docker image
resource "docker_image" "greenfield_project_image" {
  name = "${trim(data.aws_ecr_authorization_token.auth_token_ecr.proxy_endpoint, "https://")}/${var.docker_image}:latest"
  build {
    context = "../greenfield-project-java/"
  }
}

# push image to ecr repo
resource "docker_registry_image" "push_docker_image" {
  name = docker_image.greenfield_project_image.name
}
resource "aws_ecs_cluster" "greenfield_project_cluster" {
  name = "greenfield_project_cluster"
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

#Creating task definition
resource "aws_ecs_task_definition" "greenfield_project_task" {
  family = "greenfield-project-task"
  container_definitions = <<DEFINITION
  [
    {
      "name": "greenfield-project-task",
      "image": "${aws_ecr_repository.greenfield_project.repository_url}",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8080,
          "hostPort": 8080
        }
      ],
      "cpu": 1024,
      "memory": 2048
    }
  ]
  DEFINITION
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"    # add the AWS VPN network mode as this is required for Fargate
  memory                   = 2048         # Specify the memory the container requires
  cpu                      = 1024         # Specify the CPU the container requires
  execution_role_arn       = "${aws_iam_role.ecsTaskExecution.arn}"
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture = "X86_64"
  }
}
resource "aws_iam_role" "ecsTaskExecution" {
  #role used to execute ECS Task (Security)
  name               = "ecsTaskExecution"
  assume_role_policy = "${data.aws_iam_policy_document.assume_role_policy.json}"
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}
resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = "${aws_iam_role.ecsTaskExecution.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

#VPC
# Provide a reference to your default VPC
resource "aws_default_vpc" "default_vpc" {
}

# Provide references to default subnets
resource "aws_default_subnet" "default_subnet_a" {
  availability_zone = "${var.aws_region}a"
}

resource "aws_default_subnet" "default_subnet_b" {
  availability_zone = "${var.aws_region}b"
}

#Creating Load Balancer
resource "aws_alb" "greenfield_project_load_balancer" {
  name               = "greenfield-project-load-balancer" #load balancer name
  load_balancer_type = "application"
  subnets = [ # Referencing the default subnets
    "${aws_default_subnet.default_subnet_a.id}",
    "${aws_default_subnet.default_subnet_b.id}"
  ]
  # security group
  security_groups = ["${aws_security_group.lb_security_group.id}"]
}
#Adding Security Group 
# Create a security group for the load balancer:
resource "aws_security_group" "lb_security_group" {
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow traffic in from all sources
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Configure the load balancer with the VPC networking
resource "aws_lb_target_group" "target_group_app" {
  name        = "target-group-app"
  port        = 8080
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = "${aws_default_vpc.default_vpc.id}" # default VPC
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = "${aws_alb.greenfield_project_load_balancer.arn}" #  load balancer
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.target_group_app.arn}" # target group
  }
}

#Create an ECS Service
resource "aws_ecs_service" "greenfield_project_app_service" {
  name            = "greenfield-project-app-service" 
  cluster         = "${aws_ecs_cluster.greenfield_project_cluster.id}"   # Created cluster
  task_definition = "${aws_ecs_task_definition.greenfield_project_task.arn}" # Task that will run
  launch_type     = "FARGATE"
  desired_count   = 3 # Set up the number of containers to 3
  
  load_balancer {
    target_group_arn = "${aws_lb_target_group.target_group_app.arn}" # Reference the target group
    container_name   = "${aws_ecs_task_definition.greenfield_project_task.family}"
    container_port   = 8080 # Specify the container port
  }

  network_configuration {
    subnets          = ["${aws_default_subnet.default_subnet_a.id}", "${aws_default_subnet.default_subnet_b.id}"]
    assign_public_ip = true     # Provide the containers with public IPs
    security_groups  = ["${aws_security_group.lb_security_group.id}"] # Set up the security group
  }
}
#Only allow the traffic from the created load balancer
resource "aws_security_group" "service_security_group" {
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    # Only allowing traffic in from the load balancer security group
    security_groups = ["${aws_security_group.lb_security_group.id}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Log the load balancer app URL
output "app_url" {
  value = aws_alb.greenfield_project_load_balancer.dns_name
}

resource "aws_ecr_lifecycle_policy" "lifecycle_policy" {
  repository = aws_ecr_repository.greenfield_project.name
  #useful to automatically remove 15 deployments if not used or needed, cost effective
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

/*resource "null_resource" "build_push_docker_image" {
	#TODO: fix null_resource trigger so docker image gets pushed to ecr
	triggers = {
		detect_docker_source_changes = var.force_image_rebuild == true ? timestamp() : sha256(join("", [for f in fileset(".", "${var.docker_image_src_path}/**") : file(f)]))
	}
  provisioner "local-exec" {
	command = <<-EOT
	aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin 654654510727.dkr.ecr.eu-central-1.amazonaws.com
	docker tag greenfield-project:latest 654654510727.dkr.ecr.eu-central-1.amazonaws.com/greenfield-project:latest
	docker push 654654510727.dkr.ecr.eu-central-1.amazonaws.com/greenfield-project:latest
	EOT
  }
}*/
