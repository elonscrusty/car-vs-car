# Car feel: how to retune

Every car has two kinds of numbers:

1. **Stats** (hp, mass, maxSpeed, accel, turnRate, damageMult): `CarCatalog.Tuned` (the pack cars; the 8 old hand-written blocky cars were removed).
2. **Handling traits** (how it drives): `src/shared/CarTraitsConfig.luau`, table `Cars`.

## The five traits

| trait | meaning | range (clamped) |
|---|---|---|
| `grip` | kills sideways slide. 0.5 slippery, 1 normal, 1.5 glued | 0.4 to 1.8 |
| `drift` | extra slide when steering hard at speed | 0 to 1 |
| `punch` | + strong launch that fades near top speed, - slow start that keeps pulling | -0.5 to 0.6 |
| `highTurn` | turn rate multiplier at top speed (1 at standstill). Under 1 pushes wide | 0.4 to 1.3 |
| `sizeScale` | body size vs the neutral 5 x 2.5 x 8 box (every car now) | 0.7 to 1.6 |

A car with no row, or a missing field, uses `Defaults` (drives like before). Out-of-range numbers are clamped by `CarTraits.resolve`, so a typo cannot break a car.

Global feel knobs in the same file: `driftSlip` (how much `drift` loosens grip), `minGrip`, `accelRange`.

## Where it is used

- `shared/CarDrive.luau`: `push` (accel curve + grip + drift) and `manual` (turn rate fades to `highTurn`). Human-driven cars only: bot cars use `Autopilot`'s own steering, so they get the accel curve and grip but not `highTurn` / drift.
- `shared/CarTraits.luau`: pure math, bar fractions and the "Fast, slippery" text.
- `client/CarStatsUi.luau`: the 4 bars (speed, weight, turn, HP) on the store card. Bar ranges: `CarTraitsConfig.BarRanges`. Words: `CarTraitsConfig.Words`.

## Retune steps

1. Change a trait row (or a stat). Keep abilities untouched.
2. Run `lune run tests/run`. Two tests guard you:
   - every launch car must differ from every other in at least 2 traits (`differBy` = 0.09);
   - `CarPower` balance: no car over 20% above the average of its rarity. Trait weights are in `CarConfig.PowerWeights` (`grip`, `punch`, `highTurn`).
3. If balance fails, lower the strongest stat or trait of the offender, or raise the weaker cars of that rarity. Do not change `PowerTolerance`.
4. Play it. The numbers are placeholders; trust your hands over the tests.

## Quick feel guide

- Darty light car: low `grip`, high `drift`, `punch` +0.3, `highTurn` above 1.
- Pushy heavy car: high `grip`, `drift` near 0, `punch` negative, `highTurn` 0.6 to 0.7.
- Size: make a big truck `sizeScale` 1.35+. Mass stays what the stats say.
