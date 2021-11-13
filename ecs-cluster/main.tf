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

# Create ECS Cluster

resource "aws_ecs_cluster" "ecs_cluster" {
    name  = "${var.name}-${var.environment}-ecs-cluster"
}

# Create IAM Role and attach policies for the instances in the autoscaling group to use 
# to be able to use the ecs service.
# SSM policy also attached so that ssm can be used to login to the server through aws web

resource "aws_iam_role" "ecs_agent" {
  name               = "${var.name}-${var.environment}-ecs-ec2-instance-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_agent" {
  role       = aws_iam_role.ecs_agent.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ec2_ssm_policy" {
  role       = aws_iam_role.ecs_agent.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ecs_agent" {
  name = "${var.name}-${var.environment}-ecs-ec2-instance-profile"
  role = aws_iam_role.ecs_agent.name
}

# Security Groups For the Autoscaling Group Instances and for the Application Loadbalancer
# Rules are added to open connectivity between alb and ecs cluster ec2 instances

resource "aws_security_group" "alb_sg" {
    vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id
    name = "${var.name}-${var.environment}-alb_sg"
    ingress {
        from_port       = 80
        to_port         = 80
        protocol        = "tcp"
        cidr_blocks     = ["0.0.0.0/0"]
    }
}

resource "aws_security_group" "ecs_asg_sg" {
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id
  name = "${var.name}-${var.environment}-ecs_asg_sg"
  egress {
      from_port       = 80
      to_port         = 80
      protocol        = "tcp"
      cidr_blocks     = ["0.0.0.0/0"]
  }
  egress {
      from_port       = 443
      to_port         = 443
      protocol        = "tcp"
      cidr_blocks     = ["0.0.0.0/0"]
  }
  # To access mongodb container
  egress {
    from_port = 27017
    to_port = 27017
    protocol = "tcp"
    cidr_blocks     = data.terraform_remote_state.vpc.outputs.private_subnet_ips
  }
  # To access nfs mount
  egress {
    from_port = 2049
    to_port = 2049
    protocol = "tcp"
    cidr_blocks     = data.terraform_remote_state.vpc.outputs.private_subnet_ips
  }
}

resource "aws_security_group_rule" "alb_sg_rule_1" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  source_security_group_id = aws_security_group.ecs_asg_sg.id
  security_group_id = aws_security_group.alb_sg.id
}

resource "aws_security_group_rule" "ecs_asg_sg_rule_1" {
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  source_security_group_id = aws_security_group.alb_sg.id
  security_group_id = aws_security_group.ecs_asg_sg.id
}


# Create autoscaling group for ecs. Take note of the launch configuration which is used
# add the ec2 instances to the ecs cluster that you created above
# SSM agent is also installed

resource "aws_launch_configuration" "ecs_launch_config" {
    name_prefix          = "${var.name}-${var.environment}-ecs-lc-"
    image_id             = var.ecs_ec2_instance_ami
    iam_instance_profile = aws_iam_instance_profile.ecs_agent.name
    security_groups      = [aws_security_group.ecs_asg_sg.id]
    instance_type        = var.ecs_ec2_instance_type

    lifecycle {
      create_before_destroy = true
    }

    user_data            = <<EOF
#!/bin/bash
mkdir /tmp/ssm
cd /tmp/ssm
wget https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_amd64/amazon-ssm-agent.deb
sudo dpkg -i amazon-ssm-agent.deb
sudo systemctl enable amazon-ssm-agent
echo ECS_CLUSTER=${var.name}-${var.environment}-ecs-cluster >> /etc/ecs/ecs.config
EOF
}

resource "aws_autoscaling_group" "ecs_asg" {
    name                      = aws_launch_configuration.ecs_launch_config.name
    vpc_zone_identifier       = data.terraform_remote_state.vpc.outputs.private_subnet_ids
    launch_configuration      = aws_launch_configuration.ecs_launch_config.name

    desired_capacity          = var.asg_desired_size
    min_size                  = var.asg_min_size
    max_size                  = var.asg_max_size
    # When an instance launches, Amazon EC2 Auto Scaling uses the value of the HealthCheckGracePeriod for the 
    # Auto Scaling group to determine how long to wait before checking the health status of the instance
    health_check_grace_period = 300
    health_check_type         = "EC2"

    tag {
        key                 = "Name"
        value               = "${var.name}-${var.environment}-ecs-asg-ec2"
        propagate_at_launch = true
    }

    tag {
        key                 = "Environment"
        value               = var.environment
        propagate_at_launch = true
    }

    lifecycle {
      create_before_destroy = true
    }
}

# Create Internet Facing Application Loadbalancer to be used with ecs applications

resource "aws_lb" "alb" {
  name               = "${var.name}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = data.terraform_remote_state.vpc.outputs.public_subnet_ids
}

#Create Namespace for service discovery

resource "aws_service_discovery_private_dns_namespace" "ecs_service_discovery" {
  name        = "${var.name}-${var.environment}.local"
  vpc      = data.terraform_remote_state.vpc.outputs.vpc_id
}

# Create EFS File Storage to be used by applications which need persistent storage
# backends like databases. Security groups required for this aws resource is also
# created here. An access point is created so that the mongodb application has access
# to the folder /mongodb and not the entire efs root

resource "aws_security_group" "ecs_efs_sg" {
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id
  name = "${var.name}-${var.environment}-efs_ecs_sg"

  ingress {
    from_port = 2049
    to_port = 2049
    protocol = "tcp"
    security_groups = [
      aws_security_group.ecs_asg_sg.id
    ]
  }
}

resource "aws_efs_file_system" "ecs_efs_storage" {
  creation_token = "${var.name}-${var.environment}-efs-store"

  tags = {
    Name = "${var.name}-${var.environment}-efs-store"
  }
}

resource "aws_efs_mount_target" "ecs_efs_mount_targets" {
  file_system_id = aws_efs_file_system.ecs_efs_storage.id
  subnet_id      = element(data.terraform_remote_state.vpc.outputs.private_subnet_ids, count.index)
  count             = length(data.terraform_remote_state.vpc.outputs.private_subnet_ids)
  security_groups  = [ aws_security_group.ecs_efs_sg.id ]
}

resource "aws_efs_access_point" "ecs_mongodb_efs_access_point" {
  file_system_id = aws_efs_file_system.ecs_efs_storage.id

  posix_user {
    uid = "999"
    gid = "999"
  }

  root_directory {
    path = "/mongodb"
    creation_info {
      owner_uid   = "999"
      owner_gid   = "999"
      permissions = "775"
    }
  }

  tags = {
    Name = "${var.environment}-mongodb"
  }
}

# Output Section

output "ecs_cluster_id" {
  value = aws_ecs_cluster.ecs_cluster.id
}

output "alb_id" {
  value = aws_lb.alb.id
}

output "ecs_asg_sg_id" {
  value = aws_security_group.ecs_asg_sg.id
}

output "service_discovery_namespace_id" {
  value = aws_service_discovery_private_dns_namespace.ecs_service_discovery.id
}

output "efs_storage_id" {
  value = aws_efs_file_system.ecs_efs_storage.id
}

output "efs_storage_arn" {
  value = aws_efs_file_system.ecs_efs_storage.arn
}

output "mongodb_efs_access_point_id" {
  value = aws_efs_access_point.ecs_mongodb_efs_access_point.id
}

output "mongodb_efs_access_point_arn" {
  value = aws_efs_access_point.ecs_mongodb_efs_access_point.arn
}