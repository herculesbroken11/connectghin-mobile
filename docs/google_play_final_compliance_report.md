# Google Play Final Compliance Audit

Date: 2026-09-15  
App: Connectghin (`com.connectghin.app`)  
Version prepared: **1.0.2+24**

## Executive Summary

Code-level Metadata and several safety/copy gaps were fixed for resubmission after Google’s conditional appeal acceptance. **Reviewer login remains primarily an operations/Play Console credential problem**: the app correctly calls production and maps failed auth to “Invalid email or password.” Google’s “Invalid credentials” screenshot matches a real 401 against production when the supplied account does not exist or the password is wrong.

**Conditional GO for code/build** — only after a human verifies the Play Console reviewer credentials on a clean production install and updates the store listing/screenshots.

## Google-Named Issues

### Reviewer Login
**MANUAL TEST REQUIRED** (app-side mapping FIXED)

- Release API: `https://api.connectghin.com/api/v1`
- Login body: `{ email, password }`
- Backend 401 “Invalid credentials” now surfaces as **Invalid email or password**
- Network failures surface a connection error (not login failure)
- No reviewer backdoor added
- See `docs/google_play_reviewer_account_checklist.md`

### Metadata
**FIXED** (listing still MANUAL)

- Removed “premier golf network” register tagline → “Find golf partners near you”
- Store listing source of truth: `docs/google_play_store_listing_final.md`
- Do **not** reuse graphics with “Your Premier Golf Network”

## Critical Release Blockers

1. **Play Console reviewer credentials** must work on production (create/test dedicated account).
2. **Store listing + screenshots** must match `google_play_store_listing_final.md` (no Premier / Discover / Pair Up).
3. **Play Console** Child Safety / Data Safety / account deletion URL must be completed by a human.
4. Confirm production backend migrations for deletion / Feed report / Terms are deployed.

## Policy Audit

| Area | Status |
|------|--------|
| Metadata | **FIXED** + listing MANUAL |
| Play Console reviewer access | **MANUAL ACTION REQUIRED** |
| Authentication | **FIXED** (error mapping) |
| User Generated Content | **PASS** (report/block/Terms gate) |
| Child Safety Standards | **FIXED** (Terms §5A) + Console **MANUAL** |
| Age / target audience | **PASS (soft)** — checkbox + age≥18; no DOB; **LEGAL/BUSINESS** if stronger assurance needed |
| Account deletion | **PASS** (code) + web live URL **MANUAL** |
| Privacy / User Data | **PASS** inventory docs |
| Data Safety | **MANUAL PLAY CONSOLE REVIEW** |
| Billing / subscriptions | **PASS** (Play Billing + accurate Premium list) |
| Permissions | **PASS** (no CAMERA, no background location) |
| Location | **PASS** (when-in-use) |
| Impersonation / third-party wording | **FIXED** / guarded by tests |
| Restricted content / 420 | **FIXED** on Android (filters hidden; fake profile chips removed) |
| Technical quality | **PASS** with remaining analyze infos |
| Target API | **PASS** (targetSdk 36 via Flutter 3.41.6) |

## Files Changed

| File | Why |
|------|-----|
| `lib/features/auth/auth_screens.dart` | Remove premier tagline |
| `lib/core/network/api_user_message.dart` | Login/network error mapping |
| `lib/features/profile/profile_screens.dart` | Remove always-on “420 Friendly” chips |
| `lib/features/discover/discover_screen.dart` | Hide 420 filter on Android |
| `lib/features/ghinder/ghinder_screen.dart` | Hide 420 filter on Android |
| `lib/features/misc/misc_screens.dart` | CSAE Terms §5A |
| `test/nest_http_error_test.dart` | Login/network mapping tests |
| `test/play_compliance_copy_test.dart` | Ban premier phrases |
| `pubspec.yaml` | Version 1.0.2+24 |
| `docs/*` | Reviewer / matrix / CSAE / deletion / Data Safety / listing / this report |

## Tests Run

| Command | Result |
|---------|--------|
| `flutter analyze --no-fatal-infos --no-fatal-warnings` | **0 errors** (50 infos/warnings) |
| `flutter test --concurrency=1` (temp copy) | **17/17 passed** |
| Backend not re-run in this pass | Prior unit suite was green |

## Release Build

| Field | Value |
|-------|--------|
| versionName | **1.0.2** |
| versionCode | **24** |
| package | `com.connectghin.app` |
| targetSdk | **36** (Flutter 3.41.6 default) |
| Artifact | `connectghin-mobile\dist\ConnectGHIN.aab` |
| Timestamped copy | `connectghin-mobile\dist\connectghin-release-20260915-2052.aab` |
| Size | ~47.0 MB |
| API | `https://api.connectghin.com/api/v1` |

Recommended next versionCode if another upload is needed after this one: **25**.

## Manual Device QA Checklist

- [ ] Clean install release APK/AAB
- [ ] Sign in with Play Console credentials
- [ ] Connect / The Feed labels
- [ ] Free quota / Premium gates
- [ ] Report user + Report Feed post
- [ ] Terms / Privacy / Delete Account copy
- [ ] No Premier / 420 Friendly filters on Android
- [ ] Handicap Verified wording only

## Play Console Tasks (Cursor cannot perform)

- [ ] Create/verify reviewer account in production DB
- [ ] Paste App access credentials
- [ ] Upload AAB 1.0.2 (24)
- [ ] Replace Full description
- [ ] Replace feature graphic (no Premier)
- [ ] Replace outdated screenshots
- [ ] Data Safety form
- [ ] Account deletion URL = `https://connectghin.com/delete-account`
- [ ] Child Safety Standards form
- [ ] Resubmit / continue appeal process

## GO / NO-GO

**CONDITIONAL GO (code).**

Allowed only if:

- Release AAB builds successfully (targetSdk ≥ 36) — **done**
- No known remaining code-level Metadata/CSAE/420 blockers — **addressed**
- Reviewer login **manually verified** on production before upload — **still required**

Do **not** treat this as guaranteed Google approval.
