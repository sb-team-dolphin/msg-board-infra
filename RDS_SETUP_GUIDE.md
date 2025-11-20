# RDS MySQL 설정 가이드

이 가이드는 Terraform으로 RDS MySQL을 구축하고 Spring Boot 애플리케이션과 연동하는 방법을 설명합니다.

## 목차

1. [개요](#1-개요)
2. [Terraform으로 RDS 생성](#2-terraform으로-rds-생성)
3. [Spring Boot JPA 설정](#3-spring-boot-jpa-설정)
4. [로컬 개발 환경](#4-로컬-개발-환경)
5. [배포 및 확인](#5-배포-및-확인)
6. [트러블슈팅](#6-트러블슈팅)
7. [비용 및 최적화](#7-비용-및-최적화)

---

## 1. 개요

### 아키텍처

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   ALB       │ ──▶ │   ECS       │ ──▶ │   RDS       │
│             │     │  (Backend)  │     │  (MySQL)    │
└─────────────┘     └─────────────┘     └─────────────┘
                           │
                           ▼
                    ┌─────────────┐
                    │  Secrets    │
                    │  Manager    │
                    └─────────────┘
```

### 주요 구성 요소

- **RDS MySQL 8.0**: 관리형 데이터베이스
- **Secrets Manager**: DB 비밀번호 안전하게 저장
- **Private Subnet**: 외부 접근 차단
- **Security Group**: ECS에서만 접근 허용

---

## 2. Terraform으로 RDS 생성

### 2.1 Terraform 변수 설정

`terraform/variables.tf`에 다음 변수들이 정의되어 있습니다:

```hcl
variable "db_name" {
  description = "Database name"
  default     = "myappdb"
}

variable "db_username" {
  description = "Database master username"
  default     = "admin"
}

variable "db_instance_class" {
  description = "RDS instance class"
  default     = "db.t3.micro"  # 프리 티어
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB"
  default     = 20
}

variable "db_multi_az" {
  description = "Enable Multi-AZ"
  default     = false
}
```

### 2.2 RDS 모듈 구조

```
terraform/modules/rds/
├── main.tf       # RDS 인스턴스, Security Group, Secrets
├── variables.tf  # 입력 변수
└── outputs.tf    # 출력 값 (endpoint, secret ARN 등)
```

### 2.3 Terraform 실행

```bash
cd terraform

# 초기화 (새 모듈 추가 시)
terraform init

# 변경 사항 확인
terraform plan

# RDS 생성 (약 10-15분 소요)
terraform apply
```

### 2.4 생성되는 리소스

1. **RDS MySQL 인스턴스** (`myapp-mysql`)
2. **DB Subnet Group** (Private Subnet에 배치)
3. **Security Group** (ECS에서 3306 포트 허용)
4. **Secrets Manager Secret** (DB 자격 증명 저장)

### 2.5 Terraform Output 확인

```bash
# RDS 정보 확인
terraform output rds_endpoint
terraform output rds_address
terraform output rds_secret_arn

# 전체 배포 정보
terraform output deployment_info
```

---

## 3. Spring Boot JPA 설정

### 3.1 의존성 (pom.xml)

```xml
<!-- Spring Boot JPA -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-data-jpa</artifactId>
</dependency>

<!-- MySQL Driver -->
<dependency>
    <groupId>com.mysql</groupId>
    <artifactId>mysql-connector-j</artifactId>
    <scope>runtime</scope>
</dependency>

<!-- H2 (로컬 테스트용) -->
<dependency>
    <groupId>com.h2database</groupId>
    <artifactId>h2</artifactId>
    <scope>runtime</scope>
</dependency>
```

### 3.2 application.yml 프로파일

#### 기본 설정
```yaml
spring:
  profiles:
    active: ${SPRING_PROFILES_ACTIVE:local}

  jpa:
    hibernate:
      ddl-auto: update
    show-sql: false
```

#### Local 프로파일 (H2)
```yaml
spring:
  config:
    activate:
      on-profile: local

  datasource:
    url: jdbc:h2:mem:myappdb
    username: sa
    password:
    driver-class-name: org.h2.Driver

  h2:
    console:
      enabled: true
      path: /h2-console
```

#### Production 프로파일 (MySQL/RDS)
```yaml
spring:
  config:
    activate:
      on-profile: prod

  datasource:
    url: jdbc:mysql://${DB_HOST}:${DB_PORT}/${DB_NAME}?useSSL=false&serverTimezone=UTC
    username: ${DB_USERNAME}
    password: ${DB_PASSWORD}
    driver-class-name: com.mysql.cj.jdbc.Driver
```

### 3.3 JPA Entity

```java
@Entity
@Table(name = "users")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class User {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @NotBlank
    @Column(nullable = false)
    private String name;

    @Email
    @NotBlank
    @Column(nullable = false, unique = true)
    private String email;

    @Column
    private String role;
}
```

### 3.4 JPA Repository

```java
@Repository
public interface UserRepository extends JpaRepository<User, Long> {
    Optional<User> findByEmail(String email);
    boolean existsByEmail(String email);
}
```

### 3.5 초기 데이터 로딩

```java
@Configuration
public class DataInitializer {

    @Bean
    CommandLineRunner initDatabase(UserRepository repository) {
        return args -> {
            if (repository.count() == 0) {
                repository.save(new User(null, "Alice", "alice@example.com", "Developer"));
                repository.save(new User(null, "Bob", "bob@example.com", "Designer"));
            }
        };
    }
}
```

---

## 4. 로컬 개발 환경

### 4.1 H2 데이터베이스로 실행

```bash
cd backend

# Local 프로파일로 실행 (기본값)
mvn spring-boot:run

# 또는 명시적으로
mvn spring-boot:run -Dspring-boot.run.profiles=local
```

### 4.2 H2 Console 접속

- URL: http://localhost:8080/h2-console
- JDBC URL: `jdbc:h2:mem:myappdb`
- Username: `sa`
- Password: (비워두기)

### 4.3 로컬 MySQL로 테스트 (선택)

```bash
# Docker로 MySQL 실행
docker run -d \
  --name mysql-local \
  -e MYSQL_ROOT_PASSWORD=password \
  -e MYSQL_DATABASE=myappdb \
  -p 3306:3306 \
  mysql:8.0

# 환경 변수 설정 후 실행
export DB_HOST=localhost
export DB_PORT=3306
export DB_NAME=myappdb
export DB_USERNAME=root
export DB_PASSWORD=password

mvn spring-boot:run -Dspring-boot.run.profiles=prod
```

---

## 5. 배포 및 확인

### 5.1 Terraform으로 인프라 생성

```bash
cd terraform
terraform apply
```

### 5.2 GitHub에 코드 Push

```bash
git add .
git commit -m "Add RDS MySQL support"
git push origin main
```

### 5.3 배포 확인

GitHub Actions가 자동으로:
1. 코드 빌드
2. Docker 이미지 생성 및 ECR Push
3. ECS Task Definition 업데이트 (DB 환경 변수 포함)
4. ECS Service 배포

### 5.4 API 테스트

```bash
# ALB DNS 확인
terraform output alb_dns_name

# Health Check
curl http://<ALB_DNS>/health

# 사용자 목록
curl http://<ALB_DNS>/api/users

# 사용자 생성
curl -X POST http://<ALB_DNS>/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"Test","email":"test@test.com","role":"Tester"}'
```

### 5.5 데이터 영속성 확인

1. 사용자 생성
2. ECS Task 재시작
3. 데이터가 유지되는지 확인

---

## 6. 트러블슈팅

### 6.1 RDS 연결 실패

**증상:**
```
Communications link failure
```

**해결:**
1. Security Group 확인 (ECS → RDS 3306 허용)
2. RDS가 Private Subnet에 있는지 확인
3. NAT Gateway 상태 확인

```bash
# Security Group 규칙 확인
aws ec2 describe-security-groups \
  --group-ids <RDS_SECURITY_GROUP_ID>
```

### 6.2 인증 실패

**증상:**
```
Access denied for user 'admin'@'...'
```

**해결:**
1. Secrets Manager에서 비밀번호 확인
2. ECS Task Definition에 환경 변수 확인

```bash
# Secret 값 확인
aws secretsmanager get-secret-value \
  --secret-id myapp-db-password \
  --query SecretString \
  --output text | jq
```

### 6.3 테이블 생성 안됨

**증상:**
```
Table 'myappdb.users' doesn't exist
```

**해결:**
1. `spring.jpa.hibernate.ddl-auto=update` 확인
2. DB 사용자에 CREATE TABLE 권한 확인

### 6.4 연결 풀 고갈

**증상:**
```
HikariPool-1 - Connection is not available
```

**해결:**
```yaml
spring:
  datasource:
    hikari:
      maximum-pool-size: 20
      minimum-idle: 5
```

### 6.5 CloudWatch Logs 확인

```bash
# Backend 로그
aws logs tail /ecs/myapp-backend --follow

# 에러만 필터링
aws logs tail /ecs/myapp-backend --follow --filter-pattern "ERROR"
```

---

## 7. 비용 및 최적화

### 7.1 예상 비용

| 리소스 | 사양 | 월 비용 (서울 리전) |
|--------|------|---------------------|
| RDS MySQL | db.t3.micro, 20GB | ~$15-20 |
| Secrets Manager | 1 secret | ~$0.40 |

**프리 티어 (첫 12개월):**
- db.t2.micro 또는 db.t3.micro: 750시간/월 무료
- 20GB 스토리지 무료

### 7.2 비용 최적화 팁

1. **개발 환경**: db.t3.micro 사용
2. **스토리지**: gp2 대신 gp3 사용 (더 저렴)
3. **백업**: 보관 기간 최소화 (개발: 1일)
4. **Multi-AZ**: 개발 환경에서는 비활성화

### 7.3 프로덕션 권장 설정

```hcl
# terraform.tfvars
db_instance_class    = "db.t3.small"
db_allocated_storage = 50
db_multi_az          = true
```

---

## 참고 자료

- [Spring Data JPA 공식 문서](https://spring.io/projects/spring-data-jpa)
- [AWS RDS 사용자 가이드](https://docs.aws.amazon.com/rds/)
- [Terraform AWS RDS](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance)

---

## 변경 이력

| 날짜 | 버전 | 설명 |
|------|------|------|
| 2024-01-XX | 1.0.0 | 초기 버전 |
