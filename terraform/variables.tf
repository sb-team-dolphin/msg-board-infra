variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "myapp"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability Zones"
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2c"]
}

# ECS Configuration
variable "ecs_backend_cpu" {
  description = "Backend ECS Task CPU units"
  type        = string
  default     = "256"  # 0.25 vCPU
}

variable "ecs_backend_memory" {
  description = "Backend ECS Task Memory (MB)"
  type        = string
  default     = "512"  # 512 MB
}

variable "ecs_frontend_cpu" {
  description = "Frontend ECS Task CPU units"
  type        = string
  default     = "256"
}

variable "ecs_frontend_memory" {
  description = "Frontend ECS Task Memory (MB)"
  type        = string
  default     = "512"
}

variable "backend_desired_count" {
  description = "Desired number of backend tasks"
  type        = number
  default     = 2
}

variable "frontend_desired_count" {
  description = "Desired number of frontend tasks"
  type        = number
  default     = 2
}

variable "backend_container_port" {
  description = "Backend container port"
  type        = number
  default     = 8080
}

variable "frontend_container_port" {
  description = "Frontend container port"
  type        = number
  default     = 80
}

# Auto Scaling
variable "backend_min_capacity" {
  description = "Minimum number of backend tasks"
  type        = number
  default     = 1
}

variable "backend_max_capacity" {
  description = "Maximum number of backend tasks"
  type        = number
  default     = 10
}

variable "frontend_min_capacity" {
  description = "Minimum number of frontend tasks"
  type        = number
  default     = 1
}

variable "frontend_max_capacity" {
  description = "Maximum number of frontend tasks"
  type        = number
  default     = 10
}

variable "cpu_target_value" {
  description = "Target CPU utilization for auto scaling"
  type        = number
  default     = 70
}

variable "memory_target_value" {
  description = "Target memory utilization for auto scaling"
  type        = number
  default     = 80
}

# RDS Configuration
variable "db_name" {
  description = "Database name"
  type        = string
  default     = "myappdb"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "admin"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = false
}
