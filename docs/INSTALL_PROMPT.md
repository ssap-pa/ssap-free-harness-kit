# One-paste installer prompt

Two ways to install the harness into a Hermes profile.

## Method A — clone + run (recommended)

```bash
git clone https://github.com/<owner>/harness-kit.git
cd harness-kit
./install.sh                 # backs up then installs SOUL.md + the skill
./install.sh --dry-run       # preview without changing anything
./bin/preflight.sh           # confirm Claude + Codex reachable on subscription auth
```

## Method B — hand the prompt to your own Hermes

If you'd rather let your Hermes agent do it, paste the whole block below into your
Hermes chat. It clones the repo and runs the installer, then verifies on disk.

````text
너는 지금부터 내 Hermes에 "AI 코딩 하네스"를 설치한다. 아래를 그대로 수행하고,
중간에 묻지 말고 끝까지 한 뒤 실제 파일 존재와 내용으로 검증해서 결과만 보고해라.

1. 작업 디렉토리에서 harness-kit 저장소를 클론한다:
   git clone https://github.com/<owner>/harness-kit.git
2. cd harness-kit && ./install.sh --force 를 실행한다.
   (이 스크립트는 ~/.hermes/SOUL.md 와
    ~/.hermes/skills/software-development/coding-harness-protocol/SKILL.md 를
    백업 후 설치한다. 토큰 0짜리 순수 쉘이다.)
3. ./bin/preflight.sh 를 실행해 Claude·Codex가 구독 인증으로 도달 가능한지 확인한다.
4. 설치 검증: 아래 두 파일이 실제로 존재하고 내용이 맞는지 read로 확인한다.
   - ~/.hermes/SOUL.md  (첫 줄이 "# Hermes Agent Persona", 본문에 "AI 코딩 하네스 오케스트레이터")
   - ~/.hermes/skills/software-development/coding-harness-protocol/SKILL.md
     (frontmatter name: coding-harness-protocol)
5. preflight 결과(exit code)와 두 파일의 존재/첫 줄을 물증으로 보고한다.
   설치가 안 됐으면 안 됐다고 정직하게 말하고, 추정으로 성공을 지어내지 마라.

사전조건 — 연결할 3가지 (없으면 그 사실을 보고):
- Claude CLI : 빌드/오케스트레이션 엔진 (Hermes 메인 provider = claude-cli / claude-opus-4-8)
- Codex CLI : 리뷰/검증 엔진 (npm i -g @openai/codex)
- ChatGPT 로그인 : Codex CLI 인증 (codex login → codex login status 가 "Logged in using ChatGPT")
설치 후, 코딩 요청을 보내면 Hermes 가 coding-harness-protocol 을 자동 로드해
12단계 규약대로 처리하고, 완료 전 bin/gate.sh 게이트를 통과해야 한다.
````

> Replace `<owner>` with the actual GitHub owner/org before sharing.
