variable "project_name" {
  description = "Project name"
  type        = string
}

variable "codedeploy_role_arn" {
  description = "CodeDeploy IAM Role ARN"
  type        = string
}

variable "ecs_cluster_name" {
  description = "ECS Cluster Name"
  type        = string
}

variable "backend_service_name" {
  description = "Backend ECS Service Name"
  type        = string
}

variable "frontend_service_name" {
  description = "Frontend ECS Service Name"
  type        = string
}

variable "http_listener_arn" {
  description = "HTTP Listener ARN"
  type        = string
}

variable "backend_target_group_name" {
  description = "Backend Target Group Name (Blue)"
  type        = string
}

variable "backend_target_group_green_name" {
  description = "Backend Target Group Name (Green)"
  type        = string
}

variable "frontend_target_group_name" {
  description = "Frontend Target Group Name (Blue)"
  type        = string
}

variable "frontend_target_group_green_name" {
  description = "Frontend Target Group Name (Green)"
  type        = string
}
