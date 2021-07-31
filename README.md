# Rocket Chat Application Running on ECS

The infrastructure that this application is running on uses the following technologies:

Amazon ECS
Auto Scaling Groups
Service Discovery
ELastic File System
MongoDB

In order to bring up the infrastructure you will have to clone this repo into your workspace and run the terraform init and terraform apply commands in the folder in the order given below.

First you need to bring up the aws vpc, subnets, nat gateways and internet gateways required to run the infra strcuture on.
This can be done by running the terraform init/apply in the commands vpc/production folder

Secondly you need to bring up the ecs cluster and the rest of the components needed to run an application.
This can be done by running the terraform init/apply commands in the ecs-cluster/production folder.
This command brings up an ecs cluster which uses an auto scaling group and an intenet facing load balancer to run/access its tasks and services.
It also creates a service discovery namespace used to connect to the mongodb database.

Third you can bring up the mongodb task by running the terraform init/apply commands in the mongodb/production folder.
This pulls a mongodb image from docker hub and starts a mongodb service/task in the ecs cluster created in the second step.
This task uses efs as a file storage option to store the db files to prevent data loss if the mongodb task fails and restarts.
It creates security groups to ensure connectivity from mthe rocket chat application.
It also creates a service discover service which is a dns record which can be used by the rocket chat application to connec to this mongodb task.
Wait a few minutes for the db to come up and move to the final step.

Finaly you can bring up the rocket-chat application by running the terraform init/apply commands in the rocket-chat/production folder
This pulls a rocket chat image from docker hub and starts a rocket chat service/task in the ecs cluster created in the second step.
It also creats a target group and a load balancer listener used to connect to the application by users.
You can use the dns name of the load balancer to connec to the application.
