output "ecs_task_execution_role_arn" {
  description = "ECS Task Execution Role ARN"
  value       = aws_iam_role.ecs_task_execution_role.arn
}

output "ecs_task_execution_role_name" {
  description = "ECS Task Execution Role Name"
  value       = aws_iam_role.ecs_task_execution_role.name
}

output "ecs_task_role_arn" {
  description = "ECS Task Role ARN"
  value       = aws_iam_role.ecs_task_role.arn
}

output "ecs_task_role_name" {
  description = "ECS Task Role Name"
  value       = aws_iam_role.ecs_task_role.name
}

output "codedeploy_role_arn" {
  description = "CodeDeploy Service Role ARN"
  value       = aws_iam_role.codedeploy_role.arn
}

output "codedeploy_role_name" {
  description = "CodeDeploy Service Role Name"
  value       = aws_iam_role.codedeploy_role.name
}
