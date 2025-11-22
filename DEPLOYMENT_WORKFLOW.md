# 배포 워크플로우 가이드

백엔드와 프론트엔드 인프라 구축 및 애플리케이션 배포 워크플로우를 설명합니다.

---

## 전체 흐름

```
┌─────────────────────────────────────────────────────────────┐
│                    0. 사전 설정 (최초 1회)                     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  terraform-bootstrap (또는 스크립트)                         │
│         │                                                   │
│         ▼                                                   │
│  ┌─────────────┐     ┌─────────────┐                       │
│  │ S3 Bucket   │     │ DynamoDB    │                       │
│  │ (State)     │     │ (Lock)      │                       │
│  └─────────────┘     └─────────────┘                       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────┐
│                    1. 인프라 구축 (1회)                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  백엔드 담당자                    프론트엔드 담당자            │
│  ┌─────────────┐                 ┌─────────────┐           │
│  │ terraform   │                 │ terraform   │           │
│  │ -backend    │                 │ -frontend   │           │
│  └──────┬──────┘                 └──────┬──────┘           │
│         │                               │                   │
│         ▼                               ▼                   │
│  ┌─────────────┐                 ┌─────────────┐           │
│  │ ECS, ALB,   │                 │ S3,         │           │
│  │ RDS, ECR    │                 │ CloudFront  │           │
│  └──────┬──────┘                 └─────────────┘           │
│         │                                                   │
│         ▼                                                   │
│  ALB DNS Name 출력                                          │
│         │                                                   │
└─────────┼───────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────┐
│                    2. 정보 공유                              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  백엔드 담당자 ───────▶ 프론트엔드 담당자                      │
│                                                             │
│  "ALB DNS: myapp-alb-xxx.ap-northeast-2.elb.amazonaws.com"  │
│                                                             │
│  프론트엔드 담당자:                                           │
│  └─▶ GitHub Secrets에 BACKEND_API_URL 등록                  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────┐
│                    3. 애플리케이션 배포 (매번)                 │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  개발자 git push                                             │
│         │                                                   │
│         ▼                                                   │
│  ┌─────────────────────────────────────────────┐           │
│  │           GitHub Actions                     │           │
│  │  ┌─────────────┐    ┌─────────────┐        │           │
│  │  │  Backend    │    │  Frontend   │        │           │
│  │  │  CI/CD      │    │  CI/CD      │        │           │
│  │  └──────┬──────┘    └──────┬──────┘        │           │
│  │         │                  │               │           │
│  │         ▼                  ▼               │           │
│  │  ECR Push →         S3 Sync →              │           │
│  │  ECS Blue/Green     CF Invalidation        │           │
│  └─────────────────────────────────────────────┘           │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 0단계: 사전 설정 (최초 1회)

Terraform State 저장소 설정 (팀 협업 시 필수):

### 방법 A: 스크립트 사용

```bash
# Linux/Mac
./scripts/setup-terraform-backend.sh myapp ap-northeast-2

# Windows
scripts\setup-terraform-backend.bat myapp ap-northeast-2
```

### 방법 B: Terraform 사용

```bash
cd terraform-bootstrap
terraform init
terraform apply

# 출력된 backend 설정 확인
terraform output backend_config
```

### Backend 설정 적용

출력된 설정을 각 provider.tf에 추가:

```hcl
# terraform-backend/provider.tf
terraform {
  backend "s3" {
    bucket         = "myapp-terraform-state"
    key            = "backend/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "myapp-terraform-lock"
  }
}

# terraform-frontend/provider.tf
terraform {
  backend "s3" {
    bucket         = "myapp-terraform-state"
    key            = "frontend/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "myapp-terraform-lock"
  }
}
```

---

## 1단계: 인프라 구축

### 백엔드 인프라 (terraform-backend)

```bash
cd terraform-backend

# 1. 변수 설정
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 편집

# 2. 인프라 생성
terraform init
terraform plan
terraform apply

# 3. 출력값 확인
terraform output alb_dns_name
terraform output ecr_backend_repository_url
terraform output rds_endpoint
```

**생성되는 리소스:**
- VPC, Subnet, NAT Gateway
- ECS Cluster, Service (Fargate)
- Application Load Balancer
- ECR Repository
- RDS MySQL
- CodeDeploy (Blue/Green)
- CloudWatch Log Group

### 프론트엔드 인프라 (terraform-frontend)

```bash
cd terraform-frontend

# 1. 변수 설정
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 편집

# 2. 인프라 생성
terraform init
terraform plan
terraform apply

