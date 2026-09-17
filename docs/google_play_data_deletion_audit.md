# Google Play data deletion audit

## In-app

| Check | Result |
|-------|--------|
| Discoverable from Settings / Privacy | Yes — Delete Account |
| Calls authenticated API | `POST /api/v1/account/delete-request` |
| Explains data deleted/anonymized | Yes (updated copy) |
| States store billing is separate | Yes — Google Play / App Store managed separately |
| Does not claim automatic Play cancel | Correct — does not claim auto-cancel |
| Privacy reachable | In-app Privacy Policy screen |

## External web

| Check | Result |
|-------|--------|
| Expected URL | `https://connectghin.com/delete-account` |
| Linked from Terms | Yes |
| Secure flow (no delete-by-email alone) | Backend: email confirm token → `deletion-web-confirm` |
| Token TTL | ~60 minutes (implementation) |

## Backend `processAccountDeletion` (summary)

**Removed:** profile photos, profile posts, device/push tokens, password-reset tokens, open Feed posts canceled/scrubbed.

**Anonymized:** email/username, profile PII, handicap verification identifiers, sessions invalidated (`refreshTokenVersion++`).

**May retain (anonymized identity):** messages, matches, moderation reports, subscription/billing integrity rows.

Do not claim total physical erasure of all historical rows.

## Manual confirmations

- [ ] Live web page works end-to-end on production
- [ ] Production DB migrations for deletion tokens applied
- [ ] Play Console Data safety / Account deletion URL set to `https://connectghin.com/delete-account`
