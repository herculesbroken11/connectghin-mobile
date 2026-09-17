# Google Play Child Safety Standards — gap analysis

App category context: social / playing-partner UGC. Intended audience: adults 18+.

| Requirement | Status | Evidence / gap |
|-------------|--------|----------------|
| Explicit prohibition of CSAE | **PASS (after fix)** | Terms §5A added in `misc_screens.dart` |
| Prohibition / removal of CSAM | **PASS (after fix)** | Same section; report/block + moderation |
| In-app reporting mechanism | **PASS** | User report + Feed post report |
| Child-safety contact mechanism | **PASS** | `support@connectghin.com` + in-app Help |
| Process/statement for acting on reports | **PASS (after fix)** | Terms: review, remove, suspend, escalate when required by law |
| Named authority reporting (e.g. NCMEC) | **MANUAL/LEGAL ACTION REQUIRED** | Do **not** claim specific authority reporting in-app unless the business confirms a live process. Public website `/child-safety` may need legal alignment. |
| Age gate 18+ | **PASS (soft)** | Signup checkbox + onboarding/API age ≥ 18; **no DOB**. Stronger age assurance is a product/legal decision. |
| Play Console Child Safety declarations | **MANUAL ACTION REQUIRED** | Must be completed in Play Console by the account owner. |

## External tasks (not inventable in Flutter)

1. Confirm production `https://connectghin.com/child-safety` (or equivalent) matches Terms.
2. Confirm monitored inbox for child-safety/support email.
3. Complete Play Console Child Safety Standards questionnaire accurately.
4. Legal review of CSAE language before claiming jurisdiction-specific reporting.
