#!/bin/bash
# 훅 회귀 방지 테스트 러너
# 통합 dispatcher(pretooluse-bash.sh)를 임시 git repo에서 실행하고 exit 코드로 기대 동작 검증.
# dispatcher는 세 검사(main-commit / missing-issue / claude-attribution)를 순차 실행하므로
# 각 케이스는 실제 hook이 내리는 최종 판정(차단 2 / 통과 0)을 검증한다.

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$TESTS_DIR")"

DISPATCHER="pretooluse-bash.sh"

PASS=0
FAIL=0
FAIL_DESCS=()

# record_result <ok:0|1> <description> <fail_detail>
record_result() {
  local ok="$1" desc="$2" detail="$3"
  if [ "$ok" = "0" ]; then
    echo "  ✓ $desc"
    PASS=$((PASS+1))
  else
    echo "  ✗ $desc ($detail)"
    FAIL=$((FAIL+1))
    FAIL_DESCS+=("$desc")
  fi
}

# run_case <command> <branch> <expected_exit> <description> [extra_branches]
run_case() {
  local cmd="$1" branch="$2" expected="$3" desc="$4" extra="${5:-}"
  local tmp actual
  tmp="$(mktemp -d)"

  (
    cd "$tmp"
    git init -q
    git config user.email "test@test"
    git config user.name "test"
    # 첫 커밋 예외(missing-issue 검사)에 걸리지 않도록 초기 커밋 생성
    git commit --allow-empty -m "init" -q
    # 대상 브랜치로 전환 (기존 default 브랜치를 rename)
    git branch -m "$branch" 2>/dev/null || true
    for b in $extra; do git branch "$b" 2>/dev/null || true; done

    input="$(jq -nc --arg c "$cmd" '{tool_input: {command: $c}}')"
    echo "$input" | bash "$REPO_DIR/scripts/$DISPATCHER" >/dev/null 2>&1
  )
  actual=$?
  rm -rf "$tmp"

  local ok=1; [ "$actual" -eq "$expected" ] && ok=0
  record_result "$ok" "$desc" "expected $expected, got $actual"
}

# run_detect_integration_case <create_develop:yes|no> <expected> <description>
# 로컬 bare 원격을 붙여 detect-integration.sh의 원격 판정을 검증한다.
run_detect_integration_case() {
  local mk_dev="$1" expected="$2" desc="$3"
  local tmp remote actual
  tmp="$(mktemp -d)"; remote="$(mktemp -d)"
  actual="$(
    cd "$tmp"
    git init -q
    git config user.email "test@test"; git config user.name "test"
    git commit --allow-empty -m init -q
    git init -q --bare "$remote/origin.git"
    git remote add origin "$remote/origin.git"
    git push -q origin HEAD:refs/heads/main
    [ "$mk_dev" = yes ] && git push -q origin HEAD:refs/heads/develop
    bash "$REPO_DIR/scripts/detect-integration.sh" 2>/dev/null
  )"
  rm -rf "$tmp" "$remote"
  local ok=1; [ "$actual" = "$expected" ] && ok=0
  record_result "$ok" "$desc" "expected '$expected', got '$actual'"
}

echo "== 검사 1: main/develop 직접 commit·push 차단 =="
# 차단 케이스는 이슈번호(#N)를 포함시켜 missing-issue 검사가 아닌 main-commit 검사로 차단됨을 격리 검증
run_case 'git commit -m "#1 test"'                        main         2 'main 브랜치 commit 차단'
run_case 'git commit -m "#1 test"'                        master       2 'master 브랜치 commit 차단'
run_case 'git push origin main'                           main         2 'main 브랜치 push 차단'
run_case 'git commit -m "feat: #1 test"'                  feat/#1/test 0 'feature 브랜치 commit 통과'
run_case 'git push origin v1.0.0'                         main         0 'main 브랜치 태그 push 통과'
run_case 'git push origin refs/tags/v1.0.0'               main         0 'main 브랜치 refs/tags 태그 push 통과'
run_case 'git commit -m "#1 refs/tags/foo 관련 수정"'     main         2 'commit 메시지의 refs/tags 오탐 방지'
run_case 'git commit -m "#1 test"'                        develop      2 'develop 브랜치 commit 무조건 차단'
run_case 'git commit -m "feat: #1 test"'                  feat/#1/test 0 'develop 있어도 feature commit 통과' "develop"
# 우회 구멍 회귀 방지
run_case 'git commit -m "#1 x" && git push origin v1.0.0' main         2 '복합 명령: 태그 push와 함께여도 main 직접 commit 차단'
run_case 'git push origin v2-hotfix'                      main         2 'v+숫자 브랜치(v2-hotfix)는 태그 아님 → main push 차단'
run_case 'time git commit -m "no issue"'                  feat/#1/test 2 '접두 단어(time) 붙은 commit도 이슈번호 검사'
run_case 'sudo git commit -m "no issue"'                  feat/#1/test 2 '접두 단어(sudo) 붙은 commit도 이슈번호 검사'

echo ""
echo "== 검사 2: 커밋 메시지 이슈 번호 누락 차단 =="
run_case 'git commit -m "feat: 로그인 추가"'              feat/#1/test 2 '이슈 번호 없는 commit 차단'
run_case 'git commit -m "feat: #42 로그인 추가"'          feat/#1/test 0 '이슈 번호 있는 commit 통과'
run_case 'git push origin feat/#1/test'                   feat/#1/test 0 'push 커맨드는 이슈번호 검증 대상 아님'

