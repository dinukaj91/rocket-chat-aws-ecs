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

resource "aws_alb_target_group" "tg" {
  name        = "${var.name}-tg-${var.environment}"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id
  target_type = "instance"
 
  health_check {
   # Number of consecutive health checks successes required before considering an unhealthy target healthy
   healthy_threshold   = "3"
   # Approximate amount of time, in seconds, between health checks of an individual target.
   interval            = "30"
   # Protocol to use to connect with the target
   protocol            = "HTTP"
   #  Response codes to use when checking for a healthy responses from a target
   matcher             = "200"
   # Amount of time, in seconds, during which no response means a failed health check
   timeout             = "3"
   # Destination for the health check request
   path                = "/"
   # Number of consecutive health check failures required before considering the target unhealthy
   unhealthy_threshold = "2"
  }
}

resource "aws_alb_listener" "http" {
  load_balancer_arn = data.terraform_remote_state.ecs_cluster.outputs.alb_id
  port              = 80
  protocol          = "HTTP"
 
  default_action {
    target_group_arn = aws_alb_target_group.tg.id
    type             = "forward"
  }
}

resource "aws_ecs_task_definition" "rocket-chat" {
  family = "${var.name}-${var.environment}"

  container_definitions = <<TASK_DEFINITION
[
    {
        "cpu": ${var.cpu},
        "essential": true,
        "image": "rocket.chat:${var.app_version}",
        "memory": ${var.memory},
        "name": "${var.name}-${var.environment}",
        "portMappings": [{
          "containerPort": 3000,
          "hostPort": 0,
          "protocol": "tcp"
        }],
        "environment": [
          {"name": "MONGO_URL","value": "mongodb://mongo-${var.environment}.acme-ltd-${var.environment}.local:27017/mydb"},
          {"name": "MONGO_OPLOG_URL","value": "mongodb://mongo-${var.environment}.acme-ltd-${var.environment}.local:27017/local"},
          {"name": "BYPASS_OPLOG_VALIDATION","value": "true"}
        ]
    }
]
TASK_DEFINITION
}

resource "aws_ecs_service" "rocket-chat" {
  name          = "${var.name}-${var.environment}"
  cluster       = data.terraform_remote_state.ecs_cluster.outputs.ecs_cluster_id
  desired_count = "${var.task_count}"
  task_definition = aws_ecs_task_definition.rocket-chat.arn

  load_balancer {
    target_group_arn = aws_alb_target_group.tg.id
    container_port = 3000
    container_name = "${var.name}-${var.environment}"
  }

  ordered_placement_strategy {
    type  = "spread"
    field = "host"
  }
}
