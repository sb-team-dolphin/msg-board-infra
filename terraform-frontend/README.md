# Terraform Frontend Infrastructure

정적 프론트엔드(S3 + CloudFront) 배포를 위한 Terraform 구성입니다.

## 구성 요소

- **S3 Bucket**: 정적 파일 저장
- **CloudFront Distribution**: CDN + HTTPS
- **Origin Access Control (OAC)**: S3 접근 제어
- **ACM Certificate**: SSL 인증서 (커스텀 도메인 사용 시)
- **Route53 Record**: DNS 레코드 (커스텀 도메인 사용 시)

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
    key            = "frontend/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "myapp-terraform-lock"
  }
}
```

## 사용 방법

### 1. 변수 설정

```bash
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 파일을 수정하세요
```

### 2. Terraform 실행

```bash
terraform init
terraform plan
terraform apply
```

### 3. 출력 확인

```bash
terraform output deployment_info
```

## GitHub Actions 배포

Terraform apply 후 출력되는 정보를 사용하여 GitHub Actions에서 배포합니다.

### 워크플로우 예시

```yaml
name: Deploy Frontend

on:
  push:
    branches: [main]

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
          aws-region: ap-northeast-2

      - name: Build (필요시)
        run: npm run build

      - name: Upload to S3
        run: aws s3 sync ./dist s3://myapp-frontend-prod --delete

      - name: Invalidate CloudFront
        run: |
          aws cloudfront create-invalidation \
            --distribution-id E1234567890ABC \
            --paths "/*"
```

## 커스텀 도메인 사용

커스텀 도메인을 사용하려면 `terraform.tfvars`에 다음을 설정하세요:

```hcl
use_custom_domain = true
domain_name       = "www.example.com"
route53_zone_id   = "Z1234567890ABC"
```

**주의**: ACM 인증서는 자동으로 us-east-1에 생성됩니다 (CloudFront 요구사항).

## 출력값

| 출력 | 설명 |
|------|------|
| `s3_bucket_name` | S3 버킷 이름 |
| `cloudfront_distribution_id` | CloudFront 배포 ID (캐시 무효화에 사용) |
| `cloudfront_domain_name` | CloudFront 도메인 |
| `website_url` | 웹사이트 URL |
| `deployment_info` | GitHub Actions에서 필요한 명령어 포함 |

## 주의사항

1. **S3 퍼블릭 접근 차단**: S3는 CloudFront를 통해서만 접근 가능합니다
2. **SPA 라우팅**: 403/404 에러를 index.html로 리다이렉트하여 클라이언트 사이드 라우팅을 지원합니다
3. **캐시 무효화**: 배포 후 반드시 CloudFront 캐시 무효화를 실행하세요
