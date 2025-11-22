# Terraform Infrastructure

AWS ECS (Fargate) 기반 인프라 자동화 코드

## 구조

```
terraform/
├── provider.tf              # AWS Provider 설정
├── variables.tf             # 변수 정의
├── outputs.tf               # 출력 값
├── main.tf                  # 메인 Terraform 설정
├── terraform.tfvars.example # 변수 값 예시
│
└── modules/
    ├── vpc/                 # VPC, Subnet, NAT Gateway
    ├── iam/                 # IAM Roles & Policies
    ├── ecr/                 # ECR Repositories
    ├── alb/                 # Application Load Balancer
    └── ecs/                 # ECS Cluster, Services, Tasks
```

## 사전 준비

### State 저장소 설정 (팀 협업 시 필수)

루트 디렉토리의 스크립트 또는 terraform-bootstrap을 사용하세요:

**방법 A: 스크립트**
```bash
# 상위 디렉토리에서 실행
cd ..
./scripts/setup-terraform-backend.sh myapp ap-northeast-2
```

**방법 B: Terraform Bootstrap**
```bash
cd ../terraform-bootstrap
terraform init && terraform apply
```

### provider.tf에 Backend 설정 추가

설정 후 `provider.tf`에 다음을 추가:

```hcl
terraform {
  backend "s3" {
    bucket         = "myapp-terraform-state"
    key            = "backend/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "myapp-terraform-lock"
  }
}
```

## 사용 방법

### 1. 변수 파일 생성

```bash
cp terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars` 파일 편집:

```hcl
aws_region   = "ap-northeast-2"
project_name = "myapp"
environment  = "prod"
```

### 2. Terraform 초기화

```bash
terraform init
```

### 3. 계획 확인

```bash
terraform plan
```

생성될 리소스 확인:
- VPC + Subnets + NAT Gateways
- ECS Cluster + Services
- Application Load Balancer
- ECR Repositories
- IAM Roles
- CloudWatch Log Groups

### 4. 인프라 생성

```bash
terraform apply
```

입력 프롬프트에서 `yes` 입력하여 진행

**소요 시간**: 약 10-15분

### 5. 출력 값 확인

```bash
terraform output
```

중요한 출력 값:
```
alb_dns_name                  = "myapp-alb-123456789.ap-northeast-2.elb.amazonaws.com"
ecr_backend_repository_url    = "123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/myapp-backend"
ecr_frontend_repository_url   = "123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/myapp-frontend"
ecs_cluster_name              = "myapp-cluster"
```

## 생성되는 리소스

### VPC Module
- **VPC**: 10.0.0.0/16
- **Public Subnets**: 2개 (ALB용)
- **Private Subnets**: 2개 (ECS Tasks용)
- **Internet Gateway**: 1개
- **NAT Gateways**: 2개 (고가용성)
- **Route Tables**: Public 1개, Private 2개

### IAM Module
- **ECS Task Execution Role**: ECR pull, CloudWatch 로그 권한
- **ECS Task Role**: 애플리케이션 권한

### ECR Module
- **Backend Repository**: Docker 이미지 저장
- **Frontend Repository**: Docker 이미지 저장
- **Lifecycle Policy**: 최근 10개 이미지만 유지

### ALB Module
- **Application Load Balancer**: 인터넷 노출
- **Backend Target Group**: Health Check `/health`
- **Frontend Target Group**: Health Check `/health`
- **HTTP Listener**: 포트 80
- **Routing Rules**:
  - `/api/*` → Backend
  - `/health` → Backend
  - `/actuator/*` → Backend
  - `/*` → Frontend (기본)

### ECS Module
- **ECS Cluster**: Fargate 기반
- **Backend Service**:
  - Task: 0.25 vCPU, 512MB RAM
  - Desired Count: 2
  - Auto Scaling: 1-10 tasks
