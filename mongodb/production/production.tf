terraform {
  backend "s3" {
    bucket = "ecs-project-production-terraform-state"
    key    = "mongodb/tf.state"
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
  default = "mongo"
  description = "The name of your application"
}

variable "app_version" {
  default = "latest"
  description = "version of mongo"
}

variable "cpu" {
  default = "1"
  description = "cpu assigned per task"
}

variable "memory" {
  default = "2048"
  description = "memory assigned per task"
}