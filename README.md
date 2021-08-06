# Rocket Chat Application Running on Amazon ECS

This terraform code can be used to bring up a rocket chat application and all the components required for it to function.

## Technology Used

Amazon ECS

Auto Scaling Groups

Service Discovery

ELastic File System

MongoDB

Application Loadbalancer

## Bringing Up The Application

First you will have to generate an iam user which can be used to run the terraform commands on your aws cloud environment and export it to your workspace.

Then you need to create an s3 bucket in your aws account and update the terraform backend section in the production.tf file with the name of this bucket in each of the folders that are given in the steps below.

The aws_region variable needs to be updated as well in the production.tf files to match your region.

In order to bring up the infrastructure you will have to clone this repo into your workspace and run the terraform init and terraform apply commands in the given folder in the order given below.

### Step 1: Create the Underlying infrastructure

First you need to bring up the aws vpc, subnets, nat gateways and internet gateways required to run the infra strcuture on.
This can be done by running the terraform init/apply in the commands vpc/production folder.

### Step 2: Create the ECS Cluster and other required components used by ECS

Secondly you need to bring up the ecs cluster and the rest of the components needed to run an application.
This can be done by running the terraform init/apply commands in the ecs-cluster/production folder.
This command brings up an ecs cluster which uses an auto scaling group and an intenet facing load balancer to run/access its tasks and services.
It also creates a service discovery namespace used to connect to the mongodb database and an EFS storage service used by the mongodb task to store its database files.

### Step 3: Create the Mongodb Task and the Service Discovery service

Third you can bring up the mongodb task by running the terraform init/apply commands in the mongodb/production folder.
This pulls a mongodb image from docker hub and starts a mongodb service/task in the ecs cluster created in the second step.
This task uses efs as a file storage option to store the db files to prevent data loss if the mongodb task fails and restarts.
It creates security groups to ensure connectivity from the rocket chat application.
It also creates a service discover service which is a dns record which can be used by the rocket chat application to connec to this mongodb task.
Wait a few minutes for the db to come up and move to the final step.

### Step 4: Rocket Chat and Application Loadbalancer Listener

Finaly you can bring up the rocket-chat application by running the terraform init/apply commands in the rocket-chat/production folder.
This pulls a rocket chat image from docker hub and starts a rocket chat service/task in the ecs cluster created in the second step.
It also creats a target group and a load balancer listener used to connect to the application by users.
You can use the dns name of the load balancer to connec to rocket chat.

## Cleaning Up

To cleanup the infrastucture that you created above.
You can cd into the folders in the order given below and run the terraform destroy command.

rocket-chat/production

mongodb/production

ecs-cluster/production

vpc/production

Finaly you can delete the iam user and the s3 bucket that you used initialy created to wipe out this deployment completely from you aws account.

