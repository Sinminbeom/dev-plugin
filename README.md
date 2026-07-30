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

스킬은 `/dev-plugin:<스킬이름>` 형태로 호출한다. (아직 등록된 스킬 없음)

## Hooks

| Hook | 스크립트 | 설명 |
|------|----------|------|
| `SessionStart` | `scripts/inject-rules.sh` | `rules/*.md`를 `~/.claude/rules/dev-plugin-*.md`로 symlink 주입 (매 세션 재생성) |
| `PreToolUse` (Bash) | `scripts/block-main-commit.sh` | `main`/`master`/`develop`(통합 브랜치)에서 `git commit`/`git push` 직접 실행 차단. 태그 push(`refs/tags/`, `v*` 태그)는 허용 |

## Rules

| 문서 | 설명 |
|------|------|
| `rules/python.md` | Python 코딩 컨벤션 — SOLID, 클래스 래핑, 다중상속 정책, 타입 네이밍(`I`/`ab` prefix), 주석·docstring(WHY만) |

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
│   └── <script>.sh        # hook 스크립트
└── skills/                # 스킬 정의 (skills/<skill-name>/SKILL.md)
```

## 버저닝

[SemVer](https://semver.org/lang/ko/)를 따른다. `0.x`는 API 불안정 단계.
