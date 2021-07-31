terraform {
  backend "s3" {
    bucket = "ecs-project-production-terraform-state"
    key    = "ecs_cluster/tf.state"
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
  default = "ACME-Ltd"
  description = "The name of your stack"
}

variable "ecs_ec2_instance_ami" {
  # AWS ECS Optimized image
  default = "ami-0661fc0d6b5edc528"
  description = "ami id for image used in the asg"
}

variable "ecs_ec2_instance_type" {
  default = "t3.xlarge"
  description = "ec2 instance to be used in the asg"
}

variable "asg_desired_size" {
  default = "3"
  description = "auto scaling group desired size"
}

variable "asg_min_size" {
  default = "3"
  description = "auto scaling group min size"
}

variable "asg_max_size" {
  default = "4"
  description = "auto scaling group max size"
}