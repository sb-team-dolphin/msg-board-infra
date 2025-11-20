variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private Subnet IDs"
  type        = list(string)
}

variable "task_execution_role_arn" {
  description = "ECS Task Execution Role ARN"
  type        = string
}

variable "task_role_arn" {
  description = "ECS Task Role ARN"
  type        = string
}

variable "backend_ecr_url" {
  description = "Backend ECR Repository URL"
  type        = string
}

variable "frontend_ecr_url" {
  description = "Frontend ECR Repository URL"
  type        = string
}

variable "backend_target_group_arn" {
  description = "Backend Target Group ARN"
  type        = string
}

variable "frontend_target_group_arn" {
  description = "Frontend Target Group ARN"
  type        = string
}

variable "ecs_security_group_id" {
  description = "ECS Tasks Security Group ID"
  type        = string
}

variable "backend_cpu" {
  description = "Backend CPU units"
  type        = string
}

variable "backend_memory" {
  description = "Backend Memory (MB)"
  type        = string
}

variable "frontend_cpu" {
  description = "Frontend CPU units"
  type        = string
}

variable "frontend_memory" {
  description = "Frontend Memory (MB)"
  type        = string
}

variable "backend_desired_count" {
  description = "Backend desired task count"
  type        = number
}

variable "frontend_desired_count" {
  description = "Frontend desired task count"
  type        = number
}

variable "backend_container_port" {
  description = "Backend container port"
  type        = number
}

variable "frontend_container_port" {
  description = "Frontend container port"
  type        = number
}

variable "backend_min_capacity" {
  description = "Backend minimum capacity"
  type        = number
}

variable "backend_max_capacity" {
  description = "Backend maximum capacity"
  type        = number
}

variable "frontend_min_capacity" {
  description = "Frontend minimum capacity"
  type        = number
}

variable "frontend_max_capacity" {
  description = "Frontend maximum capacity"
  type        = number
}

variable "cpu_target_value" {
  description = "CPU target value for autoscaling"
  type        = number
}

variable "memory_target_value" {
  description = "Memory target value for autoscaling"
  type        = number
}

# RDS Configuration
variable "db_host" {
  description = "RDS hostname"
  type        = string
  default     = ""
}

variable "db_port" {
  description = "RDS port"
  type        = number
  default     = 3306
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = ""
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = ""
}

variable "db_secret_arn" {
  description = "Secrets Manager ARN for DB password"
  type        = string
  default     = ""
}
