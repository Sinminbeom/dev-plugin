---
name: session-start
description: Claude 개발 세션을 시작한다 — GitHub Issue 생성, 작업 브랜치 생성, 구현까지 가이드. 새 기능 개발, 버그 수정, 리팩터링 등 작업을 시작할 때 사용. 트리거 예시 — 자연어 "새 작업 시작", "이거 구현해줘", "~ 만들어줘", "~ 추가하자", "~ 고쳐줘", "이슈 만들어서 작업"; 슬래시 "/session-start", "/dev-plugin:session-start"
---

세션을 시작한다.

인자: $ARGUMENTS

## 0. 프리플라이트 리컨실

Issue·branch 생성 전에 저장소↔로컬 어긋남을 점검·제안한다. 어긋남이 없으면 프롬프트 없이 다음 Step으로 진행한다. 재진입 확인·열린 Issue 조회도 겸한다. bash는 사실만 모으고, 분류·제안과 provenance(미커밋·미푸시의 출처) 판단은 Claude가 한다.

### 사실 수집

```bash
if git fetch --prune 2>/dev/null; then NET=ok; else NET=offline; fi

BRANCH="$(git branch --show-current)"

# ${CLAUDE_SKILL_DIR}로 참조 (스킬 bash엔 CLAUDE_PLUGIN_ROOT 없음, ../../ = 플러그인 루트).
read -r INTEGRATION INTEGRATION_SRC < <(
  bash "${CLAUDE_SKILL_DIR}/../../scripts/detect-integration.sh" 2>/dev/null || echo "main unavailable"
)

REENTRY=no
[[ "$BRANCH" =~ ^(feat|fix|hotfix|refactor|docs|chore|test|style|perf|ci|build|release)/#[0-9]+/ ]] && REENTRY=yes
ON_INTEGRATION=no
{ [ "$BRANCH" = main ] || [ "$BRANCH" = master ] || [ "$BRANCH" = develop ]; } && ON_INTEGRATION=yes

if git rev-parse --abbrev-ref '@{upstream}' >/dev/null 2>&1; then
  AHEAD="$(git rev-list --count '@{upstream}..HEAD')"
  BEHIND="$(git rev-list --count 'HEAD..@{upstream}')"
else
  AHEAD=no-upstream; BEHIND=no-upstream
fi

echo "BRANCH=$BRANCH REENTRY=$REENTRY ON_INTEGRATION=$ON_INTEGRATION"
echo "INTEGRATION=$INTEGRATION (src=$INTEGRATION_SRC) NET=$NET AHEAD=$AHEAD BEHIND=$BEHIND"
echo "--- 워킹트리 (dirty) ---"; git status --porcelain
echo "--- 미푸시 커밋 ---"; git log --oneline '@{upstream}..HEAD' 2>/dev/null || echo "(upstream 없음)"
echo "--- 열린 Issue ---"; gh issue list --state open --limit 10 2>/dev/null || echo "(gh 사용 불가)"
```

판정된 `INTEGRATION`은 Step 4 분기 기준으로 쓴다.

### 상황별 제안

수집한 사실과 대화 맥락으로 분류·제안한다(겹치면 모두 보고).

| 상황 | 제안 |
|------|------|
| 작업 브랜치 + clean + 원격 동기 + `INTEGRATION=develop` | 없음 → Step 1 |
| `ON_INTEGRATION=yes` (통합 브랜치에 서 있음) | 작업 브랜치로 전환(dirty면 변경 가져가며) |
| dirty/미푸시 + 대화가 출처 설명 | 정상 이어하기 |
| dirty/미푸시 + 대화가 설명 못 함 | 내용 노출 후 위임(stash / WIP 커밋 / 폐기 / 현재 작업 포함) |
| `INTEGRATION=main` (원격 develop 없음, flow 애매) | git-flow 재생성 vs GitHub Flow 선택 프롬프트. 대화서 이미 확정했으면 skip |
| behind/ahead/diverged | behind는 pull, ahead는 push/정리 제안 |
| `NET=offline` | 차단 없이 진행. `INTEGRATION`이 캐시 기반이라 부정확할 수 있음 고지 |

### 안전 원칙

- 기본 비파괴(stash·WIP 커밋). discard·`git reset --hard`·force는 명시 확인 없이 실행하지 않는다.
- provenance 불명은 보존으로 기운다 — 삭제 단정 없이 노출한다.

재진입(`REENTRY=yes`)이면 이미 세션 중이므로 알린다.

