# 트러블슈팅 가이드

Terraform 인프라 및 AWS 서비스 관련 일반적인 문제와 해결 방법을 정리한 가이드입니다.

## 목차

1. [Terraform 문제](#terraform-문제)
2. [GitHub Actions 문제](#github-actions-문제)
3. [AWS ECS 문제](#aws-ecs-문제)
4. [CloudFront/S3 문제](#cloudfronts3-문제)
5. [네트워크 문제](#네트워크-문제)
6. [성능 문제](#성능-문제)

---

## CloudFront/S3 문제

### S3 버킷 정책 오류

**증상:**
```
Error: Error putting S3 policy: AccessDenied
```

**해결:**
```bash
# 버킷 소유권 확인
aws s3api get-bucket-ownership-controls --bucket <bucket-name>

# 퍼블릭 액세스 블록 확인
aws s3api get-public-access-block --bucket <bucket-name>
```

### CloudFront 403 Forbidden

**증상:**
```
403 Forbidden - AccessDenied
```

**원인:**
- OAC 설정 오류
- S3 버킷 정책 누락

**해결:**
```bash
# CloudFront OAC 확인
aws cloudfront get-origin-access-control --id <oac-id>

# S3 버킷 정책에 CloudFront 허용 확인
aws s3api get-bucket-policy --bucket <bucket-name>
```

### CloudFront 캐시 무효화 실패

**증상:**
```
InvalidationBatch contains multiple invalidation paths for same resource
```

**해결:**
```bash
# 올바른 무효화 명령어
aws cloudfront create-invalidation \
  --distribution-id <distribution-id> \
  --paths "/*"
```

### ACM 인증서 검증 실패

**증상:**
```
Certificate is in status PENDING_VALIDATION
```

**해결:**
1. Route53에 DNS 검증 레코드가 생성되었는지 확인
2. DNS 전파 대기 (최대 30분)
3. 도메인 소유권 확인

```bash
# 인증서 상태 확인
aws acm describe-certificate \
  --certificate-arn <cert-arn> \
  --region us-east-1
```

---

## Terraform 문제

### Bootstrap S3 버킷 생성 실패

**증상:**
```
BucketAlreadyExists: The requested bucket name is not available
```

**해결:**
```bash
# S3 버킷 이름은 전역적으로 고유해야 함
# 프로젝트 이름을 더 구체적으로 변경
./scripts/setup-terraform-backend.sh myapp-unique-123 ap-northeast-2
```

### State Lock 오류

**증상:**
```
Error acquiring the state lock
```

**해결:**
```bash
# 1. 다른 terraform 프로세스가 실행 중인지 확인
# 2. DynamoDB에서 수동으로 Lock 해제
aws dynamodb delete-item \
  --table-name myapp-terraform-lock \
  --key '{"LockID": {"S": "myapp-terraform-state/backend/terraform.tfstate"}}'

# 3. 또는 강제 잠금 해제
terraform force-unlock <LOCK_ID>
```

### Backend 설정 후 Init 실패

**증상:**
```
Error: Backend configuration changed
```

**해결:**
```bash
# 기존 state를 새 backend로 마이그레이션
terraform init -migrate-state

# 또는 reconfigure
terraform init -reconfigure
```

### Terraform Init 실패

**증상:**
```
Error: Failed to get existing workspaces
```

**해결:**
```bash
# AWS 자격 증명 확인
aws sts get-caller-identity

# AWS Configure 재설정
aws configure

# Terraform 재초기화
rm -rf .terraform
terraform init
```

### S3 Backend 접근 불가

**증상:**
```
Error: Failed to get existing workspaces: AccessDenied
```

**해결:**
```bash
# S3 버킷 존재 확인
aws s3 ls s3://myapp-terraform-state

# S3 버킷 생성 (없는 경우)
aws s3 mb s3://myapp-terraform-state --region ap-northeast-2

# 권한 확인
aws s3api get-bucket-acl --bucket myapp-terraform-state
```

### Resource Already Exists

**증상:**
```
Error: resource already exists
```

**해결:**
```bash
# 기존 리소스 Import
terraform import aws_ecs_cluster.main myapp-cluster

# 또는 리소스 삭제 후 재생성
terraform destroy -target=aws_ecs_cluster.main
terraform apply
```

### NAT Gateway 생성 실패

**증상:**
```
Error creating NAT Gateway: InvalidAllocationID.NotFound
```

**해결:**
```bash
# Internet Gateway가 먼저 생성되었는지 확인
terraform apply -target=module.vpc.aws_internet_gateway.main

# 전체 재적용
terraform apply
```

### Terraform Apply Timeout

**증상:**
```
Error: timeout while waiting for state to become 'ready'
```

**해결:**
```bash
# NAT Gateway나 ECS Service 생성 시간이 오래 걸릴 수 있음
# 10-15분 대기 후 재시도

# 특정 리소스만 재적용
terraform apply -target=module.ecs

# 상태 새로고침
terraform refresh
```

### ECR Lifecycle Policy 에러

**증상:**
```
InvalidParameterException: Lifecycle policy validation failure: Rule for tagStatus=ANY must have the lowest priority per storage class
```

**원인:**
`tagStatus=any` 규칙이 가장 높은 priority (낮은 숫자)에 있음

**해결:**
```hcl
# tagStatus=any 규칙은 항상 가장 낮은 priority (높은 숫자)를 가져야 함
rules = [
  {
    rulePriority = 1  # untagged 먼저
    tagStatus    = "untagged"
    ...
  },
  {
    rulePriority = 2  # any는 마지막
    tagStatus    = "any"
    ...
  }
]
```

### deployment_configuration 블록 에러

**증상:**
```
Error: Blocks of type "deployment_configuration" are not expected here
```

**원인:**
`deployment_circuit_breaker`가 `deployment_configuration` 외부에 있거나 구문 오류

**해결:**
간단한 ECS Service 설정에서는 deployment_configuration을 제거하고 기본값 사용:
```hcl
resource "aws_ecs_service" "app" {
  name            = "my-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration { ... }
  load_balancer { ... }
  # deployment_configuration 생략 시 기본값 사용
}
```

---

## GitHub Actions 문제

### Workflow가 실행되지 않음

**증상:**
워크플로우가 트리거되지 않음

**원인 및 해결:**
1. `.github/workflows/` 경로 확인
2. YAML 문법 오류 확인
3. 브랜치 이름 확인 (`main` vs `master`)
4. `paths` 필터 확인

```yaml
# backend 파일 변경 시에만 실행
paths:
  - 'backend/**'
```

### AWS 자격 증명 실패

**증상:**
```
Error: Credentials could not be loaded
```

**해결:**
1. GitHub Secrets 확인:
   - Repository → Settings → Secrets
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `AWS_REGION`

2. IAM 사용자 권한 확인:
   - ECR: Full Access
   - ECS: Full Access
   - IAM: PassRole 권한

### ECR Push 실패

**증상:**
```
denied: User is not authorized to perform: ecr:InitiateLayerUpload
```

**해결:**

IAM 사용자에 ECR 권한 추가:
```json
{
  "Effect": "Allow",
  "Action": [
    "ecr:GetAuthorizationToken",
    "ecr:BatchCheckLayerAvailability",
    "ecr:GetDownloadUrlForLayer",
    "ecr:PutImage",
    "ecr:InitiateLayerUpload",
    "ecr:UploadLayerPart",
    "ecr:CompleteLayerUpload"
  ],
  "Resource": "*"
}
```

### ECS 배포 Timeout

**증상:**
```
Error: Timeout waiting for ECS service stability
```

**해결:**
```bash
# ECS Service 이벤트 확인
aws ecs describe-services \
  --cluster myapp-cluster \
  --services myapp-backend-service \
  --query 'services[0].events[0:10]'

# Task 실행 실패 원인 확인
aws ecs describe-tasks \
  --cluster myapp-cluster \
  --tasks $(aws ecs list-tasks --cluster myapp-cluster --service myapp-backend-service --query 'taskArns[0]' --output text) \
  --query 'tasks[0].stopReason'
```

---

## AWS ECS 문제

### Task가 시작되지 않음

**증상:**
```
Task failed to start
```

**원인 및 해결:**

#### 1. ECR 이미지 Pull 실패
```bash
# Task Execution Role에 ECR 권한 확인
# IAM Role: myapp-ecs-task-execution-role
```

권한 추가:
```json
{
  "Effect": "Allow",
  "Action": [
    "ecr:GetAuthorizationToken",
    "ecr:BatchCheckLayerAvailability",
    "ecr:GetDownloadUrlForLayer",
    "ecr:BatchGetImage"
  ],
  "Resource": "*"
}
```

#### 2. CPU/Memory 부족
```bash
# Task Definition 확인
aws ecs describe-task-definition \
  --task-definition myapp-backend-task

# CPU/Memory 증가
# terraform.tfvars 수정
ecs_backend_cpu    = "512"
ecs_backend_memory = "1024"
```

#### 3. Subnet에 인터넷 연결 없음
```bash
# NAT Gateway 확인
aws ec2 describe-nat-gateways

# Route Table 확인
aws ec2 describe-route-tables
```

### Health Check 계속 실패

**증상:**
```
Target deregistered: Target.FailedHealthChecks
```

**해결:**

1. **애플리케이션 Health Check 엔드포인트 확인**
```bash
# 컨테이너 내부에서 확인
docker exec -it <container-id> /bin/sh
wget -O- http://localhost:8080/health
```

2. **Security Group 규칙 확인**
```bash
# ALB → ECS 통신 허용 확인
# ECS Security Group Ingress 규칙:
# Source: ALB Security Group
# Port: 8080 (Backend) or 80 (Frontend)
```

3. **startPeriod 증가**
```hcl
health_check {
  start_period = 120  # 2분으로 증가
}
```

### Task가 계속 재시작됨

**증상:**
```
Task stopped: Essential container exited
```

**해결:**
```bash
# CloudWatch Logs 확인
aws logs tail /ecs/myapp-backend --follow

# 컨테이너 로그에서 에러 찾기
# 일반적인 원인:
# - 애플리케이션 크래시
# - 메모리 부족 (OOM Killed)
# - 환경 변수 누락
```

### 배포가 멈춤 (Stuck)

**증상:**
```
Deployment is stuck in IN_PROGRESS state
```

**해결:**
```bash
# 수동으로 서비스 업데이트
aws ecs update-service \
  --cluster myapp-cluster \
  --service myapp-backend-service \
  --force-new-deployment

# 또는 서비스 삭제 후 재생성
terraform destroy -target=module.ecs.aws_ecs_service.backend
terraform apply -target=module.ecs.aws_ecs_service.backend
```

---

## 네트워크 문제

### ALB에서 502 Bad Gateway

**증상:**
```
502 Bad Gateway
```

**원인 및 해결:**

1. **Target Group에 Healthy Target 없음**
```bash
aws elbv2 describe-target-health \
  --target-group-arn <TARGET_GROUP_ARN>
```

2. **ECS Task가 실행 중이지 않음**
```bash
aws ecs list-tasks \
  --cluster myapp-cluster \
  --service myapp-backend-service
```

3. **Security Group 문제**
```bash
# ALB Security Group: 80, 443 허용
# ECS Security Group: ALB로부터 8080 허용
```

### ALB에서 504 Gateway Timeout

**증상:**
```
504 Gateway Timeout
```

**원인:**
- Backend 응답 시간 초과 (기본 60초)

**해결:**

ALB Target Group 타임아웃 증가:
```hcl
resource "aws_lb_target_group" "backend" {
  # ...
  deregistration_delay = 60
}
```

### 프론트엔드에서 백엔드 API 호출 실패

**증상:**
```
Failed to load resource: net::ERR_CONNECTION_REFUSED
```

**해결:**

1. **API URL 확인**
```javascript
// frontend/src/services/api.js
const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:8080';
```

2. **CORS 설정 확인**
```java
@CrossOrigin(origins = "*")  // 또는 특정 도메인
```

3. **ALB Listener Rule 확인**
```bash
# /api/* 경로가 Backend로 라우팅되는지 확인
aws elbv2 describe-rules \
  --listener-arn <LISTENER_ARN>
```

---

## 성능 문제

### 응답 시간이 느림

**원인 및 해결:**

1. **ECS Task CPU/Memory 부족**
```bash
# CloudWatch에서 확인
# CPUUtilization > 80% → CPU 증가
# MemoryUtilization > 80% → Memory 증가
```

2. **Auto Scaling 설정**
```hcl
# terraform.tfvars
backend_min_capacity = 2
backend_max_capacity = 10
cpu_target_value     = 70
```

3. **ALB Connection Draining**
```hcl
deregistration_delay = 30  # 30초로 감소
```

### Task가 계속 종료됨 (Out of Memory)

**증상:**
```
Task stopped: OutOfMemoryError: Container killed due to memory usage
```

**해결:**
```hcl
# Memory 증가
ecs_backend_memory = "1024"  # 512 → 1024
```

또는 애플리케이션 메모리 최적화:
```properties
# application.yml
spring:
  jpa:
    properties:
      hibernate:
        jdbc:
          batch_size: 20  # Batch 크기 조정
```

---

## 모니터링 및 디버깅

### CloudWatch Logs 확인

```bash
# 실시간 로그
aws logs tail /ecs/myapp-backend --follow

# 에러 로그만 필터링
aws logs tail /ecs/myapp-backend --follow --filter-pattern "ERROR"

# 특정 시간 범위
aws logs tail /ecs/myapp-backend \
  --since 1h \
  --filter-pattern "Exception"
```

### ECS Exec로 컨테이너 접속

```bash
# ECS Exec 활성화 (Terraform)
resource "aws_ecs_service" "backend" {
  enable_execute_command = true
}

# 컨테이너 접속
aws ecs execute-command \
  --cluster myapp-cluster \
  --task <TASK_ARN> \
  --container backend \
  --interactive \
  --command "/bin/sh"
```

### CloudWatch Insights 쿼리

```sql
-- 에러 로그 검색
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 100

-- 응답 시간 분석
fields @timestamp, @message
| filter @message like /Duration/
| stats avg(@message) by bin(5m)
```

---

## 비상 대응

### 전체 서비스 중단

**긴급 조치:**
```bash
# 1. 즉시 이전 버전으로 롤백
aws ecs update-service \
  --cluster myapp-cluster \
  --service myapp-backend-service \
  --task-definition myapp-backend-task:<PREVIOUS_REVISION> \
  --force-new-deployment

# 2. Auto Scaling 일시 중지
aws application-autoscaling delete-scaling-policy \
  --policy-name myapp-backend-cpu-autoscaling \
  --service-namespace ecs

# 3. 수동으로 Task 개수 증가
aws ecs update-service \
  --cluster myapp-cluster \
  --service myapp-backend-service \
  --desired-count 10
```

### 데이터베이스 연결 실패

**임시 해결:**
```bash
# Task Definition에 환경 변수 추가/수정
# DB connection timeout 증가
# Retry 로직 추가
```

---

## 도움말 및 지원

### 추가 리소스

- [AWS ECS Troubleshooting](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/troubleshooting.html)
- [Terraform Troubleshooting](https://www.terraform.io/docs/troubleshooting/)
- [GitHub Actions Troubleshooting](https://docs.github.com/en/actions/monitoring-and-troubleshooting-workflows)

### 로그 수집 명령어

문제 보고 시 다음 정보 수집:
```bash
# 1. ECS 서비스 상태
aws ecs describe-services --cluster myapp-cluster --services myapp-backend-service > ecs-service.json

# 2. Task 상태
aws ecs describe-tasks --cluster myapp-cluster --tasks $(aws ecs list-tasks --cluster myapp-cluster --service myapp-backend-service --query 'taskArns[0]' --output text) > ecs-task.json

# 3. CloudWatch 로그 (최근 100줄)
aws logs tail /ecs/myapp-backend --since 1h > cloudwatch-logs.txt

# 4. ALB 상태
aws elbv2 describe-target-health --target-group-arn <TG_ARN> > alb-health.json
```

---

**문제가 해결되지 않으면:**
1. CloudWatch Logs 확인
2. ECS Events 확인
3. GitHub Issues에 보고
4. AWS Support 문의