# 3. 출력값 확인
terraform output deployment_info
```

**생성되는 리소스:**
- S3 Bucket
- CloudFront Distribution
- Origin Access Control (OAC)
- ACM Certificate (선택)

---

## 2단계: 정보 공유

### 백엔드 → 프론트엔드

백엔드 담당자가 다음 정보를 프론트엔드 담당자에게 전달:

```bash
# 백엔드 담당자 실행
cd terraform-backend
terraform output alb_dns_name

# 출력 예시:
# "myapp-alb-123456789.ap-northeast-2.elb.amazonaws.com"
```

### 프론트엔드: GitHub Secrets 설정

프론트엔드 담당자가 GitHub Repository에 Secret 등록:

1. GitHub Repository → Settings → Secrets and variables → Actions
2. New repository secret 클릭
3. 다음 정보 등록:

| Name | Value |
|------|-------|
| `AWS_ACCESS_KEY_ID` | AWS IAM Access Key |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM Secret Key |
| `AWS_REGION` | `ap-northeast-2` |
| `BACKEND_API_URL` | `http://myapp-alb-xxx.elb.amazonaws.com` |
| `S3_BUCKET_NAME` | Terraform output에서 확인 |
| `CLOUDFRONT_DISTRIBUTION_ID` | Terraform output에서 확인 |

---

## 3단계: GitHub Actions 설정

### 백엔드 CI/CD 워크플로우 예시

```yaml
# .github/workflows/backend-deploy.yml
name: Backend Deploy

on:
  push:
    branches: [main]
    paths: ['backend/**']

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ secrets.AWS_REGION }}

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build, tag, and push image to ECR
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          ECR_REPOSITORY: myapp-backend
          IMAGE_TAG: ${{ github.sha }}
        run: |
          cd backend
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
          docker tag $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG $ECR_REGISTRY/$ECR_REPOSITORY:latest
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:latest

      - name: Deploy to ECS
        run: |
          aws ecs update-service \
            --cluster myapp-cluster \
            --service myapp-backend-service \
            --force-new-deployment
```

### 프론트엔드 CI/CD 워크플로우 예시

```yaml
# .github/workflows/frontend-deploy.yml
name: Frontend Deploy

on:
  push:
    branches: [main]
    paths: ['frontend/**']

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'
          cache: 'npm'
          cache-dependency-path: frontend/package-lock.json

      - name: Install dependencies
        run: |
          cd frontend
          npm ci

      - name: Build
        env:
          REACT_APP_API_URL: ${{ secrets.BACKEND_API_URL }}
        run: |
          cd frontend
          npm run build

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ secrets.AWS_REGION }}

      - name: Upload to S3
        run: |
          aws s3 sync frontend/build s3://${{ secrets.S3_BUCKET_NAME }} --delete

      - name: Invalidate CloudFront
        run: |
          aws cloudfront create-invalidation \
            --distribution-id ${{ secrets.CLOUDFRONT_DISTRIBUTION_ID }} \
            --paths "/*"
```

---

## 4단계: 배포 확인

### 백엔드 확인

```bash
# ALB를 통한 API 테스트
curl http://<alb-dns-name>/health
curl http://<alb-dns-name>/api/users

# ECS 서비스 상태 확인
aws ecs describe-services \
  --cluster myapp-cluster \
  --services myapp-backend-service \
  --query 'services[0].{status:status,running:runningCount,desired:desiredCount}'

# CloudWatch 로그 확인
aws logs tail /ecs/myapp-backend --follow
```

### 프론트엔드 확인

```bash
# CloudFront URL로 접속
# https://<cloudfront-domain>.cloudfront.net

# 또는 커스텀 도메인
# https://www.example.com
```

---

## 롤백

### 백엔드 롤백

```bash
# 이전 Task Definition으로 롤백
aws ecs update-service \
  --cluster myapp-cluster \
  --service myapp-backend-service \
  --task-definition myapp-backend-task:<이전버전> \
  --force-new-deployment
```

### 프론트엔드 롤백

```bash
# 이전 버전의 코드로 다시 빌드 & 배포
git checkout <이전커밋>
npm run build
aws s3 sync build s3://<bucket-name> --delete
aws cloudfront create-invalidation --distribution-id <id> --paths "/*"
```

---

## 모니터링

### CloudWatch 대시보드

```bash
# ECS CPU/Memory 사용률
# ALB Request Count
# RDS Connections
```

### 알림 설정

- ECS Task 실패 시 알림
- ALB 5xx 에러 증가 시 알림
- RDS CPU 80% 초과 시 알림

---

## 비용 최적화 팁

1. **개발 환경**: 사용하지 않을 때 `terraform destroy`
2. **NAT Gateway**: 단일 NAT로 비용 절감 (고가용성 포기)
3. **RDS**: Reserved Instance 사용
4. **CloudFront**: 적절한 캐시 TTL 설정
5. **ECS**: 적절한 CPU/Memory 사이징
