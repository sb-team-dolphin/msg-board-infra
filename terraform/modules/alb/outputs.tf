output "alb_arn" {
  description = "ALB ARN"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "ALB DNS Name"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "ALB Zone ID"
  value       = aws_lb.main.zone_id
}

output "alb_security_group_id" {
  description = "ALB Security Group ID"
  value       = aws_security_group.alb.id
}

output "backend_target_group_arn" {
  description = "Backend Target Group ARN"
  value       = aws_lb_target_group.backend.arn
}

output "backend_target_group_name" {
  description = "Backend Target Group Name"
  value       = aws_lb_target_group.backend.name
}

output "backend_target_group_green_arn" {
  description = "Backend Green Target Group ARN"
  value       = aws_lb_target_group.backend_green.arn
}

output "backend_target_group_green_name" {
  description = "Backend Green Target Group Name"
  value       = aws_lb_target_group.backend_green.name
}

output "frontend_target_group_arn" {
  description = "Frontend Target Group ARN"
  value       = aws_lb_target_group.frontend.arn
}

output "frontend_target_group_name" {
  description = "Frontend Target Group Name"
  value       = aws_lb_target_group.frontend.name
}

output "frontend_target_group_green_arn" {
  description = "Frontend Green Target Group ARN"
  value       = aws_lb_target_group.frontend_green.arn
}

output "frontend_target_group_green_name" {
  description = "Frontend Green Target Group Name"
  value       = aws_lb_target_group.frontend_green.name
}

output "http_listener_arn" {
  description = "HTTP Listener ARN"
  value       = aws_lb_listener.http.arn
}
