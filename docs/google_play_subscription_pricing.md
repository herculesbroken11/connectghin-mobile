# Google Play subscription pricing (manual Console task)

**App:** Connectghin (`com.connectghin.app`)

Cursor / the Flutter app **cannot** change Google Play Console pricing.
Product IDs stay the same; only Console base-plan prices change.

## Products

| Plan | Product ID | Target US price |
|------|------------|-----------------|
| Monthly | `connectghin_monthly` | **$2.99 / month** |
| Annual | `connectghin_yearly` | **$29.99 / year** |

Annual vs monthly (US list math):  
12 × $2.99 = $35.88 → annual $29.99 saves **$5.89 / year** (~16% vs monthly).

## App behavior

- Purchase UI prefers **Google Play `ProductDetails.price`** (localized).
- Fallback copy in the app uses `$2.99` / `$29.99` only when products fail to load.
- Authoritative charge is always what Play Billing returns at purchase time.

## Manual Play Console steps

1. Open [Google Play Console](https://play.google.com/console) → Connectghin.
2. **Monetize with Play** → **Products** / **Subscriptions**.
3. Open **connectghin_monthly** → base plan → set US price to **$2.99** → save/activate.
4. Open **connectghin_yearly** → base plan → set US price to **$29.99** → save/activate.
5. Review regional pricing / auto-converted prices.
6. Confirm both base plans are active for the production track.

## Existing subscribers

Changing base-plan prices does **not** automatically re-price existing subscribers.
Treat any migration of current subscribers as a separate Play Console / business decision.

## Related app files

- `lib/features/subscriptions/iap_product_config.dart` — product IDs
- `lib/features/membership/membership_screens.dart` — ProductDetails + fallbacks
