# ConnectGHIN subscriptions — local StoreKit vs App Store Connect

Bundle ID stays `com.connectghin.app`.

iOS and Android intentionally share product IDs. Nothing in this repo shows that Apple requires different IDs, and the backend already accepts these IDs for Apple verification when `APPLE_IAP_ALLOWED_PRODUCT_IDS` is unset or includes them.

| Plan | Product ID | Intended US price |
| --- | --- | --- |
| Monthly | `connectghin_monthly` | $2.99 / month |
| Yearly | `connectghin_yearly` | $29.99 / year |

The price charged is always the store’s localized `ProductDetails.price`. The amounts above are the intended US price and the display fallback when products have not loaded. A fallback price does not enable Subscribe.

## Local simulator StoreKit (not production)

File: `ios/Runner/ConnectGHIN.storekit`

This file is only for Xcode’s local StoreKit test environment. It is not synced to App Store Connect. It does not create real products, and a local purchase must not be treated as a production entitlement.

The shared Runner scheme (`ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme`) references that file on the Run action. Confirm it in Xcode before testing:

1. Open `ios/Runner.xcworkspace` in Xcode.
2. Product → Scheme → Edit Scheme…
3. Run → Options → StoreKit Configuration.
4. Select `ConnectGHIN.storekit`.
5. Run on the iPhone 17 Pro simulator from Xcode (Product → Run).

`flutter run` does not reliably attach a scheme StoreKit configuration. Use Xcode’s Run action for purchase testing.

Local StoreKit can show products and the purchase sheet. The app still sends the transaction to `POST /subscriptions/entitlements/verify/apple`. That endpoint calls Apple’s App Store Server API. A local StoreKit transaction is not a real Apple transaction, so the server should reject it and Premium should stay off. Do not add a client bypass.

## Real App Store Connect (still required)

This repo does not contain App Store Connect state. Nothing below is verified as already created. Steve needs to configure it before TestFlight or production purchases work. Do not upload a build as part of the layout/IAP copy fix.

- [ ] App record for bundle ID `com.connectghin.app`.
- [ ] In-App Purchase capability enabled for that App ID (Apple Developer → Identifiers). Standard auto-renewable subscriptions do not add a key to `Runner.entitlements`; Sign in with Apple is the only entitlement in the repo today.
- [ ] Paid Apps agreement, tax, and banking completed in App Store Connect. Subscriptions stay unavailable until this is done.
- [ ] One subscription group, for example “ConnectGHIN Premium”.
- [ ] Auto-renewable subscription `connectghin_monthly`.
  - [ ] Reference name: Premium Monthly
  - [ ] Duration: 1 month
  - [ ] US price: $2.99
  - [ ] Localization display name and description
  - [ ] Review screenshot / review notes if App Review asks for them
  - [ ] Availability set, status Ready to Submit / Approved as required for the build
- [ ] Auto-renewable subscription `connectghin_yearly` in the same group, same level as monthly (crossgrade, not a higher tier).
  - [ ] Duration: 1 year
  - [ ] US price: $29.99
  - [ ] Localization display name and description
  - [ ] Cleared for sale
- [ ] No introductory free trial unless product later decides to offer one. The app currently says launch pricing has no free trial.
- [ ] Sandbox tester Apple ID for device testing.
- [ ] App Store Server API key on the server (not in the mobile repo):
  - `APPLE_IAP_ISSUER_ID`
  - `APPLE_IAP_KEY_ID`
  - `APPLE_IAP_PRIVATE_KEY`
  - `APPLE_IAP_BUNDLE_ID` = `com.connectghin.app`
  - `APPLE_IAP_ALLOWED_PRODUCT_IDS` = `connectghin_monthly,connectghin_yearly` (optional; if empty, the server allows the product ID Apple returns)
  - `APPLE_SERVER_NOTIFICATION_SECRET` if server notifications are used
- [ ] App Store Server Notifications URL pointed at the existing Apple notifications endpoint, after the API key verifies.

Until those products exist, a simulator or device that is not using `ConnectGHIN.storekit` will report the IDs as not found. The Premium screen tells the user that subscriptions are temporarily unavailable and writes the missing IDs only to the debug log.
