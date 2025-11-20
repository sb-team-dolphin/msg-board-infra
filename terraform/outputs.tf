output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public Subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private Subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "alb_dns_name" {
  description = "Application Load Balancer DNS name"
  value       = module.alb.alb_dns_name
}

output "alb_arn" {
  description = "Application Load Balancer ARN"
  value       = module.alb.alb_arn
}

output "ecr_backend_repository_url" {
  description = "Backend ECR Repository URL"
  value       = module.ecr.backend_repository_url
}

output "ecr_frontend_repository_url" {
  description = "Frontend ECR Repository URL"
  value       = module.ecr.frontend_repository_url
}

output "ecs_cluster_name" {
  description = "ECS Cluster Name"
  value       = module.ecs.cluster_name
}

output "ecs_cluster_arn" {
  description = "ECS Cluster ARN"
  value       = module.ecs.cluster_arn
}

output "backend_service_name" {
  description = "Backend ECS Service Name"
  value       = module.ecs.backend_service_name
}

output "frontend_service_name" {
  description = "Frontend ECS Service Name"
  value       = module.ecs.frontend_service_name
}

output "backend_task_definition_family" {
  description = "Backend Task Definition Family"
  value       = module.ecs.backend_task_definition_family
}

output "frontend_task_definition_family" {
  description = "Frontend Task Definition Family"
  value       = module.ecs.frontend_task_definition_family
}

output "cloudwatch_log_group_backend" {
  description = "CloudWatch Log Group for Backend"
  value       = "/ecs/${var.project_name}-backend"
}

output "cloudwatch_log_group_frontend" {
  description = "CloudWatch Log Group for Frontend"
  value       = "/ecs/${var.project_name}-frontend"
}

# RDS Outputs
output "rds_endpoint" {
  description = "RDS endpoint"
  value       = module.rds.db_endpoint
}

output "rds_address" {
  description = "RDS hostname"
  value       = module.rds.db_address
}

output "rds_secret_arn" {
  description = "Secrets Manager secret ARN for DB credentials"
  value       = module.rds.db_secret_arn
}

# 배포 시 필요한 정보 요약
output "deployment_info" {
  description = "Deployment information summary"
  value = {
    alb_url                      = "http://${module.alb.alb_dns_name}"
    backend_api_url              = "http://${module.alb.alb_dns_name}/api/users"
    backend_health_url           = "http://${module.alb.alb_dns_name}/health"
    ecr_backend_repo             = module.ecr.backend_repository_url
    ecr_frontend_repo            = module.ecr.frontend_repository_url
    ecs_cluster                  = module.ecs.cluster_name
    backend_service              = module.ecs.backend_service_name
    frontend_service             = module.ecs.frontend_service_name
    cloudwatch_backend_logs_cmd  = "aws logs tail /ecs/${var.project_name}-backend --follow"
    cloudwatch_frontend_logs_cmd = "aws logs tail /ecs/${var.project_name}-frontend --follow"
    rds_endpoint                 = module.rds.db_endpoint
    rds_secret_arn               = module.rds.db_secret_arn
  }
}
