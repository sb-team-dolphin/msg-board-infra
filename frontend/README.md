# MyApp Frontend

> 변경 주기

React 기반 프론트엔드 애플리케이션

## 기술 스택

- React 18
- Axios (HTTP 클라이언트)
- CSS3
- Nginx (프로덕션)

## 빠른 시작

### 사전 요구사항

- Node.js 18 이상
- npm 또는 yarn

### 로컬 실행

```bash
# 의존성 설치
npm install

# 개발 서버 실행
npm start
```

애플리케이션이 http://localhost:3000 에서 실행됩니다.

**주의**: 백엔드가 http://localhost:8080 에서 실행 중이어야 합니다.

### 환경 변수 설정

```bash
# .env 파일 생성
cp .env.example .env

# .env 파일 편집
REACT_APP_API_URL=http://localhost:8080
```

### Docker로 실행

```bash
# Docker 이미지 빌드
docker build -t myapp-frontend .

# Docker 컨테이너 실행
docker run -p 80:80 myapp-frontend
```

브라우저에서 http://localhost 접속

---

## 기능

### 사용자 관리
- 사용자 목록 조회
- 사용자 추가
- 사용자 수정
- 사용자 삭제

### UI/UX
- 반응형 디자인 (모바일 지원)
- 실시간 유효성 검사
- 사용자 친화적인 에러 메시지
- 로딩 상태 표시

---

## 프로젝트 구조

```
frontend/
├── public/
│   └── index.html              # HTML 템플릿
├── src/
│   ├── components/
│   │   ├── UserList.js         # 사용자 목록 컴포넌트
│   │   ├── UserList.css
│   │   ├── UserForm.js         # 사용자 폼 컴포넌트
│   │   └── UserForm.css
│   ├── services/
│   │   └── api.js              # API 통신 로직
│   ├── App.js                  # 메인 컴포넌트
│   ├── App.css
│   ├── App.test.js
│   ├── index.js                # 엔트리 포인트
│   └── index.css
├── nginx.conf                  # Nginx 설정
├── Dockerfile
├── .dockerignore
├── package.json
└── README.md
```

---

## API 통신

### API Base URL

개발 환경:
```
http://localhost:8080
```

프로덕션 환경:
```
환경 변수 REACT_APP_API_URL로 설정
```

### API 엔드포인트

```javascript
// 모든 사용자 조회
GET /api/users

// 사용자 상세 조회
GET /api/users/{id}

// 사용자 생성
POST /api/users

// 사용자 수정
PUT /api/users/{id}

// 사용자 삭제
DELETE /api/users/{id}

// Health Check
GET /health
```

---

## 빌드 및 배포

### 프로덕션 빌드

```bash
# 프로덕션 빌드 생성
npm run build

# build/ 디렉토리에 최적화된 파일 생성됨
```

### Docker 빌드 (프로덕션)

```bash
# 이미지 빌드
docker build -t myapp-frontend:latest .

# 특정 API URL로 빌드
docker build --build-arg REACT_APP_API_URL=https://api.myapp.com -t myapp-frontend:latest .

# 이미지 확인
docker images | grep myapp-frontend
```

### Nginx 설정

`nginx.conf` 파일에서 다음을 설정할 수 있습니다:

- SPA 라우팅 (React Router)
- API 프록시
- Gzip 압축
- 정적 파일 캐싱
- 보안 헤더

---

## 테스트

```bash
# 모든 테스트 실행
npm test

# 테스트 커버리지
npm test -- --coverage

# Watch 모드로 테스트
npm test -- --watch
```

---

## 스크립트

```json
{
  "start": "개발 서버 실행 (http://localhost:3000)",
  "build": "프로덕션 빌드",
  "test": "테스트 실행",
  "eject": "Create React App 설정 추출 (주의: 되돌릴 수 없음)"
}
```

---

## 환경별 설정

### 개발 환경

```bash
# .env.development
REACT_APP_API_URL=http://localhost:8080
```

### 프로덕션 환경

```bash
# .env.production
REACT_APP_API_URL=https://api.myapp.com
```

---

## 트러블슈팅

### CORS 에러

백엔드에서 CORS를 허용해야 합니다:

```java
@CrossOrigin(origins = "http://localhost:3000")
```

또는 Nginx에서 프록시 설정을 사용합니다.

### API 연결 실패

1. 백엔드가 실행 중인지 확인:
```bash
curl http://localhost:8080/health
```

2. 환경 변수 확인:
```bash
echo $REACT_APP_API_URL
```

3. 브라우저 개발자 도구의 Network 탭 확인

### Docker 빌드 실패

```bash
# 캐시 없이 빌드
docker build --no-cache -t myapp-frontend .

# 로그 확인
docker logs <container-id>
```

---

## 성능 최적화

### 적용된 최적화

1. **Code Splitting**: React.lazy() 사용 가능
2. **이미지 최적화**: WebP 포맷 사용 권장
3. **Gzip 압축**: Nginx에서 자동 처리
4. **캐싱**: 정적 파일 1년 캐시
5. **Minification**: 빌드 시 자동 처리

### 추가 최적화 방안

```bash
# Bundle 크기 분석
npm install --save-dev webpack-bundle-analyzer
npm run build
npx webpack-bundle-analyzer build/static/js/*.js
```

---

## 반응형 디자인

모바일, 태블릿, 데스크톱 모두 지원:

- 모바일: < 768px
- 태블릿: 768px ~ 1024px
- 데스크톱: > 1024px

---

## 보안

### 적용된 보안 설정

1. **XSS 방지**: React의 기본 보호 + Nginx 헤더
2. **HTTPS**: 프로덕션에서 필수
3. **보안 헤더**: X-Frame-Options, X-Content-Type-Options 등
4. **API 인증**: 추후 JWT 또는 OAuth 추가 가능

---

## 다음 단계

1. [백엔드](../backend/README.md) 연동 확인
2. [Terraform](../terraform/README.md)으로 인프라 구축
3. [GitHub Actions](../.github/workflows/)로 CI/CD 설정

---

## 참고

- [React Documentation](https://react.dev/)
- [Create React App Documentation](https://create-react-app.dev/)
- [Axios Documentation](https://axios-http.com/)
- [Nginx Documentation](https://nginx.org/en/docs/)
