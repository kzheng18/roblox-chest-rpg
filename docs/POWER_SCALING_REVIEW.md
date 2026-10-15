# Anime power proposal review — October 15, 2026

Reviewed GitHub commit `4f66b2f1289b413f97cade6ea3a7f8175c541aa8`
("Add anime powers and showcase design doc", coauthored by Claude), after fetching
origin. That commit adds only `ANIME_POWERS_SHOWCASE.md`. It contains a design
proposal, not a power framework or a change to the executable scaling formulas.
The comments below identify design decisions needed before implementation; they
are not claims that unimplemented features currently have runtime bugs.

## Recommendation

Keep the shared framework, reusable reveal, and original themed content. Allow
different power identities and curve shapes, but measure them against shared
regional progression budgets. Independent curves without shared bounds would
make future content increasingly difficult to balance.

## Findings, in priority order

1. **High — Separate theme curves lack a common balance contract.**
   `ANIME_POWERS_SHOWCASE.md:17` calls for separate curves; line 81 makes new themes
   the next progression tier. Neither specifies comparable outputs, stacking,
   or a useful role for earlier powers. Today `Progression.PowerGain` multiplies
   base gain, the linear rebirth bonus, and one owned weapon multiplier. Define
   how a power joins this formula before giving each theme its own values.
   A stronger new-theme multiplier could otherwise invalidate previous rare
   pulls or compound weapon and rebirth bonuses unexpectedly.

2. **Medium — Training boosts and collection bonuses have no limits.**
   Lines 59 and 65 propose temporary training boosts and permanent completion
   bonuses, without duration, cooldown, stacking, rebirth behavior, or a total
   ceiling. Define additive versus multiplicative behavior and calculate the
   complete combination before selecting individual values. The server should
   own activation time, cooldown, equipped power, and reward calculation.

3. **Medium — Adding powers to chests requires an explicit probability model.**
   Lines 7 and 72 reuse regional chest drops and weapon-like rarity fields. The
   current `ChestService` checks items sequentially, rarest first, returning the
   first success. An item's final probability is its check probability times
   the chance that every preceding check failed. Thus most displayed `1/N`
   values describe individual checks, not final unconditional drop odds.
   Enlarging that pool changes existing outcomes. Choose theme selection and
   within-theme probabilities explicitly, show final player-facing odds, and
   test the distribution and Luck extremes before implementing the expansion.

4. **Medium — The new inventory type needs a save and ownership contract.**
   Lines 19 and 72 describe a shared framework, but there is no power catalog,
   `OwnedPowers`, equipped-power field, or activation endpoint in the current
   runtime. `ProfileSchema` currently validates weapon inventory dictionaries
   with a 512-ID limit and preserves retired IDs. Decide whether powers share
   that namespace or have their own schema and capacity. Migration must preserve
   weapons and owner binding; retries must not create duplicate power grants.

5. **Medium — Effects need measurable budgets.**
   Lines 53 and 82 describe lightweight auras without concrete limits. Current
   performance checks validate the quality controller with doubles, not live
   multi-player rendering. Budget visible auras and particles, cull distant
   effects, and measure frame times on defined hardware before adding cutscenes
   and skill effects to a crowded server.

## Suggested first-pass limits — proposed, not implemented

| Area | Starting constraint | Validation |
| --- | --- | --- |
| Equipment | One active power plus the existing weapon slot | Ownership and slot selection validated on the server |
| Cross-theme strength | Comparable powers in the same region/rarity bracket target progression rates within 15% | Compare time to region unlock and rebirth using combined bonuses |
| Temporary training skill | Start at +20% for 5 seconds, 30-second cooldown; refresh rather than stack | Server clock; re-equipping cannot reset cooldown; average uplift about 3.3% at continuous use |
| Collection bonus | +1% per completed collection, additive, capped at +10% total | Completing new themes cannot multiply all existing collection bonuses |
| Save capacity | Preserve the current 512-ID contract until a tested schema expansion exists | Test retired IDs and collections near the limit; never silently discard items |
| Low-effects mode | At most four nearby other-player auras; start with 20 emitted particles/second per displayed aura and a 60-stud cutoff | Stress test with full server population; tune to measured frame times |
| Rare reveals | Normal reveals at most 1 second; rare reveals at most 3 seconds and skippable | Reduced-motion preference remains effective; result grant does not depend on the animation |

The 240 FPS aspiration corresponds to approximately 4.17 ms per rendered frame on
the chosen reference PC. It is a measurement target, not a guarantee for phones
or a result established by local unit tests. The limits above are initial tuning
hypotheses, not approved balance changes.

## Current formula reference

`PowerGain = BasePowerGain × (1 + Rebirths × 0.25) × OwnedEquippedWeaponMultiplier`

Gold gain is `2 × (1 + Rebirths × 0.20)`. Rebirth currently requires 20,000 Power,
preserves weapons, and adds 0.15 Luck. Region gates are 2,500 and 12,000 Power.
The weapon catalog ranges from x1.10 to x18.00. An additional power multiplier
must be assessed together with these values rather than in isolation.

No power-scaling implementation or gameplay balance was changed in this review.