- **Frontend Service**:
  - Task: 0.25 vCPU, 512MB RAM
  - Desired Count: 2
  - Auto Scaling: 1-10 tasks
- **Auto Scaling Policies**: CPU/Memory 기반

### CloudWatch
- **Log Groups**:
  - `/ecs/myapp-backend`
  - `/ecs/myapp-frontend`
- **Retention**: 7일

## 비용 예상

| 리소스 | 사양 | 월 비용 (대략) |
|--------|------|---------------|
| ECS Fargate (Backend) | 0.25 vCPU, 0.5GB × 2 tasks | $7.50 |
| ECS Fargate (Frontend) | 0.25 vCPU, 0.5GB × 2 tasks | $7.50 |
| ALB | 트래픽 10GB | $20 |
| NAT Gateway × 2 | 트래픽 10GB | $70 |
| ECR | 10GB | $1 |
| CloudWatch Logs | 5GB | $3 |
| **총계** | | **약 $109/월** |

**비용 절감 팁**:
- NAT Gateway를 1개만 사용 (고가용성 포기)
- 개발 환경은 사용 후 `terraform destroy`

## 환경별 관리

### 개발 환경

```bash
terraform workspace new dev
terraform workspace select dev
terraform apply -var-file="environments/dev/terraform.tfvars"
```

### 프로덕션 환경

```bash
terraform workspace new prod
terraform workspace select prod
terraform apply -var-file="terraform.tfvars"
```

## 주요 명령어

```bash
# 초기화
terraform init

# 변경 사항 미리 보기
terraform plan

# 인프라 생성/수정
terraform apply

# 특정 모듈만 적용
terraform apply -target=module.ecs

# 인프라 삭제 (주의!)
terraform destroy

# 출력 값 확인
terraform output

# 상태 확인
terraform show

# 리소스 목록
terraform state list

# 특정 리소스 상태 확인
terraform state show aws_ecs_cluster.main
```

## 업데이트

### ECS Task 개수 변경

`terraform.tfvars` 수정:
```hcl
backend_desired_count = 4  # 2에서 4로 증가
```

적용:
```bash
terraform apply
```

### CPU/Memory 변경

```hcl
ecs_backend_cpu    = "512"  # 0.5 vCPU
ecs_backend_memory = "1024" # 1GB
```

## 인프라 삭제

**주의**: 모든 리소스가 삭제됩니다!

```bash
terraform destroy
```

확인 후 `yes` 입력

## 트러블슈팅

### Error: No valid credential sources found

**해결:**
```bash
aws configure
```

### Error: Error creating ECS Service

**원인**: Target Group이 생성되지 않음

**해결:**
```bash
terraform apply -target=module.alb
terraform apply
```

### Error: Timeout waiting for ECS service to become stable

**원인**: Task가 Health Check를 통과하지 못함

**확인:**
```bash
# ECS 이벤트 확인
aws ecs describe-services \
  --cluster myapp-cluster \
  --services myapp-backend-service \
  --query 'services[0].events'

# CloudWatch 로그 확인
aws logs tail /ecs/myapp-backend --follow
```

## 모범 사례

1. **State 파일 보안**
   - S3 버킷에 암호화 활성화
   - 버전 관리 활성화
   - DynamoDB로 Lock 설정

2. **변수 관리**
   - `terraform.tfvars`를 `.gitignore`에 추가
   - 민감한 정보는 AWS Secrets Manager 사용

3. **모듈화**
   - 재사용 가능한 모듈 작성
   - 환경별로 분리

4. **태그 관리**
   - 모든 리소스에 태그 추가
   - Project, Environment, ManagedBy 등

## 다음 단계

1. ✅ Terraform으로 인프라 구축 완료
2. ⏭️ [GitHub Actions로 CI/CD 설정](../.github/workflows/)
3. ⏭️ [첫 배포 실행](../DEPLOYMENT_GUIDE.md)

## 참고

- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