> 이미 진행 중인 세션이 있습니다(`<브랜치>`). 계속하려면 현재 브랜치에서 작업하거나 `/session-end`로 마무리하세요. 새 세션은 통합 브랜치로 이동 후 다시 실행하세요.

어긋남이 없거나 사용자가 처리 방안을 확정하면 다음 Step으로 넘어간다.

## 1. 작업 내용 확인

`$ARGUMENTS`가 비어 있으면 아래처럼 물어본다.

> 어떤 작업을 할 건가요? 간단히 설명해주세요.

작업 설명을 확보한다.

- 자연어 인자 — 그대로 작업 설명으로 쓴다.
- 기존 Issue 번호 — `gh issue view`로 제목·본문을 읽어 작업 설명으로 쓴다.

작업 설명으로:

1. 이해한 의도를 1~2줄로 재진술한다.
2. 명확성(①목표 도출 가능 ②해석 단일 ③완료·검증 방법 도출 가능)으로 분기한다.
   - **모두 충족** — 확인 대기 없이 3으로 간다.
   - **정보 누락형 불명확** (부족한 정보가 특정되어 타깃 질문이 도출됨) — 질문을 한 번에 하나씩 한다. 해석이 갈리면 열린 질문 대신 선택지로 제시한다. 명확해지면 3으로 간다.
   - **탐색형 불명확** (부족한 정보가 특정되지 않아 목표 정의부터 필요) — 브레인스토밍류 스킬이 가용하면 위임해 의도를 확정하고 3으로 간다. 미가용이면 정보 누락형과 같이 진행한다.
3. 확정된 의도를 라우팅한다.
   - 자연어 인자 — Step 2 Issue 초안 입력으로 쓴다.
   - 기존 Issue 번호 — 보완된 의도가 있으면 Issue 본문에 반영하고(`gh issue edit`), Step 2~3을 건너뛰고 Step 4로 간다.

## 2. Issue 초안 작성 및 분리 점검

작업 설명으로 두 가지를 한다.

- **초안 작성**: `rules/github.md`의 Issue 생성 컨벤션에 따라 본문을 쓴다.
- **분리 점검**: `rules/session.md`의 **Task 분리 기준** 5가지로 현재 Task가 단일 의도인지 자기보고한다. **현재 세션 포함 가능 예외**에 해당하는 동반 변경은 분리 신호로 보지 않는다.

**분리 신호 없음** — 초안과 함께 진행 여부를 한 번에 묻는다.

> 이 내용으로 Issue를 생성할까요? (수정이 필요하면 알려주세요)

**분리 신호 감지** — 초안과 함께 분리 권고를 보고하고 사용자에게 선택받는다.

> 본 Task에 [분리 신호]가 감지되었습니다: `<해당 항목>`. 다음 중 선택해주세요:
> 1. Task를 분리한다 (Issue 초안을 다시 작성)
> 2. 현재 의도가 단일하다고 판단하고 그대로 진행한다 (이 초안으로 Issue 생성)

사용자가 1번을 선택하면 본 Step을 다시 수행한다. 2번 선택 또는 분리 신호 없음으로 진행이 확정되면 다음 Step으로 넘어간다.

## 3. Issue 생성

현재 디렉토리의 GitHub 저장소에 Issue를 생성한다.

```bash
gh issue create --title "<제목>" --body "<본문>"
```

생성된 Issue 번호를 확인한다. (예: #42)

## 4. Branch 생성

작업 내용에 맞는 타입을 선택하고 `rules/github.md`의 Branch 네이밍 컨벤션에 따라 브랜치를 생성한다.

분기 기준은 Step 0에서 판정한 통합 브랜치. `release`/`hotfix`는 `main`에서 분기한다.

```bash
git checkout <통합브랜치> && git pull && git checkout -b "<타입>/#<번호>/<설명>"
```

## 5. 구현 진행

브랜치 생성 직후 구현을 바로 시작한다.

- 커밋·PR은 하지 않는다. 구현만 진행하고 `/session-end`에서 마무리한다.
- 구현 중에는 `rules/session.md`의 **세션 중단 기준**과 **설계 점검 신호**에 따라 자기보고한다.

## 6. 완료 보고

구현 완료 후 아래 형식으로 출력한다.

```
구현 완료

Issue : #<번호> <제목>
Branch: <브랜치명>

/session-end 로 커밋 및 PR을 생성하세요.
```
