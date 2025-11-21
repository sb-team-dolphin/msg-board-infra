# 전체 아키텍처 개요

## 목차
- [시스템 구성도](#시스템-구성도)
- [핵심 개념](#핵심-개념)
- [전체 배포 흐름](#전체-배포-흐름)
- [기술 스택](#기술-스택)

---

## 시스템 구성도

```
┌─────────────────────────────────────────────────────────────────┐
│                         Developer                                │
│                            ↓                                     │
│                      git push (GitHub)                           │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    GitHub Actions (CI/CD)                        │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐    │
│  │  Build   │ → │   Test   │ → │  Docker  │ → │ ECR Push │    │
│  └──────────┘   └──────────┘   └──────────┘   └──────────┘    │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                      AWS Infrastructure                          │
│                    (Terraform으로 구축)                         │
│                                                                  │
│  ┌──────────┐     ┌──────────────┐     ┌─────────────┐        │
│  │   ECR    │ →   │ ECS Fargate  │ →   │     ALB     │        │
│  │ (Images) │     │ Blue/Green   │     │ (Load Bal.) │        │
│  └──────────┘     └──────────────┘     └─────────────┘        │
│                          ↓                      ↓               │
│                   ┌──────────────┐       ┌──────────┐          │
│                   │ Target Group │       │  Users   │          │
│                   └──────────────┘       └──────────┘          │
└─────────────────────────────────────────────────────────────────┘
```

---

## 핵심 개념

### Terraform의 역할
> **"환경(Infrastructure)을 준비하는 도구"**

- AWS 인프라를 코드로 정의 (Infrastructure as Code)
- 한 번 구축하면 재사용 가능
- 환경 변경 시에만 실행

**담당 리소스:**
- VPC, Subnet, IGW, NAT Gateway
- ECS Cluster, ECS Service (Fargate)
- ECR Repository
- Application Load Balancer (ALB)
- Target Groups, Listeners
- Auto Scaling 정책
- IAM Roles & Policies
- CodeDeploy (Blue/Green 배포용)

### GitHub Actions의 역할
> **"애플리케이션을 배포하는 도구"**

- 코드 변경 시마다 자동 실행
- CI/CD 파이프라인 자동화
- 인프라는 건드리지 않고 애플리케이션만 배포

**담당 작업:**
- 소스 코드 빌드
- 테스트 실행
- Docker 이미지 생성
- ECR에 이미지 업로드
- ECS에 배포 명령 전송

---

## 전체 배포 흐름

### [1단계] Terraform으로 AWS 인프라 프로비저닝

```bash
# 초기 인프라 구축 (1회 실행)
terraform init
terraform plan
terraform apply
```

**결과:**
- AWS에 ECS Cluster, ALB, ECR, VPC 등이 자동 생성
- 인프라는 "고정된 환경"으로 유지됨

---

### [2단계] 개발자가 코드 Push

```bash
git add .
git commit -m "Add new feature"
git push origin main
```

**트리거:**
- GitHub Actions 워크플로우 자동 실행

---

### [3단계] GitHub Actions CI/CD 파이프라인 실행

#### CI (Continuous Integration)
1. 소스 코드 체크아웃
2. 의존성 설치 및 빌드
   - Backend: `mvn package` 또는 `gradle build`
   - Frontend: `npm build` 또는 `yarn build`
3. 테스트 실행
4. Docker 이미지 빌드
5. Docker 이미지 태깅 (예: `latest`, `v1.2.3`)
6. ECR에 이미지 Push

#### CD (Continuous Deployment)
1. 새 ECS Task Definition 생성
2. ECS Service에 업데이트 요청
3. Blue/Green 배포 트리거

---

### [4단계] AWS ECS Blue/Green 배포

#### Blue/Green 배포 프로세스

```
1. Green 환경에서 새 Task(컨테이너) 실행
   ↓
2. ALB Target Group에 Green Task 등록
   ↓
3. Health Check 통과 확인
   ↓
4. 트래픽을 Blue → Green으로 점진적 이동
   (예: 10% → 50% → 100%)
   ↓
5. Green이 안정화되면 Blue Task 종료
```

**장점:**
- 무중단 배포 (Zero Downtime)
- 문제 발생 시 즉시 롤백 가능
- 사용자는 배포 중임을 인지하지 못함

---

## 기술 스택

### Infrastructure as Code
- **Terraform** - AWS 인프라 자동 프로비저닝

### CI/CD
- **GitHub Actions** - 자동화된 빌드/테스트/배포 파이프라인

### Container & Orchestration
- **Docker** - 애플리케이션 컨테이너화
- **Amazon ECR** - Docker 이미지 저장소
- **Amazon ECS (Fargate)** - 서버리스 컨테이너 오케스트레이션

### Networking & Load Balancing
- **Application Load Balancer (ALB)** - 트래픽 분산
- **VPC, Subnet, IGW, NAT** - 네트워크 인프라

### Deployment Strategy
- **AWS CodeDeploy** - Blue/Green 배포 자동화

### Backend
- Java (Spring Boot) / Node.js / Python
- Maven / Gradle / npm

### Frontend
- React / Vue.js / Angular
- npm / yarn

---

## 발표용 핵심 메시지

> **Terraform으로 AWS 인프라(ECS, ALB, ECR, VPC 등)를 구축해두고,**
> **개발자가 GitHub에 코드를 push하면 GitHub Actions가 CI/CD 파이프라인을 실행하여**
> **Docker 이미지를 빌드 → ECR에 push하고,**
> **이후 ECS 서비스가 Blue/Green 방식으로 자동 배포되어**
> **최신 코드가 무중단 방식으로 업데이트된다.**

---

## 발표 시 설명 예시

> "먼저 Terraform을 통해 AWS의 전체 인프라를 코드로 정의하고 자동으로 생성합니다.
> 인프라 구성은 한 번 만들어놓으면 계속 재사용 가능합니다.
>
> 이후 개발자는 단순히 Git에 코드를 push하면 됩니다.
>
> GitHub Actions가 실행되어 애플리케이션을 Docker 이미지로 빌드하고
> AWS ECR에 업로드합니다.
>
> 업로드가 끝나면 GitHub Actions는 ECS에 배포 명령을 보내고,
> ECS는 Blue/Green 방식으로 새로운 Task를 띄워
> 헬스 체크 후 ALB가 트래픽을 새 버전으로 전환합니다.
>
> 이 과정은 완전 자동화되어 있어 운영자가 직접 서버에 접속할 필요가 없습니다."

---

## 다음 단계

각 단계별 상세 설계는 다음 문서를 참고하세요:

- [02-terraform-infra-design.md](./02-terraform-infra-design.md) - Terraform 인프라 설계
- [03-github-actions-ci-cd.md](./03-github-actions-ci-cd.md) - CI/CD 파이프라인 설계
- [04-ecr-ecs-bluegreen.md](./04-ecr-ecs-bluegreen.md) - ECS Blue/Green 배포 설계
- [05-application-overview.md](./05-application-overview.md) - 애플리케이션 구조
