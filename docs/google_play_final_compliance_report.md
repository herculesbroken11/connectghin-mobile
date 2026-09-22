# Google Play Final Compliance Audit

Date: 2026-09-22  
App: Connectghin (`com.connectghin.app`)  
Version prepared: **1.0.2+29**

## Executive Summary

Steve’s final UX: **The Feed opens directly to open spots** (no Pair Up / Foursome Feed mode selector). **Connect** remains the nearby-like flow. Home **Quick Actions** replaced with **Your Player Ratings**. Premium fallback list prices updated to **$2.99 / $29.99** (Play `ProductDetails.price` still authoritative).

**Conditional GO for code/build** — verify reviewer login, update Play Console listing/screenshots, and set Console subscription prices manually.

## Current product structure

| Nav | Role |
|-----|------|
| Home | Overview + Player Ratings |
| Connect | Nearby golfers, likes, Match |
| The Feed | Open spots only |
| Matches | Matches inbox |
| Settings | Account / legal / notifications |

## Metadata

Source of truth: `docs/google_play_store_listing_final.md`  
Subscription Console task: `docs/google_play_subscription_pricing.md`

Do **not** advertise: Premier claims · Official GHIN/USGA · Discover/Pair Up/Find Your 4th as nav · unsupported Premium perks.
