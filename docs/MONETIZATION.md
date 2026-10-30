# Monetisation

Free to play. Ads + in-app purchases. The full campaign can be finished without paying.

## Ads (Google AdMob)
| Format | Where | Rules |
|---|---|---|
| Rewarded | "Watch ad: +1 Bomb" on the last shot, "Double coins" on the win screen, "Revive soldiers" on lose screen, daily free coins | Always opt-in, button says what you get |
| Interstitial | Between levels only, after the win/lose screen, when the player taps Next/Retry | Not before level 4, not in the first session, at most once per 3 levels and 3 minutes. Never mid-level. Removed by "Remove Ads" |
| Banner | Not used | Takes screen space and clashes with the look |

- Consent: Google UMP form on first launch (required for EEA/UK), before any ad request.
- Test ads (Google test unit IDs) in debug builds. Real IDs only in release, read from
  `export_credentials.cfg` / env, never committed.
- Ad frequency numbers live in `data/balance.json` → `ads`.

## In-app purchases (Google Play Billing)
| Product ID | Type | Price (USD guide) | Gives |
|---|---|---|---|
| `remove_ads` | non-consumable | $2.99 | No interstitials. Rewarded ads still available (optional) |
| `coins_small` | consumable | $0.99 | 1,000 coins |
| `coins_medium` | consumable | $4.99 | 6,000 coins |
| `coins_large` | consumable | $9.99 | 15,000 coins |
| `gems_small` | consumable | $0.99 | 80 gems |
| `gems_medium` | consumable | $4.99 | 500 gems (+20%) |
| `gems_large` | consumable | $9.99 | 1,200 gems (+40%) |
| `starter_pack` | non-consumable, shown once after level 5 | $1.99 | Remove ads + 2,000 coins + golden catapult skin |

Prices are set in Play Console per country. Purchases are acknowledged within 3 days (Play rule),
restored on reinstall via `queryPurchases`. Server-side verification is a later improvement.

## Currencies
Three wallet kinds, stored in `user://save.json` (`coins`, `gems`, `blueprints`, save version 3) and
shown by `CurrencyBar` on every meta screen. Earn amounts live in `data/balance.json` →
`currencies`.

| Currency | Role | Earned | Spent on |
|---|---|---|---|
| Coins | Soft, plentiful | Every win, stars, chests, wheel, daily rewards, achievements | Hero upgrades, siege-weapon upgrades, coin-priced skins, extra heroes |
| Gems | Premium, scarce | First 3-star clear (3), first boss clear (20), wheel, daily days 2 and 6, achievements, IAP | Skins, extra wheel spins, offers, chest keys. Never required to finish the campaign |
| Blueprints | Earned progress gate | First boss clear (2), every 5th level first clear (1), chests, wheel, daily day 3 | With coins, siege-weapon upgrades and unlocks |

Rules: premium rewards are only for **first** clears (replays give coins only, so they can't be
farmed); spending is all-or-nothing (`Save.spend(cost)`); gems never buy power that the campaign
can't give for free.

## Coins
Earn: level clear, stars, rewarded ads, daily reward. Spend: extra heroes in a level, soldier
upgrades (shield = blocks first arrow), cosmetics (catapult skins, hero hats).
No pay-to-win gates, no energy/lives system in v1.

## Policy checklist
- Data safety form: AdMob collects device ID/advertising ID; declare it.
- Target audience 13+, not in Families programme.
- Privacy policy URL required (ads SDK). Host a simple page (GitHub Pages is fine).
- No ads that look like game buttons, no ad on app open in v1.
