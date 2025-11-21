output "backend_app_name" {
  description = "Backend CodeDeploy Application Name"
  value       = aws_codedeploy_app.backend.name
}

output "backend_deployment_group_name" {
  description = "Backend CodeDeploy Deployment Group Name"
  value       = aws_codedeploy_deployment_group.backend.deployment_group_name
}

output "frontend_app_name" {
  description = "Frontend CodeDeploy Application Name"
  value       = aws_codedeploy_app.frontend.name
}

output "frontend_deployment_group_name" {
  description = "Frontend CodeDeploy Deployment Group Name"
  value       = aws_codedeploy_deployment_group.frontend.deployment_group_name
}
