---
paths:
  - "**/*.tf"
  - "**/*.tfvars"
  - "terraform/**"
---

# AWS 리소스 네이밍 컨벤션 (v3.1.1 기준)

## 기본 원칙

- 모든 이름은 소문자 + 하이픈(`-`) 기반 hyphen-case (예외: CloudWatch Log Group은 슬래시 경로 — 해당 절 참고)
- Core Pattern을 공통으로 유지, 최소한의 Extension만 사용
- 공용 리소스의 `env`는 운영 영향도 기준으로 선택
  - 장애/변경이 실서비스에 영향을 주면 `prd-common`
  - 환경별로 분리된 공용 자산이 있으면 `dev-common`, `stg-common` 등

---

## Core Naming Pattern

```
oncx-{env}-{system}-{component}-{resource_type}
```

| 항목 | 예시 | 설명 |
|------|------|------|
| env | prd, stg, dev, sbx | 환경 |
| system | common, data, platform, ops | 상위 기능 영역 |
| component | api, worker, db, network | 구성 요소 |
| resource_type | vpc, subnet, ec2, bucket | 리소스 유형 |

## Full Naming Pattern

```
oncx-{env}-{system}-{component}-{resource_type}
[-{detail}][-{region}][-{az}][-{seq}]
```

| 요소 | 예시 | 설명 |
|------|------|------|
| detail | public, app, db, node, logs | 역할·특성 |
| region | apne2 | 리전 |
| az | a, c | 가용 영역 |
| seq | 01, 02 | 일련 번호 |

---

## Resource Type 약어 표준

| 리소스 | 약어 | 리소스 | 약어 |
|--------|------|--------|------|
| VPC | vpc | RDS Cluster | rdscluster |
| Subnet | subnet | RDS Instance | rds |
| Route Table | rt | ElastiCache | cache |
| NAT Gateway | natgw | S3 Bucket | bucket |
| Internet Gateway | igw | Lambda | lambda |
| EC2 Instance | ec2 | IAM Role | role |
| Auto Scaling Group | asg | IAM Policy | policy |
| Launch Template | lt | ECS Task Definition | etd |
| ALB / NLB | alb / nlb | State Machine | sfn |
| Target Group | tg | | |

---

## 리소스 유형별 네이밍 예시

대표 예시 1~2개씩. 동일 유형은 위 패턴을 반복 적용한다.

### Network

| 리소스 | 예시 |
|--------|------|
| VPC | `oncx-prd-common-network-vpc-apne2` |
| Subnet (public) | `oncx-prd-common-network-subnet-public-a` |
| Subnet (app) | `oncx-prd-common-network-subnet-app-c` |
| Route Table | `oncx-prd-common-network-rt-public` |
| NAT Gateway | `oncx-prd-common-network-natgw-a` |
| Internet Gateway | `oncx-prd-common-network-igw-apne2` |

### Compute

| 리소스 | 예시 |
|--------|------|
| EC2 | `oncx-prd-platform-api-ec2-node-apne2-01` |
| ASG | `oncx-prd-platform-api-asg-apne2` |
| Launch Template | `oncx-prd-platform-api-lt-v001` |

### Database

| 리소스 | 예시 |
|--------|------|
| RDS Cluster | `oncx-prd-data-db-rdscluster-mysql` |
| RDS Primary | `oncx-prd-data-db-rds-primary-mysql-01` |
| RDS Reader | `oncx-prd-data-db-rds-reader-mysql-01` |

### Storage / Function

| 리소스 | 예시 |
|--------|------|
| S3 Bucket (logs) | `oncx-prd-platform-api-bucket-logs` |
| S3 Bucket (raw) | `oncx-prd-data-processing-bucket-raw` |
| Lambda | `oncx-prd-platform-worker-lambda-generate-report` |
| Lambda (stg) | `oncx-stg-platform-api-lambda-handle-webhook` |

### IAM

| 리소스 | 예시 |
|--------|------|
| Role | `oncx-prd-platform-api-role-ec2access` |
| Policy | `oncx-prd-platform-api-policy-s3logs-rw` |

### CloudWatch Log Group

```
/oncx/{env}/{system}/{component}/{detail}
```

예: `/oncx/prd/platform/api/access`, `/oncx/prd/platform/api/error`

---

## Tagging Standard

Naming Convention과 정합성을 유지하기 위한 최소 기준. 태그 미지원 리소스는 예외.

| Tag Key | Required | 예시 값 |
|---------|----------|---------|
| Name | Yes | oncx-prd-common-network-subnet-public-a |
| Environment | Yes | prd, stg |
| System | Yes | platform |
| Component | Yes | api, db |
| ManagedBy | Yes | terraform |
| Repository | Yes | oncx-iac |
| Owner | Optional | ops-team |
| CostCenter | Optional | 1001 |

`ManagedBy`·`Repository`(둘 다 필수)는 IaC 관리 메타 태그 — orphan 판별·소스 추적 anchor. `Repository` 값은 git repo **이름만**(owner·URL 없이).

옵션 태그는 Naming Convention과 직접 연동되지 않으며 운영 기준에 따라 선택 적용.
