#!/bin/bash
# SessionStart: 플러그인 rules를 ~/.claude/rules/에 symlink로 연결
# - dev-plugin-* prefix로 다른 rules와 네임스페이스 분리
# - dangling symlink 방지 위해 매 세션마다 기존 dev-plugin-* 정리 후 재생성

set -euo pipefail

RULES_DIR="${CLAUDE_PLUGIN_ROOT}/rules"
TARGET_DIR="${HOME}/.claude/rules"

if [ ! -d "$RULES_DIR" ]; then
  exit 0
fi

mkdir -p "$TARGET_DIR"

find "$TARGET_DIR" -maxdepth 1 -name "dev-plugin-*.md" -delete 2>/dev/null || true

for f in "$RULES_DIR"/*.md; do
  [ -f "$f" ] || continue
  ln -s "$f" "$TARGET_DIR/dev-plugin-$(basename "$f")"
done
