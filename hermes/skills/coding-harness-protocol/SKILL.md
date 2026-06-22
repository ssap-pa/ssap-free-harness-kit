---
name: coding-harness-protocol
description: AI 코딩 하네스 운영규약 — 모든 개발 요청 처리 시 강제 적용. 구현=Claude opus(claude-cli://print), 리뷰/검증/보안/테스트/패치/검수=Codex(codex exec gpt-5.5), 이미지=ChatGPT backend-api adapter. 모델 라우팅·Codex 호출 규칙·고정 흐름·로그 증명·실패 처리·산출물·금지사항·정직성 규약을 정의한다. SOUL.md가 이 스킬을 강제 트리거한다.
---

# 코딩 하네스 운영규약

> SOUL.md의 정체성 선언이 이 스킬을 강제한다. **모든 개발 요청**(코드 생성/수정/리뷰/검증/이미지 포함 작업)은 이 규약대로 처리한다. 사용자는 목표만 말한다.

---

## ■ 모델 / 프로바이더

| 역할 | provider | model | 인증 | 호출/경로 |
|------|----------|-------|------|-----------|
| 구현 | `claude-cli` | `claude-opus-4-8` | — | `base_url=claude-cli://print` |
| 리뷰/검증 | `openai-codex` (Codex 내장 OAuth) | `gpt-5.5` | ChatGPT OAuth | **`codex exec` 공식 CLI 직접호출** |
| 이미지 생성 | `chatgpt-backend-image-adapter` | — | ChatGPT OAuth 세션 | `https://chatgpt.com/backend-api/codex` 계열 내부 경로 |

주의:
- `openai-codex`는 Hermes/Codex 내장 OAuth provider다. **`config.yaml`의 `providers:`에 직접 등록하지 마라** (providers:는 API key 기반 커스텀용).
- Codex 인증은 `hermes auth` 또는 Codex CLI ChatGPT 로그인으로 `auth.json`/token cache에 토큰이 있어야 동작한다 (`~/.codex/auth.json`).
- **backend-api 엔드포인트를 Codex CLI provider base_url로 수동 설정하지 마라.** backend-api는 이미지 어댑터에서만 쓴다.
- Codex CLI는 코드 작업/리뷰/검증용이며, `codex exec` 자체에는 이미지 생성 기능이 없다고 간주한다.
- 단일 인증(ChatGPT OAuth, `~/.codex/auth.json`)을 코드·이미지가 공유하되, **어댑터는 둘로 분리**된다.

리뷰 호출 형식 고정:
```bash
codex exec --skip-git-repo-check -s read-only -m gpt-5.5 "..."
```

---

## ■ 작업 라우팅 규칙

**1. Claude CLI** — 요구사항 해석, 작업 분해, 아키텍처 설계, 파일 생성/수정, 큰 리팩토링, 2개 이상 파일 구조 변경, 테스트/빌드 실행, 최종 통합.

**2. Codex CLI** — 변경 파일 단위 코드 리뷰, git diff 품질 검증, 보안/에지케이스/회귀 위험 탐지, 테스트 시나리오 제안, 작은 1파일 패치, 최종 검수.

**3. ChatGPT backend-api image adapter** — UI/문서/앱용 이미지 생성·편집·변형, 생성 이미지 저장, 결과 경로를 Claude/Codex에 전달.
- 저장 위치: `assets/generated/`
- 파일명: `작업명_YYYYMMDD_HHMMSS.ext`
- 저장 후 파일 존재 여부 + 크기 확인.

---

## ■ Codex 호출 규칙 (가장 중요)

- **대량 단발 요청 금지.** 앱 전체/여러 파일을 한 번에 던지지 마라.
- Codex OAuth는 큰 출력에서 90초 무응답·broken pipe·empty response 발생 가능.
- **파일 1개 = 요청 1개**로 쪼개 순차 호출. 20KB 초과 파일은 청크 분할.
- 리뷰 범위는 변경 파일 목록·git diff·핵심 파일 중심으로 제한. 전체 레포 재작성 요청 금지.

Codex 요청 기본 형식: 변경 목적 / 대상 파일 1개 / 해당 파일 diff·청크 / 확인 관점 / 출력 형식(High·Medium·Low·Nit).

---

## ■ 이미지 생성 호출 규칙

- 이미지는 Claude·Codex가 아니라 backend-api image adapter로 분기.
- 프롬프트에 목적·스타일·크기·투명배경 여부·저장 경로 포함.
- 실패 시 텍스트 설명·SVG를 임의 생성하지 말고 **실패를 기록**한다.
- 생성 이미지는 파일 존재 확인 후 사용. UI 반영은 Claude가, 사용 방식 리뷰는 Codex가.

---

## ■ 매 작업 고정 흐름

1. 요청을 small / medium / large로 분류하고 이유 기록.
2. Claude가 요구사항·파일 구조·작업 단계 설계.
3. Claude가 실제 파일 생성/수정 (답변창에 긴 코드만 뱉고 끝내지 않는다).
4. 이미지 필요 시 backend-api adapter로 생성 → `assets/generated/` 저장.
5. 생성/수정 후 find/ls로 파일 존재 확인.
6. 가능하면 검증 명령 실행: JS/TS `node --check`·`tsc`·build·test / Python `py_compile`·`pytest` / 기타 lint·test·build.
7. Codex가 변경 파일 단위 리뷰.
8. 결과를 High / Medium / Low / Nit 분류.
9. 작은 1파일 수정은 Codex가 직접 처리 가능.
10. 2개 이상 파일·구조 변경·대량 패치는 Claude가 처리.
11. 수정 후 Codex로 재검수.
12. 프로젝트 루트 `AI_HARNESS_LOG.md`에 전 과정 기록.

---

## ■ 피드백 동결 (대화 → 파일, feedback-to-file)

> 근본 원인 차단: 대화에서 합의된 내용은 빌드 핸드오프(서브에이전트/헤드리스/새 컨텍스트)를 넘으면 증발한다. 빌드 에이전트는 대화 기억이 0이고 **파일 + 시작 지시만** 받는다. 디자인만이 아니라 **종류 불문**(디자인·기능·제약·완료기준·엣지케이스·컨벤션) 합의 즉시 파일로 동결해야 살아남는다.

- **합의되는 족족 즉시 파일로 박는다.** 다음 라운드로 넘어가기 전에 동결한다. "나중에 정리"는 금지.

  | 합의 종류 | 동결 위치 |
  |-----------|-----------|
  | 디자인(색·폰트·레이아웃·컴포넌트) | `DESIGN.md` 또는 레포에 커밋된 승인 프리뷰(throwaway 금지) |
  | 기능 요구사항 | `SPEC.md` / 이슈 / 테스트 |
  | 기술 제약·코드 컨벤션·금지 라이브러리·언어/버전 고정 | `CLAUDE.md` |
  | 완료 기준(Acceptance) | `CLAUDE.md`의 Acceptance 절 + 검증 명령 |
  | 엣지케이스 합의 | 테스트 코드 |

- **전체 빌드 지시 직전**: "위 `CLAUDE.md`/`DESIGN.md`/`SPEC.md`/테스트를 **단일 진실원천(SoT)으로 그대로 구현**하라. 새로 설계·재해석 금지"를 핸드오프 프롬프트에 명시한다.
- **검증 단계(고정 흐름 6·11)**: 산출물이 동결 파일과 일치하는지 대조한다. 불일치 시 "완료" 선언 금지 — 동결본 기준으로 정정한다(정직성 조항).
- 피드백 라운드가 있었는데 SoT 파일이 비어 있으면 **먼저 동결**한 뒤 빌드한다.

---

## ■ 로그 / 증명

- 모델 라우팅은 자기보고가 아니라 `~/.hermes/logs/agent.log`로 증명한다.
- 보고 시 작업별로: provider / model / base_url·endpoint / 출력 토큰 / 로그 라인 번호 / 호출 시각.

라우팅 확인 기준:
- Claude CLI: `base_url=claude-cli://print`
- Codex CLI: `provider=openai-codex`, `model=gpt-5.5`, backend endpoint는 공식 CLI 내부 연결로만 확인.
  - ※ `codex exec`는 외부 CLI라 agent.log에 안 찍히므로, 라우팅 증명은 **codex exit code + 출력 + `codex login status`**로 한다 (agent.log 증명 규칙의 유일한 명시적 예외).
- Image adapter: `provider=chatgpt-backend-image-adapter`, `endpoint=https://chatgpt.com/backend-api/codex` 계열, 목적=image generation/edit.

주의: **session_id만으로 라우팅을 증명하지 마라.** 과거 같은 session_id가 다른 provider였을 수 있다. 반드시 턴 시각 + 라인 범위로 좁힌 개별 API call 기준으로 확정한다.

---

## ■ 메트릭 비손기록 (no-hand-metrics)

> 근본 원인 차단: 정량 수치를 손으로 적으면 추정치가 물증인 척 샌다. 모든 숫자는 권위 출처에서 명령으로 추출한다.

- **토큰·비용·exit code·세션ID·시각 등 모든 정량 수치는 손으로 적지 않는다.** 기억·추정으로 채우지 마라.
- 반드시 권위 출처에서 명령으로 추출해 기록한다:
  - Codex 토큰/세션 → `~/.codex/sessions/<id>.jsonl` 의 `total_token_usage` (jq/grep으로 추출)
  - Codex exit/인증 → `codex` 프로세스 exit code + `codex login status`
  - Claude 경로/세션 → `~/.hermes/logs/agent.log` 의 해당 session 라인
- 기록할 때 **추출에 쓴 세션ID·파일경로·명령**을 같이 남겨 재검증 가능하게 한다.
- 출처를 댈 수 없는 수치는 **"미측정"** 으로 적고 추정치를 쓰지 않는다.
- 검증 단계(고정 흐름 6·11)에서 보고 전 모든 수치를 로그에서 재추출해 대조한다. 자가보고 값과 실측이 다르면 **실측으로 정정하고 정정 사유를 기록**한다(정직성 조항).

---

## ■ 실패 처리

다음은 반드시 `AI_HARNESS_LOG.md`와 `agent.log` 근거로 기록: fallback / silent hang / empty response / no first byte / broken pipe / image adapter failure / auth token expired / rate limit / backend-api schema changed.

규칙:
- 실패 시 **몰래 다른 모델·provider로 바꾸지 마라.**
- fallback이 0건이면 0건이라고 명시.
- 이미지 실패 시 임의 대체 이미지 금지.
- 실패한 작업은 보류 항목으로 분리.

---

## ■ 산출물

필수: `AI_HARNESS_LOG.md` / `CODEX_REVIEW.md`(또는 `CODEX_REVIEW_*.md`) / 변경 파일 목록 / 실행한 검증 명령과 결과 / 남은 보류 항목.

피드백 라운드가 있었던 작업은 추가: 동결 파일(`CLAUDE.md`·`DESIGN.md`·`SPEC.md` 중 해당) + 산출물↔동결본 일치 확인 결과.

이미지 작업 포함 시 추가: `IMAGE_GENERATION_LOG.md` / 생성 이미지 경로 / 이미지 프롬프트 / provider·endpoint 로그 근거 / 파일 존재·크기 확인 결과.

---

## ■ 금지사항

- GPT OAuth로 앱 전체를 한 번에 생성 금지.
- Codex에 앱 전체를 한 번에 리뷰시키기 금지.
- backend-api를 Codex CLI provider base_url로 수동 등록 금지.
- `codex exec`로 이미지 생성 시도 금지.
- 실제 파일 생성 없이 완료 선언 금지.
- 검증 명령 없이 정상작동 단정 금지.
- Codex 리뷰 없이 완료 처리 금지.
- 실패 로그 은폐 금지.
- 라우팅 증명 없이 "Claude가 했다 / Codex가 했다 / backend-api가 했다" 금지.
- 대화에서만 합의하고 파일로 동결하지 않은 채 전체 빌드로 핸드오프 금지(디자인·기능·제약·완료기준 불문).

---

## ■ 정직성

- "Codex로 리뷰가 라우팅돼 응답을 받았다" ≠ "리뷰 내용이 옳다".
- 라우팅은 agent.log(또는 Codex exit/login status)로 증명, 품질은 `CODEX_REVIEW*.md`로 판단, 이미지 성공은 파일 저장·검증으로 판단.
- 코드로 만들 수 없는 것(실결제 키·실DB·실제 배포·외부 마케팅 성과)은 "완성"이라 하지 말고 보류 항목으로 구분한다.
