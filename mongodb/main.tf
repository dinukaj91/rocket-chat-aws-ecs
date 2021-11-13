data "terraform_remote_state" "ecs_cluster" {
  backend = "s3"

  config = {
    bucket = "ecs-project-${var.environment}-terraform-state"
    key    = "ecs_cluster/tf.state"
    region = var.aws_region
  }
}

data "terraform_remote_state" "vpc" {
  backend = "s3"

  config = {
    bucket = "ecs-project-${var.environment}-terraform-state"
    key    = "vpc/tf.state"
    region = var.aws_region
  }
}

provider "aws" {
  region = var.aws_region
}

# Since service disovery is used to ge the ip of the network interface used by the
# mongodb container a security group is created for this interface.

resource "aws_security_group" "mongo_sg" {
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id
  name = "${var.name}-${var.environment}-ecs_asg_sg"
  ingress {
      from_port       = 27017
      to_port         = 27017
      protocol        = "tcp"
      cidr_blocks     = data.terraform_remote_state.vpc.outputs.private_subnet_ips
  }
}

# A service discovery tf resource is created with its own namespace which will be used
# by the rocket chat application to connect to it

resource "aws_service_discovery_service" "mongo_discovery_service" {
  name = "${var.name}-${var.environment}"

  dns_config {
    namespace_id = data.terraform_remote_state.ecs_cluster.outputs.service_discovery_namespace_id

    dns_records {
      ttl  = 10
      type = "A"
    }
    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

# Role and policy needed by the container to access the efs access point

resource "aws_iam_role" "mongodb_role" {
  name               = "${var.name}-${var.environment}-ecs-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy" "mongodb_efs_role_policy" {
 name = "${var.name}-${var.environment}-efs-policy"
  role = aws_iam_role.mongodb_role.id

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Resource": "${data.terraform_remote_state.ecs_cluster.outputs.efs_storage_arn}",
            "Action": [
                "elasticfilesystem:ClientWrite",
                "elasticfilesystem:ClientMount"
            ],
            "Condition": {
              "StringEquals": {
                "elasticfilesystem:AccessPointArn": "${data.terraform_remote_state.ecs_cluster.outputs.mongodb_efs_access_point_arn}"
              }
            }
        }
    ]
}
POLICY
}

# Task definiton and service for mongodb application

resource "aws_ecs_task_definition" "mongo" {
  family = "${var.name}-${var.environment}"
  network_mode = "awsvpc"
  task_role_arn = aws_iam_role.mongodb_role.arn
  execution_role_arn = aws_iam_role.mongodb_role.arn

  volume {
    name = "efs-storage"

    efs_volume_configuration {
      file_system_id          = data.terraform_remote_state.ecs_cluster.outputs.efs_storage_id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = data.terraform_remote_state.ecs_cluster.outputs.mongodb_efs_access_point_id
        iam             = "ENABLED"
      }
    }
  }

  container_definitions = <<TASK_DEFINITION
[
    {
        "cpu": ${var.cpu},
        "essential": true,
        "image": "${var.name}:${var.app_version}",
        "memory": ${var.memory},
        "name": "${var.name}",
        "portMappings": [{
          "containerPort": 27017,
          "hostPort": 27017,
          "protocol": "tcp"
        }],
        "mountPoints": [
            {
                "sourceVolume": "efs-storage",
                "containerPath": "/data/db"
            }
        ]
    }
]
TASK_DEFINITION
}

resource "aws_ecs_service" "mongo" {
  name          = "${var.name}-${var.environment}"
  cluster       = data.terraform_remote_state.ecs_cluster.outputs.ecs_cluster_id
  desired_count = 1
  task_definition = aws_ecs_task_definition.mongo.arn

  ordered_placement_strategy {
    type  = "spread"
    field = "host"
  }

  network_configuration {
    subnets = data.terraform_remote_state.vpc.outputs.private_subnet_ids
    security_groups = [aws_security_group.mongo_sg.id, data.terraform_remote_state.ecs_cluster.outputs.ecs_asg_sg_id]
  }

  service_registries {
    registry_arn = aws_service_discovery_service.mongo_discovery_service.arn
  }

}
