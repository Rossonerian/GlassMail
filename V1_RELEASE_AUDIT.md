# GlassMail v1.0.0 Release Audit (Phase 0)

Baseline: `main` @ `6c3babc27fccf7b24c9c702c42007431b2db9b52` (= `origin/main`, observed 2026-10-05).
**V1_CANONICAL_APP=NATIVE_KOTLIN** (`com.glassmail.app`). Reasoning: Flutter host uses dev id `com.glassmail.dev.glassmail`, imports no Room data or credentials (README), has no parity evidence; a cutover would orphan existing native users' data. Flutter stays experimental.

Columns: AREA | STATUS | EVIDENCE | RISK | OWNER | ACTION | RELEASE_BLOCKER

| AREA | STATUS | EVIDENCE | RISK | OWNER | ACTION | RELEASE_BLOCKER |
| --- | --- | --- | --- | --- | --- | --- |
| CI native (`android.yml`) | FIXED (pending remote green) | All 4 jobs red at HEAD: `gh api .../actions/runs/36469865609/jobs` shows `android-actions/setup-android@v3` failing; jobs never reached gradle. PR #31 removes it; remote run now reaches Gradle. | Was: nothing ever tested in CI | Codex | verify remote green on PR | YES until green |
| Native unit tests | FIXED | `AppViewModelTest.kt` did not compile (`uiState`, `putCredential`, `scheduleSynchronize` don't exist) — latent since CI never reached tests. Codex rewrote tests; supervisor ran `./gradlew test` -> BUILD SUCCESSFUL. | Test suite had zero signal | Codex | done | NO |
| Native lint/assembleDebug/assembleRelease (R8) | PASS locally | supervisor: `lintDebug :app:assembleDebug :app:assembleRelease` BUILD SUCCESSFUL (unsigned release) | - | Supervisor | repeat in CI | NO |
| CI Flutter (`flutter.yml`, dup `flutter_ci.yml`) | PARTIAL | setup-flutter@v4.2 failed on macOS; replaced by pinned subosito 3.47.5. Now fails in real test: `widget_test.dart:35` expects key `mail-dock-expanded` that does not exist in committed `lib/` (key only referenced by user's untracked WIP tests). | Experimental track red | Codex | reconcile committed test with committed UI (do not touch untracked WIP) | NO (experimental) but must not look red |
| Release workflow | MISSING | No `release.yml`; only `.github/workflows/{android,flutter,flutter_ci}.yml` | Cannot produce signed artifact | Codex | Phase 3 task in progress | YES |
| Version | WRONG | `app/build.gradle.kts`: versionCode=1, versionName="1.0" | - | Codex | 1.0.0 / 10000 | YES |
| Signing | UNCONFIGURED | env-var config exists; unsigned silently when absent; no keystore secrets in repo (correct) | unsigned APK could be published | Codex + USER | strict mode + secrets | YES (external: user must create keystore & GH secrets) |
| Premature tag | PROBLEM | remote tag `v1.0.0` -> `173f6fa` ("prepare v1.0.0"), no GitHub Release | tag would trigger release workflow on wrong commit; false claim | Supervisor | delete/re-point only when all gates pass | YES |
| Database migrations | BLOCKER FOUND | Codex read-only review: 7->8 FTS SQL `content='messages'` vs Room-expected ``content=`messages` `` => every 1..7->10 upgrade fails Room validation. Also: pending mutations store UID without UIDVALIDITY (HIGH), reset detected after fetch (HIGH), detached v2 mutations lose target (MED), account delete doesn't cascade notification/cache/quota rows (MED), observeThread not account-scoped (MED), only 3->4 tested (MED). No destructive fallback (good). | data loss / wrong-message mutation | Codex | part1 task running (F1,F2,F3,tests); part2 UIDVALIDITY | YES |
| Gmail live acceptance | NOT DONE | no disposable test credential supplied | Core claims unproven | USER | BLOCKED_BY_TEST_CREDENTIAL | YES |
| Device acceptance | AVAILABLE | adb: Pixel 9a (`5B271XEBF3XDF0`), Android 17 | - | Supervisor | run after build | YES |
| Logging/credential leakage | OK (grep) | no `Log.*` calls in app/core/data/domain/sync | verify HTML/URL logs | Supervisor | Gemini audit | NO |
| Backup | OK | `android:allowBackup="false"` in manifest | check dataExtractionRules | Gemini | confirm | NO |
| README/privacy claims | UNVERIFIED | README claims IDLE service, undo send, 2 accounts, remote drafts; FUNCTIONAL_STATUS itself lists these as "Unverified" | claims > evidence | Gemini audit + Supervisor | align after acceptance | YES |
| THIRD_PARTY_NOTICES | UNVERIFIED | 41 lines; not compared to lockfiles | licence completeness | Gemini then Codex | Phase 10 | YES |
| Repo description | STALE | "A liquid glass concept based Email client ... Maybe add some AI but optional idk." | looks unfinished | Supervisor | `gh repo edit` at release | NO |
| TODO/FIXME in native code | CLEAN | grep: 0 hits in app/core/data/domain/sync/designsystem | - | - | - | NO |
| Repo hygiene | NOTE | untracked user files: `fix_*.py`, `test_*.dart`, `flutter_app/{artifacts,docs/release-evidence}`, WIP Dart files/tests. Preserved; not committed by supervisor. | - | User | untouched | NO |
| Worker availability | NOTE | Copilot: no non-Claude model available to account (every gpt-*/gemini model returns `not available`); not used. Gemini CLI unauthenticated; Antigravity workers via Orca used. | review coverage | Supervisor | Codex read-only reviews substitute | NO |
