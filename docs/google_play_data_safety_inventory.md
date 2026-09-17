# Google Play Data Safety — technical inventory

Encrypt in transit: HTTPS to `api.connectghin.com` (release). Classification of “shared” is **MANUAL PLAY CONSOLE REVIEW**.

| Data | Collected | Required? | Purpose | Off device? | Destination | Deletion |
|------|-----------|-----------|---------|-------------|-------------|----------|
| Email | Yes | Required | Auth / contact | Yes | Backend | Anonymized |
| Password hash | Yes (server) | Required | Auth | Yes | Backend | Invalidated / replaced |
| User IDs | Yes | Required | Account | Yes | Backend | Retained as anonymized row |
| Display name / bio / prefs | Yes | Optional after signup | Profile / Connect | Yes | Backend | Cleared / anonymized |
| Age (integer) | Yes | For profile complete | Eligibility / profile | Yes | Backend | Cleared |
| DOB | No | — | — | — | — | — |
| Photos | Yes | Optional | Profile / posts | Yes | Backend storage | Deleted |
| Precise/approx location | Yes | Optional | Nearby Connect / Feed | Yes | Backend | Cleared |
| Messages | Yes | When chatting | Match chat | Yes | Backend | Retained anonymized |
| Feed UGC | Yes | When posting | Open spots | Yes | Backend | Posts canceled / scrubbed |
| Ratings | Yes | Optional | Community | Yes | Backend | Manual retention review |
| Reports / blocks | Yes | When used | Safety | Yes | Backend | Retained anonymized |
| Handicap number / names | Yes | Optional | Manual Handicap Verified | Yes | Backend | Redacted |
| Play purchase tokens | Yes | Premium | Billing verify | Yes | Backend + Google Play | Billing rows may retain |
| FCM token | Yes | Optional | Push | Yes | Backend + Firebase | Deleted |
| Device advertising ID | Not app-primary | — | — | — | — | Confirm SDK merge |
| Crash analytics | Depends on Firebase defaults | Optional | Stability | Possible | Firebase | **MANUAL** |

## Location Data Safety note

- Foreground / when-in-use only
- No `ACCESS_BACKGROUND_LOCATION`
- Precise + approximate permissions declared for nearby golfers

## Manual Play Console decisions

- Whether Firebase / Google Play Billing count as “shared”
- Ephemeral vs stored location
- Data deletion timeline wording vs anonymization
