#!/bin/bash
# main/master/develop(통합 브랜치) 직접 commit/push 차단

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "jq가 설치되어 있지 않아 훅을 실행할 수 없습니다. 설치 후 다시 시도하세요." >&2
  exit 1
fi

INPUT="$(cat)"
COMMAND="$(echo "$INPUT" | jq -r '.tool_input.command // empty')"

if [[ "$COMMAND" =~ (^|[[:space:];|&])(git[[:space:]]+(commit|push))([[:space:]]|$) ]]; then
  # 태그 push는 허용 (git push origin v1.0.0 또는 refs/tags/)
  # commit 메시지 본문의 refs/tags 문자열로 우회되지 않도록 push 커맨드일 때만 예외 적용
  if [[ "$COMMAND" =~ git[[:space:]]+push ]]; then
    if [[ "$COMMAND" =~ refs/tags/ ]] || [[ "$COMMAND" =~ git[[:space:]]+push[[:space:]]+[^[:space:]]+[[:space:]]+v[0-9] ]]; then
      exit 0
    fi
  fi
  BRANCH="$(git branch --show-current 2>/dev/null || true)"
  if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ] || [ "$BRANCH" = "develop" ]; then
    echo "main/master/develop 등 통합 브랜치에서 직접 commit/push할 수 없습니다. 작업 브랜치를 사용하세요." >&2
    exit 2
  fi
fi

exit 0
