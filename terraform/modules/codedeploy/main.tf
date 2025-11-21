# CodeDeploy Application for Backend
resource "aws_codedeploy_app" "backend" {
  compute_platform = "ECS"
  name             = "${var.project_name}-backend"
}

# CodeDeploy Application for Frontend
resource "aws_codedeploy_app" "frontend" {
  compute_platform = "ECS"
  name             = "${var.project_name}-frontend"
}

# CodeDeploy Deployment Group for Backend
resource "aws_codedeploy_deployment_group" "backend" {
  app_name               = aws_codedeploy_app.backend.name
  deployment_group_name  = "${var.project_name}-backend-dg"
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

# CodeDeploy Deployment Group for Frontend
resource "aws_codedeploy_deployment_group" "frontend" {
  app_name               = aws_codedeploy_app.frontend.name
  deployment_group_name  = "${var.project_name}-frontend-dg"
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
    service_name = var.frontend_service_name
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [var.http_listener_arn]
      }

      target_group {
        name = var.frontend_target_group_name
      }

      target_group {
        name = var.frontend_target_group_green_name
      }
    }
  }

  tags = {
    Name = "${var.project_name}-frontend-dg"
  }
}
