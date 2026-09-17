# Google Play reviewer account checklist

Use this when preparing App Access credentials for Google Play review.

**Do not put real passwords in this file.**

## Goal

Google must sign in with the credentials you enter in Play Console → App content → App access.

A failed login that shows “Invalid email or password” usually means the production account does not exist or the password is wrong—not that the app is broken.

## Create the account (production)

1. Install the **release** APK/AAB (or production Play build), not a debug build that shows demo hints.
2. Register a **dedicated** email used only for Google review (example pattern: `play-review@yourdomain.com`).
3. Use a strong, **non-expiring** password you control.
4. Confirm email/password login works on a **clean install** (clear app data or new device).
5. Complete onboarding:
   - Age 18+
   - Display name
   - Location (city and/or coordinates)
   - At least one profile photo (recommended)
6. Accept Terms / Privacy when prompted.
7. Confirm the account is **ACTIVE**, not suspended, and not pending deletion.
8. Optional Premium demo: use **Admin Premium Override** on the backend for this user. Do **not** hardcode Premium in the app for reviewers.

## Play Console App access form

Provide:

- Email
- Password
- Any 2FA: **None** (do not require OTP)
- Short notes, for example:
  - “Email/password login on the Sign In screen.”
  - “Account has a completed profile and location so Connect and The Feed load.”
  - “Premium entitlements enabled via admin override if Premium screens must be reviewed.”

## Verify before every resubmission

On a production-pointing release build:

1. Open Connectghin → Sign In
2. Enter the **exact** credentials from Play Console (copy/paste carefully; watch trailing spaces)
3. Confirm home / Connect loads
4. Confirm The Feed opens
5. Confirm Settings → Terms / Privacy / Delete Account are reachable
6. Do **not** delete the reviewer account during testing

## If login still fails

1. Confirm production API is `https://api.connectghin.com/api/v1`
2. Confirm the user exists in the **production** database (not only local seed)
3. Reset the password via the in-app forgot-password flow or admin tooling
4. Confirm `lifecycleStatus` is ACTIVE and `isSuspended` is false
5. Re-test on a clean install before updating Play Console credentials
