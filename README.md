# AWS Infrastructure Terraform Templates

AWS 인프라를 Terraform으로 프로비저닝하기 위한 템플릿 저장소입니다.

## 개요

이 저장소는 두 가지 독립적인 Terraform 프로젝트를 포함합니다:

| 프로젝트 | 설명 | 담당 |
|----------|------|------|
| `terraform-backend/` | 백엔드 인프라 (ECS, RDS, ALB 등) | 백엔드 인프라 담당자 |
| `terraform-frontend/` | 프론트엔드 인프라 (S3, CloudFront) | 프론트엔드 인프라 담당자 |

## 프로젝트 구조

```
.
├── README.md                      # 이 파일
├── DEPLOYMENT_WORKFLOW.md         # 배포 워크플로우 가이드
├── TROUBLESHOOTING.md             # 문제 해결 가이드
│
├── terraform-backend/             # 백엔드 인프라
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── provider.tf
│   ├── terraform.tfvars.example
│   ├── README.md
│   └── modules/
│       ├── vpc/                   # VPC, Subnet, NAT
│       ├── ecs/                   # ECS Cluster, Service
│       ├── alb/                   # Application Load Balancer
│       ├── ecr/                   # Container Registry
│       ├── rds/                   # MySQL Database
│       ├── iam/                   # IAM Roles
│       └── codedeploy/            # Blue/Green 배포
│
├── terraform-frontend/            # 프론트엔드 인프라
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── provider.tf
│   ├── terraform.tfvars.example
│   ├── README.md
│   └── modules/
│       ├── s3/                    # 정적 파일 버킷
│       ├── cloudfront/            # CDN
│       └── acm/                   # SSL 인증서
│
└── docs/                          # 참고 문서
    ├── 01-architecture-overview.md
    ├── 02-terraform-infra-design.md
    ├── 04-ecr-ecs-bluegreen.md
    └── RDS_SETUP_GUIDE.md
```

---

## 빠른 시작

### 사전 요구사항

- AWS 계정 및 IAM Access Key
- Terraform 1.0+
- AWS CLI

### 백엔드 인프라 구축

```bash
cd terraform-backend
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 편집

terraform init
terraform plan
terraform apply

# 출력값 확인 (프론트엔드 팀에 전달)
terraform output alb_dns_name
```

### 프론트엔드 인프라 구축

```bash
cd terraform-frontend
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 편집

terraform init
terraform plan
terraform apply

# 출력값 확인
terraform output deployment_info
```

---

## 인프라 구성

### 백엔드 (terraform-backend)

| 리소스 | 설명 |
|--------|------|
| VPC | 네트워크 인프라 (Public/Private Subnet, NAT) |
| ECS Fargate | 컨테이너 오케스트레이션 |
| ALB | 로드 밸런서 |
| ECR | Docker 이미지 저장소 |
| RDS MySQL | 데이터베이스 |
| CodeDeploy | Blue/Green 배포 |
| CloudWatch | 로그 및 모니터링 |

### 프론트엔드 (terraform-frontend)

| 리소스 | 설명 |
|--------|------|
| S3 | 정적 파일 저장 |
| CloudFront | CDN + HTTPS |
| OAC | S3 접근 제어 |
| ACM | SSL 인증서 (선택) |
| Route53 | DNS 레코드 (선택) |

---

## 배포 워크플로우

자세한 내용은 [DEPLOYMENT_WORKFLOW.md](./DEPLOYMENT_WORKFLOW.md)를 참조하세요.

### 요약

1. **인프라 구축** (1회)
   - 백엔드 담당자: `terraform-backend` apply
   - 프론트엔드 담당자: `terraform-frontend` apply

2. **정보 공유**
   - 백엔드 → 프론트엔드: ALB DNS Name (API URL)
   - 프론트엔드: GitHub Secrets에 `BACKEND_API_URL` 등록

3. **애플리케이션 배포** (매번)
   - GitHub Actions로 자동 배포
   - 백엔드: ECR push → ECS Blue/Green
   - 프론트엔드: S3 sync → CloudFront invalidation

---

## 비용 예상

### 백엔드 (월간)

| 서비스 | 사양 | 예상 비용 |
|--------|------|-----------|
| ECS Fargate | 0.25 vCPU × 2 | $15 |
| ALB | 기본 | $20 |
| RDS | db.t3.micro | $15 |
| NAT Gateway | 1개 | $35 |
| **총계** | | **~$85** |

### 프론트엔드 (월간)

| 서비스 | 사양 | 예상 비용 |
|--------|------|-----------|
| S3 | 1GB | $0.03 |
| CloudFront | 10GB 전송 | $1 |
| **총계** | | **~$1** |

---

## 인프라 삭제

```bash
# 프론트엔드 먼저 삭제
cd terraform-frontend
terraform destroy

# 백엔드 삭제
cd terraform-backend
terraform destroy
```

---

## 문서

- [DEPLOYMENT_WORKFLOW.md](./DEPLOYMENT_WORKFLOW.md) - 배포 워크플로우
- [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) - 문제 해결
- [RDS_SETUP_GUIDE.md](./RDS_SETUP_GUIDE.md) - RDS 설정
- [terraform-backend/README.md](./terraform-backend/README.md) - 백엔드 인프라 상세
- [terraform-frontend/README.md](./terraform-frontend/README.md) - 프론트엔드 인프라 상세

### 참고 문서 (docs/)

- [01-architecture-overview.md](./01-architecture-overview.md) - 아키텍처 개요
- [02-terraform-infra-design.md](./02-terraform-infra-design.md) - Terraform 설계
- [04-ecr-ecs-bluegreen.md](./04-ecr-ecs-bluegreen.md) - ECS Blue/Green 배포

---

## 라이선스

MIT License
