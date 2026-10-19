# Economy report (simulated)

All prices and coin amounts are PRETEND placeholders. No Robux prices exist or were invented.
Source: `tests/economy_sim.test.luau` (part of `lune run tests/run`). It uses the real
LobbyConfig, ProgressConfig, QuestsConfig, Daily, Gacha, Store, Inventory and the 12-car launch
roster (4 Common, 3 Rare, 3 Epic, 2 Legendary; Sedan is the free starter). 300 fake players per
profile, 60 days, deterministic seeds, so the numbers reproduce exactly.

Player rules in the sim: claims the daily gift each day; plays matches (win rate 50%, picks a
random owned car, half the wins count as "beat the bot"); claims every finished quest;
levels cars with XP (real level-up coins and streak bonuses); the daily spin is NOT played
because `FeatureFlags.dailySpin` is false at launch.

Profiles: casual (4 matches a day, pulls the claw whenever it can pay), daily-only (0 matches,
only the free daily claw try), casual+store (4 matches a day, saves for the cheapest unowned
car in the store, claws only with free tries).

## Numbers (medians, after the small refund tweak below)

| Profile | First pull | Rare | Epic | Legendary | Cars owned d30 / d60 | Coins d60 |
|---|---|---|---|---|---|---|
| Casual | day 1 | day 1 | day 2 | day 6 | 12 / 12 | 60 |
| Daily-only | day 1 | day 1 | day 4 | day 24 | 10 / 11 | 50 |
| Casual + store | day 1 | day 2 | day 4 | day 15 | 12 / 12 | 12400 |

- Casual: 308 claw pulls in 60 days, 297 of them duplicates, 7080 coins refunded.
- 13.7% of casual players still have no Legendary after day 14; 0% are without one by day 60.
- Coin income for a casual player is roughly 250 to 300 a day (match rewards, quests, level-ups).
- Store, no claw: a Common car (150) is about 1 day of play, Rare (400) 1.5 days, Epic (1000)
  about 4 days, Legendary (2500) about 9 days.

Before the tweak (refunds 30/60/150/400): casual had 665 pulls and 42930 refund coins, because an
Epic/Legendary duplicate paid back more than a pull cost. The refunds were recycling so much that
the effective pull price fell to about 34 coins.

## Does progress feel steady?

- Good: the free first pull and the daily gift mean day 1 always has a pull, and the first Rare
  comes almost at once.
- Too fast: the whole 12-car collection is owned by day 30 at the latest for a casual player (sim checkpoint). After
  that the claw only returns duplicates and there is no coin sink, so coins sit unused (the
  store player ends with about 12000 unspent). Paint is hidden (`paintShop` flag), the spin is
  hidden, so the long-term sink is missing.
- Duplicates: the refunds keep the claw feeling rewarding early, but after the tweak they no
  longer make pulling free.
- Daily-only players still get ~1 pull a day; they see a Legendary in about 3 weeks, which is
  acceptable for "log in and press the gift" players.

## Tweak applied (config only)

`LobbyConfig.Gacha.duplicateRefunds`: Common 30 to 10, Rare 60 to 25, Epic 150 to 60,
Legendary 400 to 120. Reason: an Epic/Legendary duplicate paid more than the 100 coin pull price,
so a casual player did 665 pulls and every sanity assert about a Legendary arriving too early
failed. Odds (55/28/14/3), pull price (100), store prices and rewards are unchanged because
existing tests pin them.

## Recommendations (not applied)

1. Raise the pull price to about 150 and re-pin `tests/lobby.test.luau` (it hardcodes 100): a
   casual Legendary moves to about day 9 to 10 and the collection completes later (re-run the sim to get the day).
2. Add a long-term sink before launch or soon after: turn on paint (`paintShop`), a prestige or
   "golden" car skin bought with coins, or a cosmetic trail. Without it the late game is dead.
3. Consider a pity timer (guaranteed Epic after 25 pulls without one) so bad luck does not
   break the steady feel; pure code in `Gacha`, easy to unit test.
4. Quest rewards (60/40/50) are about 40% of a casual day's income. If the claw price is raised,
   keep quests as they are; they are the main reason a low-skill player still progresses.
5. When the real store and Robux packs exist, re-run this sim with the real coin packs: a bought
   pack of a few thousand coins buys the whole collection in one go at current prices.
