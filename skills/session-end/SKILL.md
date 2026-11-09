---
name: session-end
description: Claude 개발 세션을 종료한다 — 커밋, 브랜치 push, PR 생성까지 GitHub에 반영. 작업을 마무리하고 코드 리뷰 요청할 때 사용. 트리거 예시 — 자연어 "PR 올려줘", "PR 만들어", "작업 마무리", "이거 끝내자", "커밋하고 푸시", "세션 종료"; 슬래시 "/session-end", "/dev-plugin:session-end"
---

세션을 종료한다.

이슈 번호는 현재 브랜치명(`feat/#61/...`)에서 파싱한다 — 이 번호가 PR이 close하는 **Task Issue**다 (`rules/session.md`).

파싱에 실패하면 아래처럼 물어본다.

> 이슈 번호가 무엇인가요? (예: /session-end #42)

**모드 분기**: 스킬 인자 `--unattended` 또는 env `DEV_PLUGIN_SESSION_END_UNATTENDED`가 있으면 → `## 무인 모드`. 없으면 → `## 대화형`. 선택한 쪽의 step만 실행한다.

## 대화형

### 1. 준비

이슈 번호를 파싱하고(실패 시 위 규칙대로 질문하거나 중단한다) 현재 상태를 파악한다.

```bash
git branch --show-current   # 브랜치명에서 이슈번호 파싱
git status                  # 미커밋 변경 확인
git log --oneline -5        # 최근 커밋 확인
```

### 2. 계획과 단일 승인

커밋 초안·base·PR 초안·후처리 점검은 `(워킹트리 diff, base)`에서 파생되는 **한 그룹**이다. 네 항목을 순서대로 보여주되 **마지막에 한 번만** 승인받고, 승인 전까지 아무것도 커밋·생성하지 않는다.

**커밋 초안**: 미커밋 변경이 있으면 `rules/github.md`의 Commit 메시지 컨벤션으로 초안을 작성해 보여준다. 이미 다 커밋된 상태면 "미커밋 변경 없음"이라 밝힌다(추가 수정이 생기면 새 커밋으로 처리하고, 기존 히스토리는 건드리지 않는다).

**base 유도**: PR이 머지될 base 브랜치를 유도해 보여준다.

```bash
BRANCH="$(git branch --show-current)"
# ${CLAUDE_SKILL_DIR}로 참조 (../../ = 플러그인 루트). canonical: scripts/detect-integration.sh
INTEGRATION="$(bash "${CLAUDE_SKILL_DIR}/../../scripts/detect-integration.sh" 2>/dev/null | awk '{print $1}')"
[ -n "$INTEGRATION" ] || INTEGRATION=main

if [[ "$BRANCH" =~ ^(release|hotfix)/ ]]; then
  BASE=main
else
  BASE="$INTEGRATION"
fi
echo "유도된 base: $BASE"
```

**PR 초안**: 확정된 base 기준으로 PR 제목과 본문 초안을 `rules/github.md`의 Pull Request 컨벤션에 따라 작성해 보여준다. Summary는 핵심 변경을 bullet로 쓰고(절대 `-` 하나만 남기지 않음), 본문에 close할 Issue를 명시한다. **이미 PR이 있으면**(`gh pr list --head "$(git branch --show-current)"`) 새로 만들지 않고 "기존 PR 유지, 본문 갱신"으로 표시한다.

**후처리 점검**: 이번 **세션 전체 변경분**(base 대비 전부, `git merge-base origin/<BASE> HEAD` 이후 커밋+미커밋)을 점검한다. 대상만 좁힐 뿐 판단에 필요한 주변·연관 코드는 읽는다. **report-only**다(작업 트리·PR 미수정). 결과는 **채팅 출력 전용** — GitHub(PR 본문·코멘트)에 쓰지 않는다. findings를 `gh pr comment`로 남기는 건 `## 무인 모드` 전용 경로다. 해당 항목만 이모지 앵커로 보여주고, 없으면 "점검: 해당 없음".

🔍와 🔒는 `*-review` 커맨드(`/code-review`, `/security-review`, `/codex:review` 등)다. **대화형은 실행 유무 확인만 하고, 실행은 무인 모드가 한다** — 대화형엔 직접 돌릴 사람이 있다. 자체 diff 검토를 리뷰 결과로 보고하지 않는다. **세션당 1회** 기준으로 `실행됨` / `미실행` / `해당 없음`(대상 조건 미충족)을 표기하고, 미실행이면 아래 커맨드 문자열을 그대로 출력한다. ⚠️ 두 항목은 매번 현재 diff로 판단한다.

- **🔍 code-review** → `/code-review origin/<BASE>...HEAD`: 실행 코드(소스·스크립트·설정) 변경이 대상. 산문 문서(`SKILL.md`·`rules/*.md`·`README`)만 바뀐 세션은 해당 없음 — 단 문서 내 실행 코드 블록(hook 등)은 대상. 애매하면 코드로 간주.
- **🔒 security-review** → `/security-review`: 보안 경계(인증·인가, 시크릿, 네트워크·접근 제어, 외부 입력→신뢰 경계) 접촉이 대상. 애매하면 해당 없음(명백할 때만).
- **⚠️ CLAUDE.md 정합**: 루트에 `CLAUDE.md`가 있고 diff가 그 서술을 낡게 만들면 `⚠️ CLAUDE.md <항목>`으로 알린다. 애매하면 제외한다.
- **⚠️ 연관 변경 누락**: diff에서 유추되는 연관 지점(같은 로직 복붙, 같은 상수와 시그니처를 쓰는 다른 파일, diff가 참조하는 문서)이 함께 안 바뀌었으면 `⚠️ 연관 누락: <지점>`으로 알린다. 애매하면 제외한다.

위 네 항목을 보여준 뒤 승인받는다.

> 이대로 커밋하고 PR을 생성할까요? (수정할 부분이 있으면 알려주세요)

### 3. 피드백 루프 (승인 전)

사용자 응답에 따라 분기한다.

- **진행**: 4번으로 간다.
- **코드, 문서, base 수정**: 조치한 뒤 **2번 그룹(커밋, PR, 점검)을 재실행**해 다시 제시한다. 정정된 범위 재검토가 필요하면 사용자가 직접 요청한다(사용자 책임).
- **초안 문구만 수정**(커밋 메시지와 PR 본문 표현): diff가 안 바뀌었으므로 **해당 초안만 갱신**해 다시 제시한다.

점검은 report-only라 findings가 진행을 막지 않는다. 사용자가 무시하고 "진행"하면 그대로 간다.

### 4. 실행 (승인 후)

순서대로 실행한다. Claude attribution 금지(`rules/github.md`).

1. **커밋**: 미커밋 변경이 있으면 커밋 초안의 메시지로 커밋한다(없으면 skip).
2. **push**: `git push -u origin "$(git branch --show-current)"` (이미 push됐으면 생략한다).
3. **PR**: 없으면 PR 초안으로 생성하고, 이미 있으면 유지한다(필요 시 본문 갱신).

   ```bash
   gh pr create --base <BASE> --title "..." --body "..."
   ```

   생성 후 본문에 close하는 Issue가 들어갔는지 확인한다.

### 5. 완료 보고

실제 생성 후에만 아래 형식으로 출력한다. 안 한 일을 끝난 것처럼 표기하지 않는다.

```
세션 종료

PR    : <PR URL>
Issue : #<번호> (close 예정)
```

## 무인 모드

**진입 조건**: 위 모드 분기 참조. 조건 없이 이 섹션을 실행하지 않는다.

승인을 기다리지 않고 대화형 §2의 유도값과 초안을 그대로 채택해 아래 순서로 실행한다. 이슈 번호를 브랜치명과 인자 어디서도 못 얻으면 중단한다. 작업 트리는 고치지 않는다 — 아래 5·6번은 PR 코멘트만 남긴다.

1. **커밋**: 미커밋 변경이 있으면 초안 메시지로 커밋한다(없으면 skip).
2. **push**.
3. **base 유도**: 대화형 §2의 base 유도 로직으로 유도값을 그대로 채택한다.
4. **PR 생성**: 본문에 close할 Issue를 명시한다.
5. **리뷰 실행**: 무인 모드는 위임 실행이므로 🔍·🔒를 **직접 돌린다**(세션당 1회). 대화형 §2의 대상 조건이 `해당 없음`인 항목만 건너뛴다. 커맨드 모델 호출이 막혀 있으면 같은 역할의 호출 가능한 `*-review`로 대체하고, 대체도 없거나 실행이 실패한 항목만 `미실행`으로 기록한다. PR이 없으면(4번 실패) 5·6번을 건너뛴다.
6. **findings 기록**: 5번 결과와 ⚠️ CLAUDE.md 정합, 연관 판정을 `gh pr comment`로 PR에 남긴다. 커맨드가 PR에 직접 남겼으면 링크만, 아니면 결과 요약을 옮겨 적는다. `미실행`은 그 사실만 적는다.
7. **보고**: PR URL과 findings 요약(건수, 링크).
