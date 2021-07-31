terraform {
  backend "s3" {
    bucket = "ecs-project-production-terraform-state"
    key    = "vpc/tf.state"
    region = "us-west-2"
  }
}

variable "cidr" {
  default = "10.10.0.0/16"
  description = "The CIDR block for the VPC."
}

variable "name" {
  default = "ACME-Ltd"
  description = "The name of your stack/company"
}

variable "environment" {
  default = "production"
  description = "The name of your environment"
}

variable "availability_zones" {
  type    = list(string)
  default = ["us-west-2a", "us-west-2b", "us-west-2c"]
  description = "List of availability zones"
}

variable "private_subnets" {
  type    = list(string)
  default = ["10.10.1.0/24", "10.10.2.0/24", "10.10.3.0/24"]
  description = "List of private subnets"
}

variable "public_subnets" {
  type    = list(string)
  default = ["10.10.4.0/24", "10.10.5.0/24", "10.10.6.0/24"]
  description = "List of public subnets"
}