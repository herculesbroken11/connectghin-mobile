# Google Play feature / claim matrix

Source: Connectghin Flutter app + NestJS backend audit (2026-09-15).

App name: **Connectghin** · Package: **com.connectghin.app**

| Feature | Flutter evidence | Backend | Free/Premium | Implemented | Safe to advertise | Manual QA |
|---------|------------------|---------|--------------|-------------|-------------------|-----------|
| Email registration | `auth_screens.dart`, `auth_api.register` | `POST /auth/register` | Free | Yes | Yes | Yes |
| Email/password login | `auth_screens.dart`, `auth_api.login` | `POST /auth/login` | Free | Yes | Yes | **Critical** |
| Google Sign-In | `google_sign_in_helper.dart` | `POST /auth/google` | Free | Yes | Yes | Yes |
| Apple Sign-In | iOS path; Android shows unavailable | `POST /auth/apple` | Free | iOS | Android: do not claim | — |
| Profile | `profile_screens.dart` | `/profiles/me` | Free | Yes | Yes | Yes |
| Photos (gallery) | `manage_photos_screen.dart` | upload endpoints | Free | Yes | Yes | Yes |
| Location (when in use) | `location_device.dart` | profile lat/lng | Free | Yes | Yes | Yes |
| Connect (nearby) | `discover_screen.dart` (nav label Connect) | `/discovery` | Free | Yes | Yes | Yes |
| Daily Connect like limit | `swipe_daily_quota.dart` | `LIKE_LIMIT_REACHED` | Free limited | Yes | Yes | Yes |
| Unlimited Connect | Premium path in swipes | premium check | Premium | Yes | Yes | Yes |
| Mutual Connect → Match | swipes → matches | matches module | Free | Yes | Yes | Yes |
| Chat with Matches | `messages_screens.dart` | conversations + socket | Free after Match | Yes | Yes | Yes |
| The Feed | `ghinder_screen.dart` + `foursome_feed_tab.dart` | discovery + foursome-feed | Pair Up free (shared swipe quota); Feed preview free | Yes | Yes | Yes |
| Pair Up (Feed mode) | `ghinder_screen.dart` mode tab | `/discovery` + swipes | Free (same daily like limit as Connect) | Yes | Yes — as Feed mode, **not** bottom nav | Yes |
| Full Feed / post / contact | Premium gates | `PREMIUM_REQUIRED` | Premium | Yes | Yes | Yes |
| Premium badge | `cg_premium_badge.dart` | membershipType | Premium | Yes | Yes | Yes |
| Restore purchases | IAP membership screens | Google Play verify | Premium | Yes | Yes | Yes |
| Handicap Verified (manual) | verification screens + badge | GHIN verification queue (manual) | Free submit | Yes | Yes — as **manual review**, not official | Yes |
| Player ratings | player_ratings screens | player-ratings | Free | Yes | Yes | Yes |
| Report / block user | report/block flows | reports, blocks | Free | Yes | Yes | Yes |
| Report Feed post | `report_feed_post_sheet.dart` | feed report API | Free | Yes | Yes | Yes |
| Terms acceptance before UGC | `terms_acceptance_gate.dart` | `TERMS_ACCEPTANCE_REQUIRED` | Free | Yes | Yes | Yes |
| Privacy / Terms | in-app screens | public-legal settings | Free | Yes | Yes | Yes |
| Account deletion (in-app) | `delete_account_flow_screen.dart` | `POST /account/delete-request` | Free | Yes | Yes | Yes |
| Account deletion (web) | Terms link | web deletion APIs | Free | Yes | Yes | Yes |
| Push notifications | Firebase messaging | device tokens | Optional | Yes | Yes | Yes |

## Do not advertise

- Official GHIN / USGA verification or affiliation
- Premier / best / #1 claims
- See who likes you, Profile Boost, priority placement, message anyone
- Discover / Find Your 4th as current bottom-nav names
- Pair Up as a bottom-nav name (Pair Up is a mode **inside** The Feed)
- Automatic Google Play subscription cancellation on account deletion
- Guaranteed safety/moderation outcomes
