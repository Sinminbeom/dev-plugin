# dev-plugin

개인용 Claude Code 플러그인. 개발 워크플로우 스킬(세션 관리, GitHub 플로우, 코딩 도우미 등)을 담는다.

## 설치

```bash
# 1. 마켓플레이스 등록
claude plugin marketplace add sinminbeom/dev-plugin

# 2. 플러그인 설치
claude plugin install dev-plugin@sinminbeom
```

또는 Claude Code 세션 안에서:

```
/plugin marketplace add sinminbeom/dev-plugin
/plugin install dev-plugin@sinminbeom
```

## 사용

스킬은 `/dev-plugin:<스킬이름>` 형태로 호출한다.

| 스킬 | 설명 |
|------|------|
| `session-start` | 세션 시작 — 프리플라이트 점검, Issue 생성, 작업 브랜치 생성, 구현 |
| `session-end` | 세션 종료 — 커밋, push, PR 생성. `--unattended` 또는 env `DEV_PLUGIN_SESSION_END_UNATTENDED`면 무인 모드 |

두 스킬은 `scripts/detect-integration.sh`로 통합 브랜치를 판정한다. 원격에 `develop`이 있으면 git-flow(base `develop`), 없으면 GitHub Flow(base `main`).

## Hooks

| Hook | 스크립트 | 설명 |
|------|----------|------|
| `SessionStart` | `scripts/inject-rules.sh` | `rules/*.md`를 `~/.claude/rules/dev-plugin-*.md`로 symlink 주입 (매 세션 재생성) |
| `PreToolUse` (Bash) | `scripts/pretooluse-bash.sh` | `git`/`gh` 명령 가드. ① `main`/`master`/`develop`에서 직접 `git commit`/`git push` 차단(태그 push는 허용) ② 커밋 메시지 이슈 번호(`#N`) 누락 차단 ③ 커밋·PR 본문의 Claude 서명 차단 |

## Rules

| 문서 | 설명 |
|------|------|
| `rules/python.md` | Python 코딩 컨벤션 — SOLID, 클래스 래핑, 인터페이스(ABC 통일·`Protocol` 예외), 다중상속 정책, 타입 네이밍(`I`/`ab` prefix), 주석·docstring(WHY만) |
| `rules/github.md` | Git 컨벤션 — 타입, Issue·Branch·Commit·PR 형식, 리치 포맷, 태그 |
| `rules/session.md` | 세션 규칙 — 1 세션 = 1 Issue = 1 PR, Task 분리 기준, 세션 중단 기준·처리 절차 |
| `rules/terraform.md` | Terraform 프로비저닝 규약 — state 백엔드·락, provider 버전, `default_tags`, tfvars·시크릿 (`*.tf` 등에서만 로드) |
| `rules/aws-naming.md` | AWS 리소스 네이밍·태깅 표준 (`*.tf` 등에서만 로드) |
| `rules/aws-ecr.md` | ECR 저장소 분리, 이미지 태그, Lifecycle Policy (`*.tf`·`Dockerfile`에서만 로드) |

## 테스트

```bash
bash tests/run.sh
```

`pretooluse-bash.sh`와 `detect-integration.sh`의 회귀 테스트. `jq`가 필요하다.

## 구조

```
dev-plugin/
├── .claude-plugin/
│   ├── plugin.json        # 플러그인 메타데이터
│   └── marketplace.json   # 마켓플레이스 정의 (repo = 마켓플레이스 + 플러그인 겸용)
├── hooks/
│   └── hooks.json         # hook 정의
├── rules/
│   └── <rule>.md          # 세션에 주입되는 컨벤션 문서
├── scripts/
│   └── <script>.sh        # hook·스킬 보조 스크립트
├── skills/
│   └── <skill>/SKILL.md   # 스킬 정의
└── tests/
    └── run.sh             # hook 회귀 테스트
```

## 버저닝

[SemVer](https://semver.org/lang/ko/)를 따른다. `0.x`는 API 불안정 단계.
