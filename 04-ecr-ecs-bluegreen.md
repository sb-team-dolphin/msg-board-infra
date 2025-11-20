# ECR, ECS 및 Blue/Green 배포 설계

## 목차
- [Amazon ECR 개요](#amazon-ecr-개요)
- [Amazon ECS 개요](#amazon-ecs-개요)
- [Blue/Green 배포 개념](#bluegreen-배포-개념)
- [Blue/Green 배포 프로세스](#bluegreen-배포-프로세스)
- [ECS Task Definition](#ecs-task-definition)
- [CodeDeploy 설정](#codedeploy-설정)
- [모니터링 및 롤백](#모니터링-및-롤백)

---

## Amazon ECR 개요

### ECR이란?
**Amazon Elastic Container Registry**
- AWS에서 제공하는 완전 관리형 Docker 컨테이너 레지스트리
- Docker Hub와 유사하지만 AWS와 완벽 통합
- Private 저장소로 보안성 높음

### 주요 기능

#### 1. 이미지 저장 및 관리
```bash
# ECR 로그인
aws ecr get-login-password --region ap-northeast-2 | \
  docker login --username AWS --password-stdin <account-id>.dkr.ecr.ap-northeast-2.amazonaws.com

# 이미지 태깅
docker tag my-app:latest <account-id>.dkr.ecr.ap-northeast-2.amazonaws.com/my-app:latest
docker tag my-app:latest <account-id>.dkr.ecr.ap-northeast-2.amazonaws.com/my-app:v1.0.0

# 이미지 Push
docker push <account-id>.dkr.ecr.ap-northeast-2.amazonaws.com/my-app:latest
docker push <account-id>.dkr.ecr.ap-northeast-2.amazonaws.com/my-app:v1.0.0
```

#### 2. 이미지 스캔
- 보안 취약점 자동 검사
- Push 시 자동 스캔 가능

#### 3. Lifecycle Policy
```json
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Remove untagged images older than 7 days",
      "selection": {
        "tagStatus": "untagged",
        "countType": "sinceImagePushed",
        "countUnit": "days",
        "countNumber": 7
      },
      "action": {
        "type": "expire"
      }
    },
    {
      "rulePriority": 2,
      "description": "Keep last 10 images",
      "selection": {
        "tagStatus": "any",
        "countType": "imageCountMoreThan",
        "countNumber": 10
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
```

**주의:** `tagStatus=any` 규칙은 항상 가장 낮은 priority (높은 숫자)를 가져야 합니다.

---

## Amazon ECS 개요

### ECS란?
**Amazon Elastic Container Service**
- AWS의 완전 관리형 컨테이너 오케스트레이션 서비스
- Docker 컨테이너를 쉽게 실행, 중지, 관리

### ECS 주요 구성 요소

```
┌────────────────────────────────────────────────────────────┐
│                      ECS Cluster                            │
│  (논리적 컨테이너 그룹)                                     │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐  │
│  │              ECS Service                             │  │
│  │  (Task의 원하는 개수를 유지)                         │  │
│  │                                                      │  │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐   │  │
│  │  │   Task 1   │  │   Task 2   │  │   Task 3   │   │  │
│  │  │ (컨테이너)  │  │ (컨테이너)  │  │ (컨테이너)  │   │  │
│  │  └────────────┘  └────────────┘  └────────────┘   │  │
│  └─────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────┘
```

#### 1. Cluster
- 여러 ECS Service와 Task를 그룹화하는 논리적 단위

#### 2. Task Definition
- 컨테이너 실행을 위한 청사진 (Blueprint)
- Docker 이미지, CPU, 메모리, 환경 변수 등 정의

#### 3. Task
- Task Definition에 기반한 실행 중인 컨테이너 인스턴스

#### 4. Service
- 지정된 수의 Task를 항상 실행 상태로 유지
- Auto Scaling, Load Balancing 관리

---

### ECS Launch Types

#### 1. EC2 Launch Type
- EC2 인스턴스에 컨테이너 실행
- 서버 관리 필요 (패치, 스케일링 등)
- 비용 최적화 가능 (Reserved Instance, Spot Instance)

#### 2. Fargate Launch Type (권장)
- **서버리스 컨테이너 실행**
- EC2 인스턴스 관리 불필요
- 사용한 만큼만 비용 지불
- 운영 부담 최소화

**Fargate 장점:**
```
✅ 서버 관리 불필요
✅ 자동 스케일링
✅ 보안 패치 자동화
✅ 사용한 만큼만 과금
✅ Cold Start 없음
```

---

## Blue/Green 배포 개념

### Blue/Green 배포란?

```
┌─────────────────────────────────────────────────────────────┐
│  Before Deployment (Blue 환경에서 실행 중)                   │
│                                                              │
│  Users → ALB → [Blue Tasks] (v1.0.0)                        │
│                                                              │
│                [Green Tasks] (준비 중)                       │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  During Deployment (Green 배포)                             │
│                                                              │
│  Users → ALB → [Blue Tasks] (v1.0.0) ← 100% 트래픽         │
│                                                              │
│                [Green Tasks] (v1.1.0) ← Health Check 중     │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  Traffic Shifting (트래픽 전환)                              │
│                                                              │
│  Users → ALB → [Blue Tasks] (v1.0.0) ← 50% 트래픽          │
│              ↘                                               │
│                [Green Tasks] (v1.1.0) ← 50% 트래픽         │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  After Deployment (Green 환경으로 전환 완료)                 │
│                                                              │
│  Users → ALB → [Green Tasks] (v1.1.0) ← 100% 트래픽        │
│                                                              │
│                [Blue Tasks] (종료됨)                         │
└─────────────────────────────────────────────────────────────┘
```

---

### Blue/Green vs Rolling Update

| 구분 | Blue/Green | Rolling Update |
|------|-----------|----------------|
| **배포 속도** | 빠름 (즉시 전환) | 느림 (순차 교체) |
| **리소스 사용** | 2배 필요 (Blue + Green) | 최소 증가 |
| **롤백 속도** | 즉시 (트래픽만 전환) | 느림 (재배포) |
| **위험도** | 낮음 (문제 시 즉시 롤백) | 중간 |
| **비용** | 높음 (일시적) | 낮음 |
| **적합한 경우** | 프로덕션, 무중단 필수 | 개발/스테이징 |

---

### Blue/Green 배포의 장점

```
✅ 무중단 배포 (Zero Downtime)
✅ 즉시 롤백 가능 (단순히 트래픽만 되돌림)
✅ 프로덕션 환경에서 실제 테스트 가능
✅ 새 버전과 이전 버전 비교 가능
✅ 사용자가 배포를 인지하지 못함
```

---

## Blue/Green 배포 프로세스

### 1. 배포 전 상태

```
ALB (Application Load Balancer)
  ↓
Target Group (Blue)
  ↓
ECS Tasks (Blue) - 현재 버전 v1.0.0
  - Task 1 (Running)
  - Task 2 (Running)
```

---

### 2. 새 버전 배포 시작

```yaml
# GitHub Actions에서 트리거
- ECR에 새 이미지 Push (v1.1.0)
- 새 Task Definition 생성
- CodeDeploy에 배포 요청
```

---

### 3. Green 환경 생성

```
CodeDeploy가 수행:
1. Green Target Group 생성
2. 새 ECS Task 실행 (v1.1.0)
3. Green Task가 시작될 때까지 대기
```

```
ALB
  ↓
Target Group (Blue) → Tasks (v1.0.0) ← 100% 트래픽

Target Group (Green) → Tasks (v1.1.0) ← 0% 트래픽 (준비 중)
```

---

### 4. Health Check

```
CodeDeploy가 Green Task의 Health Check 수행:

Health Check 설정:
- Path: /health
- Interval: 30초
- Timeout: 5초
- Healthy Threshold: 2회 연속 성공
- Unhealthy Threshold: 2회 연속 실패

✅ 모든 Green Task가 Healthy 상태가 되어야 다음 단계 진행
❌ Unhealthy 시 자동 롤백
```

---

### 5. 트래픽 전환 (Traffic Shifting)

#### 전환 전략 3가지

##### 1) Canary (카나리 배포)
```
Step 1: 10% 트래픽을 Green으로 전환
  → 5분 대기 (문제 없는지 모니터링)

Step 2: 나머지 90% 트래픽을 Green으로 전환
  → 완료
```

##### 2) Linear (선형 배포)
```
Step 1: 10% 트래픽을 Green으로 전환
  → 1분 대기

Step 2: 20% 트래픽을 Green으로 전환
  → 1분 대기

...

Step 10: 100% 트래픽을 Green으로 전환
  → 완료
```

##### 3) All-at-once (한 번에 전환)
```
Step 1: 100% 트래픽을 즉시 Green으로 전환
  → 완료
```

**권장 전략: Canary 10% → 100%**

---

### 6. Blue 환경 종료

```
트래픽 전환 완료 후:
1. Blue Task 종료
2. Blue Target Group 제거 (또는 유지)
3. 배포 완료

최종 상태:
ALB → Target Group (Green) → Tasks (v1.1.0)
```

---

## ECS Task Definition

### Task Definition 구조

```json
{
  "family": "my-app-task",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "arn:aws:iam::123456789012:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::123456789012:role/ecsTaskRole",
  "containerDefinitions": [
    {
      "name": "app",
      "image": "123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/my-app:latest",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8080,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "SPRING_PROFILES_ACTIVE",
          "value": "prod"
        },
        {
          "name": "DB_HOST",
          "value": "my-db.cluster-abc.ap-northeast-2.rds.amazonaws.com"
        }
      ],
      "secrets": [
        {
          "name": "DB_PASSWORD",
          "valueFrom": "arn:aws:secretsmanager:ap-northeast-2:123456789012:secret:db-password"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/my-app",
          "awslogs-region": "ap-northeast-2",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
```

---

### 주요 설정 설명

#### 1. CPU & Memory (Fargate)

| CPU (vCPU) | Memory (GB) | 사용 예시 |
|-----------|-------------|-----------|
| 0.25 | 0.5, 1, 2 | 경량 애플리케이션 |
| 0.5 | 1, 2, 3, 4 | 소규모 API 서버 |
| 1 | 2, 3, 4, 5, 6, 7, 8 | 일반 웹 애플리케이션 |
| 2 | 4 ~ 16 | 대용량 처리 |
| 4 | 8 ~ 30 | 고성능 애플리케이션 |

#### 2. 환경 변수 vs Secrets

```json
// 일반 환경 변수 (노출되어도 무방)
"environment": [
  {
    "name": "APP_ENV",
    "value": "production"
  }
]

// Secrets (민감 정보)
"secrets": [
  {
    "name": "DB_PASSWORD",
    "valueFrom": "arn:aws:secretsmanager:region:account:secret:name"
  }
]
```

#### 3. Health Check

```json
{
  "healthCheck": {
    "command": ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"],
    "interval": 30,        // 30초마다 체크
    "timeout": 5,          // 5초 안에 응답 없으면 실패
    "retries": 3,          // 3회 연속 실패 시 Unhealthy
    "startPeriod": 60      // 시작 후 60초 동안은 실패해도 무시
  }
}
```

---

## CodeDeploy 설정

### CodeDeploy Application

```hcl
# Terraform
resource "aws_codedeploy_app" "main" {
  name             = "my-app"
  compute_platform = "ECS"
}
```

---

### CodeDeploy Deployment Group

```hcl
resource "aws_codedeploy_deployment_group" "main" {
  app_name               = aws_codedeploy_app.main.name
  deployment_group_name  = "my-app-deployment-group"
  service_role_arn       = aws_iam_role.codedeploy.arn
  deployment_config_name = "CodeDeployDefault.ECSCanary10Percent5Minutes"

  blue_green_deployment_config {
    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }

    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }
  }

  ecs_service {
    cluster_name = aws_ecs_cluster.main.name
    service_name = aws_ecs_service.app.name
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [aws_lb_listener.http.arn]
      }

      target_group {
        name = aws_lb_target_group.blue.name
      }

      target_group {
        name = aws_lb_target_group.green.name
      }
    }
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM"]
  }
}
```

---

### Deployment Config (트래픽 전환 전략)

#### 1. Canary
```
CodeDeployDefault.ECSCanary10Percent5Minutes
  → 10% 트래픽 전환 → 5분 대기 → 나머지 90% 전환

CodeDeployDefault.ECSCanary10Percent15Minutes
  → 10% 트래픽 전환 → 15분 대기 → 나머지 90% 전환
```

#### 2. Linear
```
CodeDeployDefault.ECSLinear10PercentEvery1Minutes
  → 1분마다 10%씩 증가

CodeDeployDefault.ECSLinear10PercentEvery3Minutes
  → 3분마다 10%씩 증가
```

#### 3. All-at-once
```
CodeDeployDefault.ECSAllAtOnce
  → 즉시 100% 전환
```

---

### AppSpec 파일

`appspec.yml` (ECS Blue/Green 배포용)

```yaml
version: 0.0
Resources:
  - TargetService:
      Type: AWS::ECS::Service
      Properties:
        TaskDefinition: "arn:aws:ecs:ap-northeast-2:123456789012:task-definition/my-app-task:10"
        LoadBalancerInfo:
          ContainerName: "app"
          ContainerPort: 8080
        PlatformVersion: "LATEST"

Hooks:
  # Green Task 실행 전
  - BeforeInstall: "LambdaFunctionToValidateBeforeInstall"

  # Green Task 실행 후, 트래픽 전환 전
  - AfterInstall: "LambdaFunctionToValidateAfterInstall"

  # 트래픽 전환 허용 여부 확인
  - AfterAllowTestTraffic: "LambdaFunctionToValidateAfterTestTrafficStart"

  # 트래픽 전환 시작 전
  - BeforeAllowTraffic: "LambdaFunctionToValidateBeforeTrafficShift"

  # 트래픽 전환 후
  - AfterAllowTraffic: "LambdaFunctionToValidateAfterTrafficShift"
```

---

## 모니터링 및 롤백

### 1. CloudWatch Alarms로 자동 롤백

```hcl
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "ecs-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 80

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.app.name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

# CodeDeploy Deployment Group에서 알람 연결
resource "aws_codedeploy_deployment_group" "main" {
  # ...

  alarm_configuration {
    enabled = true
    alarms  = [aws_cloudwatch_metric_alarm.ecs_cpu_high.alarm_name]
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM"]
  }
}
```

---

### 2. 수동 롤백

```bash
# AWS CLI로 이전 Task Definition으로 롤백
aws ecs update-service \
  --cluster my-app-cluster \
  --service my-app-service \
  --task-definition my-app-task:9 \
  --force-new-deployment

# CodeDeploy 배포 중지
aws deploy stop-deployment \
  --deployment-id d-ABCDEFGH \
  --auto-rollback-enabled
```

---

### 3. 배포 모니터링

```bash
# ECS Service 상태 확인
aws ecs describe-services \
  --cluster my-app-cluster \
  --services my-app-service

# CodeDeploy 배포 상태 확인
aws deploy get-deployment \
  --deployment-id d-ABCDEFGH

# CloudWatch Logs 확인
aws logs tail /ecs/my-app --follow
```

---

### 4. 주요 메트릭

**ECS 메트릭:**
- CPUUtilization (CPU 사용률)
- MemoryUtilization (메모리 사용률)
- TargetResponseTime (응답 시간)
- HealthyHostCount (정상 호스트 수)
- UnHealthyHostCount (비정상 호스트 수)

**ALB 메트릭:**
- RequestCount (요청 수)
- TargetResponseTime (백엔드 응답 시간)
- HTTPCode_Target_4XX_Count (4xx 에러)
- HTTPCode_Target_5XX_Count (5xx 에러)

---

## 배포 플로우 요약

```
1. Developer pushes code to GitHub
   ↓
2. GitHub Actions builds Docker image
   ↓
3. Image pushed to ECR
   ↓
4. GitHub Actions updates ECS Task Definition
   ↓
5. CodeDeploy creates Green environment
   ↓
6. Green Tasks start and pass Health Checks
   ↓
7. Traffic shifts from Blue to Green (Canary)
   ↓
8. If successful: Blue Tasks terminated
   If failed: Automatic rollback to Blue
   ↓
9. Deployment complete
```

---

## 트러블슈팅

### 1. Task가 시작되지 않음
```
원인:
- ECR 이미지 Pull 권한 없음
- CPU/Memory 부족
- Subnet에 인터넷 연결 없음

해결:
- Task Execution Role에 ECR 권한 추가
- CPU/Memory 증가
- NAT Gateway 확인
```

### 2. Health Check 실패
```
원인:
- /health 엔드포인트가 없음
- 애플리케이션 시작 시간 부족
- 방화벽/Security Group 문제

해결:
- Health Check 엔드포인트 구현
- startPeriod 증가
- Security Group 규칙 확인
```

### 3. 배포가 너무 느림
```
원인:
- Health Check interval이 너무 긺
- Traffic shifting이 너무 보수적

해결:
- Health Check interval 감소
- Canary → All-at-once로 변경 (개발 환경)
```

---

## 다음 단계

ECS Blue/Green 배포를 이해했다면:
- [05-application-overview.md](./05-application-overview.md) - 애플리케이션 구조 및 예시 코드
