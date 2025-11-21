# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
}

# IAM Module
module "iam" {
  source = "./modules/iam"

  project_name = var.project_name
  environment  = var.environment
}

# ECR Module
module "ecr" {
  source = "./modules/ecr"

  project_name = var.project_name
  environment  = var.environment
}

# ALB Module
module "alb" {
  source = "./modules/alb"

  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  backend_port       = var.backend_container_port
  frontend_port      = var.frontend_container_port
}

# ECS Security Group (공유용 - 순환 의존성 해결)
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project_name}-ecs-tasks-sg"
  description = "Security group for ECS tasks"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [module.alb.alb_security_group_id]
    description     = "Allow traffic from ALB"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.project_name}-ecs-tasks-sg"
  }
}

# RDS Module
module "rds" {
  source = "./modules/rds"

  project_name          = var.project_name
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  ecs_security_group_id = aws_security_group.ecs_tasks.id
  db_name               = var.db_name
  db_username           = var.db_username
  db_instance_class     = var.db_instance_class
  db_allocated_storage  = var.db_allocated_storage
  multi_az              = var.db_multi_az
}

# ECS Module
module "ecs" {
  source = "./modules/ecs"

  project_name              = var.project_name
  environment               = var.environment
  vpc_id                    = module.vpc.vpc_id
  private_subnet_ids        = module.vpc.private_subnet_ids

  # IAM Roles
  task_execution_role_arn   = module.iam.ecs_task_execution_role_arn
  task_role_arn             = module.iam.ecs_task_role_arn

  # ECR
  backend_ecr_url           = module.ecr.backend_repository_url
  frontend_ecr_url          = module.ecr.frontend_repository_url

  # ALB
  backend_target_group_arn  = module.alb.backend_target_group_arn
  frontend_target_group_arn = module.alb.frontend_target_group_arn
  ecs_security_group_id     = aws_security_group.ecs_tasks.id

  # ECS Configuration
  backend_cpu               = var.ecs_backend_cpu
  backend_memory            = var.ecs_backend_memory
  frontend_cpu              = var.ecs_frontend_cpu
  frontend_memory           = var.ecs_frontend_memory
  backend_desired_count     = var.backend_desired_count
  frontend_desired_count    = var.frontend_desired_count
  backend_container_port    = var.backend_container_port
  frontend_container_port   = var.frontend_container_port

  # Auto Scaling
  backend_min_capacity      = var.backend_min_capacity
  backend_max_capacity      = var.backend_max_capacity
  frontend_min_capacity     = var.frontend_min_capacity
  frontend_max_capacity     = var.frontend_max_capacity
  cpu_target_value          = var.cpu_target_value
  memory_target_value       = var.memory_target_value

  # RDS Configuration
  db_host       = module.rds.db_address
  db_port       = module.rds.db_port
  db_name       = module.rds.db_name
  db_username   = module.rds.db_username
  db_secret_arn = module.rds.db_secret_arn

  depends_on = [module.alb, module.rds]
}

# CodeDeploy Module for Blue/Green Deployment
module "codedeploy" {
  source = "./modules/codedeploy"

  project_name        = var.project_name
  codedeploy_role_arn = module.iam.codedeploy_role_arn

  # ECS
  ecs_cluster_name      = module.ecs.cluster_name
  backend_service_name  = module.ecs.backend_service_name
  frontend_service_name = module.ecs.frontend_service_name

  # ALB
  http_listener_arn = module.alb.http_listener_arn

  # Target Groups
  backend_target_group_name        = module.alb.backend_target_group_name
  backend_target_group_green_name  = module.alb.backend_target_group_green_name
  frontend_target_group_name       = module.alb.frontend_target_group_name
  frontend_target_group_green_name = module.alb.frontend_target_group_green_name

  depends_on = [module.ecs]
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${var.project_name}-backend"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-backend-logs"
  }
}

resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/ecs/${var.project_name}-frontend"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-frontend-logs"
  }
}
