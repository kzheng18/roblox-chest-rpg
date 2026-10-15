# Client boundary hardening — 2026-09-29

Implemented against [Roblox's client-server security guidance](https://create.roblox.com/docs/scripting/security/client-server-boundary), which calls for server-side structure, value, context/permission validation, and rate limiting. These changes protect the current prototype endpoints; this is not a platform security certification.

| Boundary | Implemented behavior |
| --- | --- |
| Identity/session | Uses engine-supplied Player; membership and active profile required before dispatch. No payload can select the profile or grant a role. |
| Structure | Bounded action names and IDs, exact two-field settings payload, no extra remote arguments, unknown action/setting/ID rejection. Nested extras are rejected without recursive traversal. |
| Values | Settings reject NaN/infinity/out-of-range numbers; inventory ownership requires finite positive integer counts. Non-finite balance/position/health and invalid chest costs fail closed. |
| Permissions | Server checks owned weapons, region unlocks, current chest region, funds, and Rebirth eligibility. Training and region transitions require a living character. |
| Chest interaction | Character must be in Workspace and within 24 studs of the actual anchored chest on the server. No client position or Instance path is accepted. |
| Request budgets | Token buckets: aggregate player 30/s burst 30, aggregate server 600/s burst 600, plus the existing per-action budgets. Invalid/unknown requests consume ingress capacity; already-throttled players cannot consume the shared bucket. |
| Log safety | At most one rejection/dispatch-error warning per ten seconds per server. Per-player counters retain rejection totals without storing arbitrary payloads. |
| Reward ordering | Resolve/validate the roll and existing count before a non-yielding debit/grant pair; an empty pool cannot consume Gold. |

Action settings remain configurable in `src/shared/Config/Network.luau`. The aggregate server budget is an initial prototype setting; tune it with real server-population/load evidence. An application-level limiter does not remove platform transport/decoding costs.

## Verification

- Local working tree: **53 regression tests passed**, including existing rarity-format tests, and **39 Luau files compiled**.
- Exact IntentGate/IntentPolicy and gameplay service code runs in the CLI harness. Tests cover malformed floods, mixed actions, extra fields/arguments, recovery of token budgets, cross-player isolation, invalid numbers, distant/dead/unanchored chest interactions, inactive sessions, valid purchases/equipment/travel/settings/Rebirth, and an empty loot pool.
- Test doubles replace Roblox service I/O, persistence, character objects, and RNG. These tests do not demonstrate actual cloud persistence, network replication, movement replication, random-distribution fairness, or device performance.
- Fixed pre-existing ambiguous typed assignments in the working UI so the full prototype compiles; no layout change was required.

## Required Studio follow-up

1. In a mock Studio play session, train and open the starting chest from nearby, then try from beyond 24 studs. Confirm a clear message and unchanged balance on rejection.
2. Respawn, travel between unlocked regions, equip a legitimately obtained item, change settings, and complete Rebirth. Check touch/keyboard interaction and Output for errors.
3. Use two test clients to send malformed/extra arguments and unowned IDs. Check the other player's state is unchanged, valid requests recover after throttling, and warning output stays bounded.
4. Test server population/burst traffic and latency before changing limiter thresholds. Distance checks use server-observed character position; they are not a complete defense against client-owned movement manipulation.

These engine/network checks have not been completed by the headless suite. The rebuilt place is local; cloud deployment is not implied.

## Still open in Story 1

Strict save migrations and corrupt-profile quarantine, durable transaction receipts/replay handling, save-confirmed reward UI, privacy of public attributes/deltas, recovery drills, and operational alerts remain tracked in [CORE_SYSTEMS_SECURITY.md](CORE_SYSTEMS_SECURITY.md). The immediate chest cooldown prevents rapid repeated purchases, not replay after cooldown or across sessions. The separate persisted transaction protocol must be implemented before claiming duplicate-safe purchases.

Future prompts must enter through the same router; simply calling a domain service bypasses its aggregate ingress budgets. New combat/ability endpoints require server hit-window/range/cooldown checks and capped effect broadcasts before they are exposed.
