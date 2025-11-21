# Terraform 인프라 설계

## 목차
- [Terraform 개요](#terraform-개요)
- [프로젝트 구조](#프로젝트-구조)
- [주요 리소스 설계](#주요-리소스-설계)
- [Terraform 코드 예시](#terraform-코드-예시)
- [실행 방법](#실행-방법)

---

## Terraform 개요

### Terraform이란?
- **Infrastructure as Code (IaC)** 도구
- 인프라를 코드로 정의하고 버전 관리 가능
- 선언적 구문으로 원하는 상태를 정의하면 Terraform이 자동으로 생성/수정/삭제

### 왜 Terraform을 사용하는가?

**장점:**
- 인프라를 코드로 관리 (버전 관리, 리뷰, 재사용)
- 수동 설정 오류 방지
- 환경 복제 용이 (dev, staging, prod)
- 변경 사항을 미리 확인 가능 (`terraform plan`)
- AWS 콘솔에서 클릭하는 것보다 빠르고 정확

---

## 프로젝트 구조

```
terraform/
├── main.tf                 # 메인 설정 파일
├── variables.tf            # 변수 정의
├── outputs.tf              # 출력 값 정의
├── terraform.tfvars        # 변수 값 설정 (환경별)
├── provider.tf             # AWS Provider 설정
│
├── modules/                # 모듈 디렉토리
│   ├── vpc/               # VPC 관련 리소스
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── ecs/               # ECS Cluster & Service
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── alb/               # Application Load Balancer
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── ecr/               # ECR Repository
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── iam/               # IAM Roles & Policies
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── rds/               # RDS MySQL Database
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   └── codedeploy/        # CodeDeploy for Blue/Green
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
│
└── environments/           # 환경별 설정
    ├── dev/
    │   └── terraform.tfvars
    ├── staging/
    │   └── terraform.tfvars
    └── prod/
        └── terraform.tfvars
```

---

## 주요 리소스 설계

### 1. VPC (Virtual Private Cloud)

**구성 요소:**
- VPC (CIDR: 10.0.0.0/16)
- Public Subnet x 2 (가용 영역 분산)
- Private Subnet x 2 (가용 영역 분산)
- Internet Gateway (IGW)
- NAT Gateway x 2 (고가용성)
- Route Tables

**설계 이유:**
- Public Subnet: ALB 배치 (인터넷 접근 가능)
- Private Subnet: ECS Task 배치 (보안 강화)
- Multi-AZ: 가용성 향상

---

### 2. ECS (Elastic Container Service)

**구성 요소:**
- ECS Cluster
- ECS Service (Fargate)
- Task Definition
- Auto Scaling Policy

**주요 설정:**
```
Launch Type: Fargate (서버리스)
CPU: 256, 512, 1024, 2048 (선택)
Memory: 512MB, 1GB, 2GB, 4GB (선택)
Desired Count: 2 (최소 가용성)
Deployment Type: Blue/Green (CodeDeploy)
```

---

### 3. ECR (Elastic Container Registry)

**구성 요소:**
- ECR Repository (Docker 이미지 저장)
- Lifecycle Policy (오래된 이미지 자동 삭제)

**설계:**
```
Repository 이름: my-app-backend, my-app-frontend
이미지 태그: latest, v1.0.0, commit-sha
보관 정책: 최근 10개 이미지만 유지
```

---

### 4. ALB (Application Load Balancer)

**구성 요소:**
- Application Load Balancer
- Target Group (Blue)
- Target Group (Green)
- Listener (HTTP/HTTPS)
- Security Group

**설계:**
```
Listener:
  - Port 80 (HTTP) → Port 443 리다이렉트
  - Port 443 (HTTPS) → Target Group

Health Check:
  - Path: /health
  - Interval: 30s
  - Timeout: 5s
  - Healthy Threshold: 2
  - Unhealthy Threshold: 2
```

---

### 5. IAM (Identity and Access Management)

**필요한 Role:**

1. **ECS Task Execution Role**
   - ECR에서 이미지 Pull 권한
   - CloudWatch Logs 쓰기 권한

2. **ECS Task Role**
   - 애플리케이션이 필요한 AWS 서비스 접근 권한
   - 예: S3, DynamoDB, RDS 등

3. **CodeDeploy Service Role**
   - Blue/Green 배포 실행 권한

---

### 6. RDS (MySQL Database)

**구성 요소:**
- RDS MySQL 8.0 Instance
- DB Subnet Group (Private Subnets)
- Security Group (ECS에서만 3306 접근 허용)
- Secrets Manager (DB 비밀번호 저장)

**주요 설정:**
```
Engine: MySQL 8.0
Instance Class: db.t3.micro (프리 티어)
Storage: 20GB gp2
Multi-AZ: false (개발), true (프로덕션)
Backup Retention: 1일 (프리 티어)
```

**보안:**
- Private Subnet에 배치 (외부 접근 차단)
- ECS Security Group에서만 접근 가능
- 비밀번호는 Secrets Manager에 자동 생성/저장

---

### 7. CodeDeploy (Blue/Green 배포)

**구성 요소:**
- CodeDeploy Application
- CodeDeploy Deployment Group
- Deployment Configuration

**배포 설정:**
```
Deployment Type: Blue/Green
Traffic Routing:
  - Canary: 10% → 대기 → 100%
  - Linear: 10%씩 증가
  - All-at-once: 즉시 100%

Rollback:
  - 자동 롤백: Health Check 실패 시
  - 수동 롤백: 언제든지 가능
```

---

## Terraform 코드 예시

### provider.tf

```hcl
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Terraform State를 S3에 저장 (팀 협업 시)
  # 초기 테스트는 로컬 State 사용 (아래 backend 블록 주석 처리)
  # backend "s3" {
  #   bucket         = "my-terraform-state-bucket"
  #   key            = "prod/terraform.tfstate"
  #   region         = "ap-northeast-2"
  #   encrypt        = true
  #   dynamodb_table = "terraform-lock"
  # }
}

provider "aws" {
  region = var.aws_region
}
```

---

### variables.tf

```hcl
variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "my-app"
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

variable "ecs_task_cpu" {
  description = "ECS Task CPU units"
  type        = string
  default     = "256"
}

variable "ecs_task_memory" {
  description = "ECS Task Memory (MB)"
  type        = string
  default     = "512"
}

variable "desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 2
}
```

---

### modules/vpc/main.tf

```hcl
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project_name}-vpc"
    Environment = var.environment
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-public-subnet-${count.index + 1}"
    Environment = var.environment
  }
}

# Private Subnets
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name        = "${var.project_name}-private-subnet-${count.index + 1}"
    Environment = var.environment
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-igw"
    Environment = var.environment
  }
}

# NAT Gateway
resource "aws_eip" "nat" {
  count  = 2
  domain = "vpc"

  tags = {
    Name        = "${var.project_name}-nat-eip-${count.index + 1}"
    Environment = var.environment
  }
}

resource "aws_nat_gateway" "main" {
  count         = 2
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name        = "${var.project_name}-nat-${count.index + 1}"
    Environment = var.environment
  }
}
```

---

### modules/ecs/main.tf

```hcl
# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name        = "${var.project_name}-cluster"
    Environment = var.environment
  }
}

# Task Definition
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.project_name}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = "${var.ecr_repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.project_name}"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      environment = [
        {
          name  = "ENVIRONMENT"
          value = var.environment
        }
      ]
    }
  ])
}

# ECS Service
resource "aws_ecs_service" "app" {
  name            = "${var.project_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "app"
    container_port   = 8080
  }

  depends_on = [var.alb_listener]
}

# Auto Scaling
resource "aws_appautoscaling_target" "ecs" {
  max_capacity       = 10
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_cpu" {
  name               = "${var.project_name}-cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
}
```

---

### modules/alb/main.tf

```hcl
# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  tags = {
    Name        = "${var.project_name}-alb"
    Environment = var.environment
  }
}

# Target Group (Blue)
resource "aws_lb_target_group" "blue" {
  name        = "${var.project_name}-tg-blue"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
  }

  tags = {
    Name        = "${var.project_name}-tg-blue"
    Environment = var.environment
  }
}

# Target Group (Green)
resource "aws_lb_target_group" "green" {
  name        = "${var.project_name}-tg-green"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
  }

  tags = {
    Name        = "${var.project_name}-tg-green"
    Environment = var.environment
  }
}

# Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue.arn
  }
}
```

---

### modules/ecr/main.tf

```hcl
resource "aws_ecr_repository" "app" {
  name                 = "${var.project_name}-repository"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "${var.project_name}-ecr"
    Environment = var.environment
  }
}

# Lifecycle Policy (오래된 이미지 자동 삭제)
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Remove untagged images older than 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "any"
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
```

---

## 실행 방법

### 1. 초기 설정

```bash
# Terraform 초기화 (플러그인 다운로드)
terraform init

# 작업 공간 생성 (환경별 관리)
terraform workspace new prod
terraform workspace select prod
```

---

### 2. 인프라 계획 확인

```bash
# 변경 사항 미리 보기
terraform plan

# 특정 환경 변수 파일 사용
terraform plan -var-file="environments/prod/terraform.tfvars"
```

---

### 3. 인프라 생성

```bash
# 인프라 생성
terraform apply

# 자동 승인 (주의: 프로덕션에서는 권장하지 않음)
terraform apply -auto-approve
```

---

### 4. 인프라 확인

```bash
# 생성된 리소스 확인
terraform show

# 특정 출력 값만 확인
terraform output
terraform output alb_dns_name
```

---

### 5. 인프라 삭제

```bash
# 인프라 삭제 (개발 환경에서만)
terraform destroy

# 특정 리소스만 삭제
terraform destroy -target=aws_ecs_service.app
```

---

## 주요 명령어 요약

```bash
terraform init        # 초기화
terraform validate    # 문법 검증
terraform fmt         # 코드 포맷팅
terraform plan        # 변경 사항 미리 보기
terraform apply       # 인프라 생성/수정
terraform destroy     # 인프라 삭제
terraform show        # 현재 상태 확인
terraform output      # 출력 값 확인
terraform state list  # 관리 중인 리소스 목록
```

---

## 베스트 프랙티스

### 1. State 파일 관리
- S3 + DynamoDB로 원격 저장
- 팀원 간 State 공유
- State Lock으로 동시 수정 방지

### 2. 환경 분리
- dev, staging, prod 환경 분리
- Workspace 또는 별도 디렉토리 사용

### 3. 모듈화
- 재사용 가능한 모듈 작성
- 입력/출력 명확히 정의

### 4. 변수 관리
- 민감한 정보는 환경 변수 또는 AWS Secrets Manager 사용
- `.tfvars` 파일은 `.gitignore`에 추가

### 5. 버전 관리
- Terraform 버전 고정
- Provider 버전 명시

---

## 다음 단계

Terraform으로 인프라를 구축한 후:
- [03-github-actions-ci-cd.md](./03-github-actions-ci-cd.md) - GitHub Actions로 CI/CD 구성
