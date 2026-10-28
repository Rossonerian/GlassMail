# GlassMail v1.0.0 Release Ledger

Supervisor-owned. Only the supervisor sets `VERIFIED`.
Worker policy: allowed workers are Codex, Gemini, Copilot. No Claude/Anthropic-backed agent is ever invoked as worker, reviewer, or fallback. (The supervising session itself is whatever model the harness runs; it delegates only to the three allowed worker families.)

V1_CANONICAL_APP=NATIVE_KOTLIN (applicationId `com.glassmail.app`). `flutter_app/` is experimental.

Baseline: branch `main`, HEAD `6c3babc27fccf7b24c9c702c42007431b2db9b52` (= `origin/main`). Work branch: `release/v1.0.0-hardening` (PR #31).
Pre-existing remote tag `v1.0.0` -> `173f6fa` ("chore(release): prepare v1.0.0") was created prematurely (CI red, unsigned, no live Gmail acceptance). Must be deleted/re-pointed only when all gates pass.

## Worker availability (observed 2026-10-05)

| Worker | Route | Status |
| --- | --- | --- |
| Codex | `codex exec` (gpt-6.1-sol), sandbox workspace-write; cannot run Gradle (socket denied) so supervisor runs Gradle | AVAILABLE |
| Gemini | Antigravity `worker_primary` via `agent-team-orca-start` (Orca run `run_b791f45d2439`) | AVAILABLE (first attempt died on agent-terminal network error; retry succeeded). `gemini` CLI needs interactive login — not used |
| Copilot | `copilot -p --model <non-Claude>` | BLOCKED: every non-Claude model (gpt-6.1-sol, gpt-6-sol, gpt-6-luna, gpt-5.6-*, gpt-5.5, gpt-5.4, gpt-5.3-codex, gpt-5-mini, gemini-3.8-flash) returns `Model ... is not available`; only Claude models are listed and `auto` may route to Claude, so Copilot is NOT used. Review scope reassigned to read-only Codex reviews. |

## Ledger

| PHASE | TASK | WORKER | STATUS | EVIDENCE | BLOCKERS | NEXT |
| --- | --- | --- | --- | --- | --- | --- |
| 0 | Repo audit `V1_RELEASE_AUDIT.md` | Supervisor | REVIEW | audit written; updated as findings arrive | - | update after each milestone |
| 0 | Release-readiness audit | Gemini worker_primary | REVIEW | `/tmp/gm/gemini_audit_report.md` (12 findings). Supervisor verdicts: G1 test compile = TRUE (fixed). G2 offline archive resurrection = PARTIAL (only on batch overlap; real defect is no server-state reconcile). G3 history/50-msg + checkpoint = TRUE (confirmed `INITIAL_MAIL_LIMIT=50`, no backfill, Sync.md contradicts). **G4 "FTS triggers missing" = REJECTED**: Room generates the 4 triggers in generated `_Impl` (Codex review verified); real defect was quoting. G5 Sent APPEND duplicates = TRUE (Gmail SMTP auto-files Sent). G6 removal residue = TRUE. G7 IDLE uncancellable = TRUE (to verify in fix). G8 docs contradictions = TRUE. G9 minSdk 34 = intentional, document. G11 notices gaps = TRUE. G12 String(password) = LOW, documented. | - | fixes below |
| 1 | Fix CI | Codex | REVIEW | PR #31: setup-android/setup-flutter removed; native job now reaches Gradle (earlier run failed on real test compile error, now fixed); Flutter runs reached `flutter test` and fail on stale committed test `widget_test.dart:35` (`mail-dock-expanded` key absent from committed lib) | remote native run green not yet observed | wait for run on 4168e45+, fix Flutter test |
| 1 | Unit-test compile fix (AppViewModelTest) | Codex | VERIFIED(local) | supervisor `./gradlew test` BUILD SUCCESSFUL; `lintDebug assembleDebug assembleRelease` BUILD SUCCESSFUL | remote | confirm in CI |
| 3 | Release engineering (versionName 1.0.0/code 10000, strict signing, release.yml, release-notes script, CHANGELOG, checklist) | Codex | REVIEW | committed 4168e45; supervisor ran `GLASSMAIL_REQUIRE_RELEASE_SIGNING=true ./gradlew :app:assembleRelease` -> fails with clear message (no secrets printed) | signing secrets are USER-supplied; signed build with throwaway key still to be exercised | signed dry-run with throwaway key; Gemini review of release.yml |
| 4 | DB migration review | Codex read-only (Copilot unavailable) | VERIFIED | report `/tmp/gm/codex_migr_out.md`: F1 BLOCKER 7->8 FTS quoting; others below | - | - |
| 4 | DB fixes part 1 (F1 FTS SQL, observeThread account scope, transactional removal, migration tests) | Codex | VERIFIED | `:core:database:testDebugUnitTest :core:database:connectedDebugAndroidTest` on Pixel 9a (Android 17): 20 tests passed; migration tests use MigrationTestHelper validating each step 1..9->10, full 1->10 and 7->10 with data; committed | - | - |
| 4 | DB part 2: UIDVALIDITY correctness (mutation target validity, detect before fetch, detached v2 mutations) | Codex | NOT_STARTED | review findings 2,3,4 | - | after S3 |
| 5 | S3: Gmail Sent-duplicate, account-removal completeness, IDLE cancellation | Codex | IN_PROGRESS | task launched | - | review, build, test |
| 5/6 | S2: server-state reconciliation of cached Inbox (flags/labels/expunge), history backfill / load-older, honest Sync.md | Codex | NOT_STARTED | Gemini G3 + code read: sync only fetches new UIDs (>checkpoint); first sync = newest 50 only; no flag sync for existing messages | scope decision: implement bounded reconcile + backfill to cache limit | after DB part 2 |
| 7 | Real Gmail acceptance | - | NOT_STARTED | no disposable Gmail test credential supplied | **BLOCKED_BY_TEST_CREDENTIAL** | USER must supply dedicated test account + app password |
| 8 | Device acceptance | Supervisor | NOT_STARTED | Pixel 9a, Android 17 attached | - | after fixes |
| 10 | Dependency / licence audit | Gemini then Codex | NOT_STARTED | Gemini noted nav-compose/activity-compose/core-ktx missing from notices | - | run full audit after code freeze |
| 11 | Docs/README/privacy/repo description | Codex + Supervisor | NOT_STARTED | contradictions listed by Gemini G8 | - | after code freeze |
