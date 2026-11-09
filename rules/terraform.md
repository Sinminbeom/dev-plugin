---
paths:
  - "**/*.tf"
  - "**/*.tfvars"
  - "terraform/**"
---

# Terraform 컨벤션

리소스 *이름* 규칙은 `aws-naming.md`를 따른다. 이 문서는 state·backend·버전·태그 등 **프로비저닝 규약**만 다룬다.

## State 백엔드 (모든 스택 필수)

`backend "s3"`에 다음을 반드시 포함한다. (락 없으면 동시 apply 시 state 유실 — 신규 스택 포함 예외 없음)

- `encrypt = true`
- state 락 — 둘 중 하나
  - `dynamodb_table = "oncx-prd-ops-terraform-dynamodb-backend"` (공용 락 테이블)
  - 또는 Terraform 1.11+ `use_lockfile = true` (S3 네이티브 락)
- state 키: `{repo}/{env}/{component}/terraform.tfstate`

backend 버킷은 버저닝을 켜고, backend 버킷·락 테이블은 `prevent_destroy`로 보호한다.

## Provider · 버전

- `required_version`: 최소 `>= 1.6`. `use_lockfile` 사용 시 `>= 1.11`.
- provider `aws`: **메이저 핀** `~> 6.0`. `>= 5.0` 같은 열린 제약 금지.
- `.terraform.lock.hcl`은 **모든 root에 커밋**. `terraform init -upgrade`는 의도적일 때만.

## Provider default_tags (모든 스택 필수)

태그 키·값·필수 여부의 SSOT는 `aws-naming.md` Tagging Standard. 이 섹션은 *적용 방식*만 정한다.

`provider "aws"`의 `default_tags`로 Tagging Standard의 **Required 태그(`Name` 제외 — 리소스별 부여)를 누락 없이** 적용한다(`ManagedBy = "terraform"` 고정).

`default_tags`는 **TF가 직접 만드는 리소스에만** 적용된다. ASG·Batch·launch template으로 **런타임 생성**되는 EC2·EBS·ENI에는 전파되지 않으니 `tag_specifications`로 보완하되, 값은 **변수로 받아 default_tags와 일치**시킨다(하드코딩 금지 → drift).

## 파일 구조

각 스택/모듈은 `main.tf`(리소스·모듈 호출), `variables.tf`(입력), `outputs.tf`(출력)로 분리한다.

## 변수 · tfvars · 시크릿

- 실제 `*.tfvars`·`*.tfvars.json`은 **커밋 금지**(시크릿 가능). `.gitignore`로 차단.
- 커밋하는 것은 `*.tfvars.example`(키만, 값은 placeholder)뿐.
- `*.tfstate`·`*.tfstate.*`도 커밋 금지.
- `variable`에 `description` 작성(권장).

## 신규 스택

- repo에 `_template` 스택이 있으면 복사(backend·버전·default_tags 기본 포함). 없으면 위 필수 항목을 모두 갖춰 생성.

## 금지

- `main` 등 운영 브랜치에서 직접 `apply` 금지. 리뷰/CI를 거친 변경만 적용.
- state 파일 수동 편집 금지. `terraform state mv`/`rm`은 의도적일 때만 쓰고 사유를 PR에 남긴다.
