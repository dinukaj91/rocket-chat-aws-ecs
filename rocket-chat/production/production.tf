terraform {
  backend "s3" {
    bucket = "ecs-project-production-terraform-state"
    key    = "rocket-chat/tf.state"
    region = "us-west-2"
  }
}

variable "aws_region" {
  default = "us-west-2"
  description = "The name of your region"
}

variable "environment" {
  default = "production"
  description = "The name of your environment"
}

variable "name" {
  default = "rocket-chat"
  description = "The name of your application"
}

variable "app_version" {
  default = "3.13.1"
  description = "version of rocket chat"
}

variable "cpu" {
  default = "1"
  description = "cpu assigned per task"
}

variable "memory" {
  default = "2048"
  description = "memory assigned per task"
}

variable "task_count" {
  default = "4"
  description = "number of tasks"
}