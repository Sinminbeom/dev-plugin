#!/bin/bash
# PreToolUse "Bash" 가드: git/gh 명령에 세 검사를 실행한다.
#   1. main/master/develop 직접 commit/push 차단
#   2. 커밋 메시지 이슈 번호(#N) 누락 차단
#   3. 커밋/PR 본문의 Claude 서명 차단
# exit: 0=통과, 2=차단(사유는 stderr), 1=jq 미설치

set -uo pipefail

# NUL 구분자로 stdin 전체를 읽는다(JSON엔 NUL 없음). EOF에서 read는 non-zero → || true.
IFS= read -r -d '' INPUT || true

# prefilter: 검사 대상이 전부 git/gh라 토큰이 없으면 파싱 없이 통과(비-git 명령은 fork 0).
# 부분일치 오탐은 파싱 후 통과할 뿐, 실제 git/gh 누락은 없다.
case "$INPUT" in
  *git*|*gh*) ;;
  *) exit 0 ;;
esac

if ! command -v jq >/dev/null 2>&1; then
  echo "jq가 설치되어 있지 않아 훅을 실행할 수 없습니다. 설치 후 다시 시도하세요." >&2
  exit 1
fi

COMMAND="$(jq -r '.tool_input.command // empty' <<< "$INPUT")"
[ -n "$COMMAND" ] || exit 0

# -F·--body-file 경로 토큰의 양끝 따옴표만 벗긴다. 셸 변수·명령치환은 확장하지 않는다(eval 위험).
strip_quotes() {
  local s="$1"
  s="${s#[\"\']}"
  s="${s%[\"\']}"
  printf '%s' "$s"
}

# --- 1. main/master/develop 직접 commit/push 차단 ---
check_main_commit() {
  if [[ "$COMMAND" =~ (^|[[:space:];|&])(git[[:space:]]+(commit|push))([[:space:]]|$) ]]; then
    # commit은 항상 검사 — `git commit ... && git push v1.0.0`이 태그 push로 통째 통과되던 우회 차단.
    local has_commit=0 push_blocks=0
    if [[ "$COMMAND" =~ (^|[[:space:];|&])git[[:space:]]+commit([[:space:]]|$) ]]; then
      has_commit=1
    fi
    if [[ "$COMMAND" =~ (^|[[:space:];|&])git[[:space:]]+push([[:space:]]|$) ]]; then
      # 태그 push만 예외(refs/tags/ 또는 v<major>.<minor>…). v2-hotfix는 브랜치라 제외.
      if [[ "$COMMAND" =~ refs/tags/ ]] \
         || [[ "$COMMAND" =~ git[[:space:]]+push[[:space:]]+[^[:space:]]+[[:space:]]+v[0-9]+\.[0-9] ]]; then
        :
      else
        push_blocks=1
      fi
    fi
    if [ "$has_commit" = 0 ] && [ "$push_blocks" = 0 ]; then
      return 0
    fi
    # 브랜치명만으로 차단 — develop 위면 곧 통합 브랜치이고 GitHub Flow엔 develop이 없어 오탐 없음.
    local branch
    branch="$(git branch --show-current 2>/dev/null || true)"
    if [ "$branch" = "main" ] || [ "$branch" = "master" ] || [ "$branch" = "develop" ]; then
      echo "main/master/develop 등 운영 기준 브랜치에서 직접 commit/push할 수 없습니다. 작업 브랜치를 사용하세요." >&2
      return 1
    fi
  fi
  return 0
}

