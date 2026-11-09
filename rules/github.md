# Git 컨벤션

## Flow

```
Issue 생성 → Branch 생성 → Commit → Push → Pull Request
```

## 타입 (Branch / Commit / PR 공통)

Branch·Commit·PR 모두 [Conventional Commits](https://www.conventionalcommits.org/) 표준 타입을 쓴다. 여기에 **Branch 전용**으로 두 개를 더한다.

- `hotfix`: 긴급 수정
- `release`: 배포 준비

`hotfix`/`release` 브랜치 안의 커밋은 내용 성격에 맞춰 `fix`, `chore` 등 표준 타입을 쓴다.

## Issue 생성 컨벤션

영어 섹션 헤더 + 한국어 내용. 가이드는 HTML 주석(생성된 이슈엔 안 보임), 이모지·특수문자 배제. Description·Goal·Acceptance Criteria는 코어(항상), 나머지는 확장(해당 시에만).

```markdown
## Description
<!-- 문제와 배경 (why & what), 1-2문장 -->

## Goal
<!-- 의도: 무엇을 이루려는가 -->
- <이루려는 것>

## Acceptance Criteria
<!-- 검증 가능한 완료 조건: 어떻게 확인하는가 -->
- [ ] <완료 기준>

<!-- 확장(해당 시에만):
     Reproduction — 버그: 최소 재현 단계 / 기대 vs 실제 / 환경
     Impact — API·데이터 모델·권한·배포·경계 변경
     긴 로그·출력은 <details>로 접는다. -->
```

## Branch 네이밍

```
<타입>/#<이슈번호>/<간단한-설명>
```

예: `feat/#1/add-login-page`, `hotfix/#3/fix-payment-error`

## Commit 메시지

```
<타입>(<영역>): #<이슈번호> <간단한 설명>

- **<해결 or 구현>**
  - <세부 내용>
```

예시:
```
feat(etl): #21 etl.iceberg_sync_checkpoint 테이블 추가

- **구현**
  - IcebergSyncCheckpointModel SQLAlchemy 모델 추가
  - etl.iceberg_sync_checkpoint 테이블 Alembic 마이그레이션 추가
```

## Pull Request

제목: `[타입] #<이슈번호> <간단한 설명>`

본문:
```markdown
## Summary
- <무엇을 왜 바꿨나 (what & why)>

## Test Plan
- <검증 방법: 실행 명령·확인 절차>
- <실행 결과 첨부 권장. 검증 불가 시 N/A + 사유>

## Related Issues
- close #<이슈번호>
```

PR이 close하는 Issue를 `Related Issues`에 명시한다.

변경이 여러 파일·영역에 걸치면 `## Summary`를 표로 요약한다 (아래 "리치 포맷" 참고).

## 리치 포맷 (Issue / PR 본문)

Issue·PR 본문은 GitHub 웹에서 렌더링되므로 가독성이 올라갈 때 리치 요소를 쓴다. **판단이 서지 않으면 plain markdown이 기본값**이다. 커밋 메시지는 `git log`에서 plain text로 보이므로 대상이 아니다.

무엇을 언제 쓸지만 정한다(문법은 GitHub 표준을 따른다).

| 요소 | 사용 기준 |
|------|-----------|
| 표 | 항목 3개 이상 × 축 2개 이상(비교·매트릭스·변경 요약). 단순 나열은 bullet |
| `<details>` | 20줄 넘는 로그·스택트레이스·diff·명령 출력. 본문엔 결론만, 원문은 접는다 |
| alert (`[!WARNING]`·`[!IMPORTANT]` 등) | 되돌리기 어려운 영향(마이그레이션·삭제·breaking)이나 리뷰어가 놓치면 안 되는 항목 1건 |
| mermaid | 흐름·관계·순서가 글보다 그림이 명백히 빠를 때(아키텍처 경계 변경, 다중 서비스 시퀀스, 상태 전이). 3노드 이하면 문장으로 |

LaTeX·GeoJSON·STL·`<kbd>`·첨자·색상칩 등은 이 팀 도메인에서 사용 빈도가 낮아 규칙 대상에서 제외한다.

## 커밋 메타데이터

- 커밋 메시지에 `Co-Authored-By: Claude` 등 Claude attribution 문구를 포함하지 않는다.

## 브랜치 작업공간

- 운영 기준 브랜치(`main`/`master`, git-flow면 `develop`)에 직접 commit/push하지 않는다. 모든 변경은 작업 브랜치에서 PR로 머지한다. (hook이 차단)

## 태그

`v<MAJOR>.<MINOR>.<PATCH>` (예: `v1.0.0`). 버전은 SemVer를 따른다.