# HEREDOC 커밋 메시지는 COMMAND 문자열에 이슈 번호가 포함됨
HEREDOC_OK='git commit -m "$(cat <<EOF
feat: #42 로그인 추가
EOF
)"'
run_case "$HEREDOC_OK" feat/#1/test 0 'HEREDOC 커밋 메시지 이슈 번호 감지'

# 오탐 제거
run_case $'git commit -m "don\'t fix #1"'                 feat/#1/test 0 '따옴표 안 작은따옴표(don'"'"'t)로 이슈번호 안 잘림'
run_case 'git commit'                                     feat/#1/test 0 '에디터 커밋(-m 없음)은 검증 불가 → 통과'
run_case 'git commit --amend'                             feat/#1/test 0 'amend 에디터 커밋도 통과'

# -F 파일 경로에 셸 변수·따옴표가 있을 때 오탐 차단 방지
FIX_ISSUE="$(mktemp)";   printf 'fix(k8s): #42 something\n' > "$FIX_ISSUE"
FIX_NOISSUE="$(mktemp)"; printf 'fix(k8s): something\n'      > "$FIX_NOISSUE"
# 셸 변수 경로(미확장)는 파일을 못 읽으므로 fail-open — 명령 문자열에 리터럴 $SP가 남도록 작은따옴표 사용
run_case 'git commit -F "$SP/commit-msg.txt"'      feat/#1/test 0 '-F 변수 경로(미확장)는 검증 불가 → 통과'
run_case "git commit -F \"$FIX_ISSUE\""            feat/#1/test 0 '-F 따옴표 감싼 경로에서 이슈번호 감지'
run_case "git commit -F $FIX_ISSUE"                feat/#1/test 0 '-F bare 경로에서 이슈번호 감지'
run_case "git commit -F \"$FIX_NOISSUE\""          feat/#1/test 2 '-F 따옴표 경로라도 이슈번호 실제 누락이면 차단'
rm -f "$FIX_ISSUE" "$FIX_NOISSUE"

echo ""
echo "== 검사 3: Claude 서명(attribution) 차단 =="
run_case 'git commit -m "feat: #42 로그인 추가"' feat/#1/test 0 '서명 없는 commit 통과'

ATTR_FLAT='git commit -m "feat: #42 로그인 추가

Co-Authored-By: Claude <noreply@anthropic.com>"'
run_case "$ATTR_FLAT" feat/#1/test 2 'Co-Authored-By: Claude 차단'

ATTR_LOWER='git commit -m "feat: #42 test

co-authored-by: claude <noreply@anthropic.com>"'
run_case "$ATTR_LOWER" feat/#1/test 2 '대소문자 무시 차단'

HEREDOC_ATTR='git commit -m "$(cat <<EOF
feat: #42 test

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"'
run_case "$HEREDOC_ATTR" feat/#1/test 2 'HEREDOC 내부 Claude 서명 차단'

# canonical footer(마크다운 링크 형태)는 차단
PR_GEN='gh pr create --title "test" --body "summary

🤖 Generated with [Claude Code](https://claude.com/claude-code)"'
run_case "$PR_GEN" feat/#1/test 2 'PR body의 canonical Generated-with footer 차단'

# 단순 문구/URL 언급(서명 아님)은 통과
PR_MENTION='gh pr create --title "test" --body "Generated with Claude Code 문구 제거 #1"'
run_case "$PR_MENTION" feat/#1/test 0 'Generated with Claude Code 문구 언급만은 통과'

PR_LINK='gh pr create --title "test" --body "see https://claude.com/claude-code"'
run_case "$PR_LINK" feat/#1/test 0 'claude.com/claude-code URL 단순 언급은 통과'

PR_EDIT_ATTR='gh pr edit --body "summary

Co-Authored-By: Claude <noreply@anthropic.com>"'
run_case "$PR_EDIT_ATTR" feat/#1/test 2 'gh pr edit body의 Claude 서명 차단'

PR_OK='gh pr create --title "[feat] #42 로그인" --body "## Summary
- 로그인 추가"'
run_case "$PR_OK" feat/#1/test 0 'Claude 서명 없는 PR 통과'

run_case 'echo "Co-Authored-By: Claude"' feat/#1/test 0 'commit/PR 외 커맨드는 통과'

echo ""
echo "== prefilter: 비-git 명령은 jq 없이 즉시 통과 =="
run_case 'ls -la'                                         main         0 '비-git 명령(ls)은 main에서도 통과'
run_case 'grep -r foo .'                                  develop      0 '비-git 명령(grep)은 develop에서도 통과'

echo ""
echo "== detect-integration.sh =="
run_detect_integration_case yes 'develop remote' '원격 develop 있으면 develop (git-flow)'
run_detect_integration_case no  'main remote'    '원격 develop 없으면 main (GitHub Flow)'

echo ""
echo "---"
echo "Pass: $PASS, Fail: $FAIL"

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "Failed tests:"
  for d in "${FAIL_DESCS[@]}"; do
    echo "  - $d"
  done
  exit 1
fi
