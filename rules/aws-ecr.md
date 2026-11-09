---
paths:
  - "**/*.tf"
  - "**/*.tfvars"
  - "**/Dockerfile"
---

# AWS ECR 컨벤션

## Repository 전략

ECR Repository는 환경별로 분리한다.

- dev 이미지와 prd 이미지는 별도 Repository에 저장
- 환경별 IAM 권한을 완전히 분리하여 prd에 실수로 push하는 사고를 방지

---

## 이미지 태그

```
{version}
```

예시:
```
1.2.0
0.5.1
```

- `latest` 태그는 사용하지 않는다.
- 버전은 SemVer를 따른다.

---

## Lifecycle Policy

모든 Repository에 Lifecycle Policy를 설정한다: 태그된 이미지 기준 **최근 30개만 유지**, 초과분 expire.
