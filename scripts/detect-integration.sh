#!/bin/bash
# 통합 브랜치 판정 (canonical) — /session-start·/session-end 공통 호출.
# 원격 develop 있으면 develop(git-flow), 없으면 main(GitHub Flow). 오프라인이면 로컬 폴백.
# stdout 1행: "<branch> <source>"  source ∈ {remote, local-cache}
#
# 스킬 bash엔 CLAUDE_PLUGIN_ROOT가 없어, 스킬은 ${CLAUDE_SKILL_DIR}/../../scripts/detect-integration.sh
# (공식 문자열 치환, ../../ = 플러그인 루트)로 이 스크립트를 참조한다.

set -uo pipefail

# ls-remote는 원격에 닿으면(브랜치 유무와 무관) exit 0, 연결 실패면 non-zero.
# 성공 시 출력 유무로 develop 존재를 판정하고, 실패 시 로컬 원격추적 ref로 폴백한다.
if out="$(git ls-remote --heads origin develop 2>/dev/null)"; then
  [ -n "$out" ] && echo "develop remote" || echo "main remote"
else
  git show-ref --verify --quiet refs/remotes/origin/develop \
    && echo "develop local-cache" || echo "main local-cache"
fi