# --- 2. 커밋 메시지 이슈 번호(#N) 누락 차단 ---
check_missing_issue() {
  # 명령 경계 앵커로 time·sudo 등 접두 단어 붙은 commit도 잡는다.
  if [[ "$COMMAND" =~ (^|[[:space:];|&])git[[:space:]]+commit([[:space:]]|$) ]]; then
    if ! git rev-parse HEAD >/dev/null 2>&1; then
      return 0  # 첫 커밋
    fi

    # -m 메시지 추출. 여는 따옴표 종류를 구분해 내부 따옴표(예: "don't ... #1")로 안 잘리게 한다.
    local msg="" has_source=0 unverifiable=0
    local re_dq='-m[[:space:]]+"([^"]*)"'
    local re_sq="-m[[:space:]]+'([^']*)'"
    if [[ "$COMMAND" =~ $re_dq ]]; then
      msg="${BASH_REMATCH[1]}"; has_source=1
    elif [[ "$COMMAND" =~ $re_sq ]]; then
      msg="${BASH_REMATCH[1]}"; has_source=1
    elif [[ "$COMMAND" =~ -m[[:space:]]+([^[:space:]]+) ]]; then
      msg="${BASH_REMATCH[1]}"; has_source=1
    fi

    # -F 경로 읽기. 셸 변수 미확장으로 파일을 못 읽으면 unverifiable(확인 불가).
    if [[ "$COMMAND" =~ -F[[:space:]]+([^[:space:]]+) ]]; then
      has_source=1
      local file
      file="$(strip_quotes "${BASH_REMATCH[1]}")"
      if [ -f "$file" ]; then
        msg="$msg
$(cat "$file")"
      else
        unverifiable=1
      fi
    fi

    if [[ "$msg" =~ \#[0-9]+ ]]; then
      return 0
    fi

    # HEREDOC 블록만 추출한다(COMMAND 전체 검색은 URL/경로 내 #N 오탐).
    local heredoc_msg
    heredoc_msg="$(awk '
      !started && match($0, /<<[[:space:]]*['\''"]*[A-Za-z_][A-Za-z0-9_]*['\''"]*/) {
        delim = substr($0, RSTART, RLENGTH)
        gsub(/^<<[[:space:]]*['\''"]*/, "", delim)
        gsub(/['\''"]*$/, "", delim)
        started = 1
        next
      }
      started && $0 == delim { started = 0; next }
      started { print }
    ' <<< "$COMMAND")"
    if [[ "$heredoc_msg" =~ \#[0-9]+ ]]; then
      return 0
    fi
    [ -n "$heredoc_msg" ] && has_source=1

    # 소스가 없거나(에디터 커밋) 확인 불가면 메시지를 볼 수 없으므로 차단하지 않는다(fail-open).
    if [ "$has_source" = 0 ] || [ "$unverifiable" = 1 ]; then
      return 0
    fi

    echo "커밋 메시지에 이슈 번호(#번호)가 없습니다. 예시: feat(auth): #42 로그인 API 추가" >&2
    return 1
  fi
  return 0
}

# --- 3. 커밋/PR 본문의 Claude 서명(canonical footer) 차단 ---
# 실제 생성되는 footer만 차단하고 문구 단순 언급은 통과. 생성 자체 예방은
# settings.json의 attribution="" (README 참고).
check_claude_attribution() {
  if ! [[ "$COMMAND" =~ (^|[[:space:];|&])(git[[:space:]]+commit|gh[[:space:]]+pr[[:space:]]+(create|edit))([[:space:]]|$) ]]; then
    return 0
  fi

  # -F/--body-file 파일 내용까지 합쳐 검사한다.
  local msg="$COMMAND" flag file
  for flag in '-F' '--body-file'; do
    if [[ "$COMMAND" =~ ${flag}[[:space:]]+([^[:space:]]+) ]]; then
      file="$(strip_quotes "${BASH_REMATCH[1]}")"
      if [ -f "$file" ]; then
        msg="$msg
$(cat "$file")"
      fi
    fi
  done

  if grep -qiE 'co-authored-by:.*noreply@anthropic\.com|\[claude code\]\(https?://claude\.com/claude-code' <<< "$msg"; then
    echo "커밋 메시지/PR 본문에 Claude 서명(Co-Authored-By: Claude, 🤖 Generated with [Claude Code] 등)을 포함할 수 없습니다." >&2
    echo "관련 규칙: rules/session.md → 커밋 규칙" >&2
    return 1
  fi
  return 0
}

if ! check_main_commit; then exit 2; fi
if ! check_missing_issue; then exit 2; fi
if ! check_claude_attribution; then exit 2; fi

exit 0
