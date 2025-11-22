# CodeDeploy Application for Backend
# 이름 형식: AppECS-{cluster}-{service} (aws-actions/amazon-ecs-deploy-task-definition 호환)
resource "aws_codedeploy_app" "backend" {
  compute_platform = "ECS"
  name             = "AppECS-${var.ecs_cluster_name}-${var.backend_service_name}"
}

# CodeDeploy Deployment Group for Backend
# 이름 형식: DgpECS-{cluster}-{service} (aws-actions/amazon-ecs-deploy-task-definition 호환)
resource "aws_codedeploy_deployment_group" "backend" {
  app_name               = aws_codedeploy_app.backend.name
  deployment_group_name  = "DgpECS-${var.ecs_cluster_name}-${var.backend_service_name}"
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"
  service_role_arn       = var.codedeploy_role_arn

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  ecs_service {
    cluster_name = var.ecs_cluster_name
    service_name = var.backend_service_name
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [var.http_listener_arn]
      }

      target_group {
        name = var.backend_target_group_name
      }

      target_group {
        name = var.backend_target_group_green_name
      }
    }
  }

  tags = {
    Name = "${var.project_name}-backend-dg"
  }
}
