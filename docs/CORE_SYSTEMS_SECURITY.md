# Core systems, player identity, and data security

Status: implementation specification and static code review, 2026-09-29. These requirements extend Story 1; they are not a security certification or evidence that the controls are deployed. Existing behavior and gaps are recorded below. Proposed limits are project decisions to validate in staging.

## 1. Ownership and trust boundaries

| System | Owns | Must never accept as authoritative |
| --- | --- | --- |
| Identity / session | Server-provided Player, UserId, active save session | Client-supplied identity or admin status |
| Profile lifecycle | Load, lock, schema, save, recovery, shutdown | Client-provided profile, save key, or revision |
| Economy | Training income, Gold, Power, multipliers, Rebirth | Client-provided reward amount, price, or Luck |
| Regions | Unlock eligibility, permitted travel, arrival state | A client claim that a gate was unlocked |
| Chests / inventory | Roll distribution, debit, grant, ownership, equipment | Client-selected result or invented ownership |
| Combat | Equipped ability, attack cadence, hit validation, damage | Client-declared damage, kill, or cooldown completion |
| Replication / UI | Curated views of authoritative state | UI attributes or animations as proof of a reward |
| Operations | Restricted publishing, migrations, restores, incident controls | General-purpose admin remotes or credentials in assets |

Proposed request path:

```text
Roblox Player -> ingress budget -> input validation -> session/permission checks
             -> per-player mutation coordinator -> validated state change
             -> save checkpoint where required -> curated client response
```

Keep these responsibilities modular. Reuse the current DataService, IntentGate, RuntimeState, and StateReplicator where appropriate; a separate service for every table row is unnecessary.

Treat the player's client as inspectable and modifiable. Keep secrets and privileged logic outside replicated containers. Roblox documents the distinction between client-visible and server-only content in its [access-control guidance](https://create.roblox.com/docs/scripting/security/access-control).

## 2. Authentication and authorization

**Player login belongs to Roblox.** No custom sign-up, password database, email collection, or Roblox-cookie collection is needed for the game. For this experience, use the engine-provided Player identity and UserId to select the profile. Roblox exposes this identity through [Player.UserId](https://create.roblox.com/docs/reference/engine/classes/Player#UserId).

Project requirements:

- Bind every gameplay request to the Player argument supplied to OnServerEvent. Gameplay payloads cannot choose a different account, profile key, store, or permission level.
- Authenticated does not mean authorized: every operation also requires an active loaded profile and action-specific eligibility.
- Deny progression writes during Loading, Quarantined, SessionLost, or Closing. Handle an economy-saving pause separately from client disconnect.
- Never trust display names for identity, leaderboard ownership, support restoration, or privileged commands.
- No ordinary client-accessible grant-Gold, set-Luck, arbitrary require, script execution, or profile-edit endpoints.
- If staff tools are later needed, enforce explicit server-side roles and narrow operations. Staff actions require a reason, audit identifier, and profile revision check. Hide buttons for usability, never as authorization.
- Secure creator and GitHub accounts with MFA/passkeys and least-privilege collaborator roles. Routine publishing must not require profile-restoration permissions.
- A future external account website needs a separately reviewed Roblox OAuth integration; do not add client-held signing secrets or homemade authentication tokens now.

Acceptance: player A cannot read or mutate player B's private state; spoofed UserIds, display names, attributes, and staff flags never confer access.

## 3. Player data contract

Retain one authoritative profile for coupled player progression. The current key is Player_<UserId>; storage namespace and environment are server configuration. Production, staging, and Studio mock data must be isolated, preferably using separate test and production experiences. Studio API access can reach an experience's live data, so test isolation is a real requirement. See [Roblox data stores](https://create.roblox.com/docs/cloud-services/data-stores).

| Data | Storage rule / invariant |
| --- | --- |
| SchemaVersion | Explicit supported integer version; reject future versions |
| Revision / durable revision | Monotonic mutation revision; durable revision only advances on confirmed save |
| Power, Gold | Finite, nonnegative, bounded by documented economy limits |
| Rebirths | Bounded nonnegative integer; bonuses derived by one shared formula |
| Luck | Derived from authorized sources; if persisted as a cache, recompute/validate it |
| OwnedWeapons | Bounded catalog-ID-to-positive-integer counts for the current stackable prototype |
| EquippedWeapon | Empty/default or a known, owned, currently usable weapon |
| UnlockedRegions | Known region IDs mapped to booleans; starting region always available |
| CurrentRegion | Known unlocked region; reconcile spawn/travel server-side |
| Settings | Only documented keys, typed values, bounded volume |
| Operation receipts | Bounded deduplication metadata, result, sequence/session scope, resulting revision |
| Metadata | Only needed timestamps, economy/config version, and recovery provenance |

Do not silently switch stackable ownership to unique item instances. Introduce server-generated item IDs and an explicit migration when individual traits, locks, or trading require them.

Reject NaN, infinity, unsupported types, excessive nesting, oversized containers, unknown identifiers, and invalid ownership relationships at ingestion and before persistence. Specify finite numeric caps before launch; integer currency/counts must remain within exact integer representation or use a tested alternative. Large number display formatting does not solve precision loss.

Migrations must be version-by-version, deterministic, tested against fixtures, and operate on a copy. New defaults are allowed only for a confirmed missing record or a documented missing field in a known old schema. An unreadable record, invalid progression, or a future schema is not a new player. Quarantine rather than resetting the player's economy. Do not expose a profile for play until migration and validation pass; ensure automatic saving cannot commit a partial migration or a default replacement on the failure path.

Preserve a recovery point before migration. Unknown fields/IDs from an incompatible release require investigation, not silent deletion. Approved repairs to noncritical settings can be separate from currency/item recovery.

## 4. Session ownership and persistence

Use the existing ProfileStore session lifecycle as the single writer. Do not add a second DataStore writer against its live keys. Session conflicts must resolve without two servers awarding or saving simultaneously; never implement a force-unlock that ignores the current owner. Roblox's [data-store best practices](https://create.roblox.com/docs/cloud-services/data-stores/best-practices) discuss concurrency, session locking, and coordinated storage design.

Required lifecycle:

1. Loading: acquire session, validate/migrate, and build a private state view.
2. Ready: accept validated gameplay intents.
3. Saving/degraded: track pending versus confirmed revisions; apply backpressure when storage is unhealthy.
4. Closing/session lost: stop mutations, flush within platform shutdown limits, release ownership, and detach runtime state. A lost owner never continues granting progression.

Persistence policy for this project:

- Retain a nominal 120-second background autosave target initially. Measure actual save age and throttling; this interval is not a maximum-loss guarantee.
- Continuous training may be provisional until a successful checkpoint. A crash can lose training since the last confirmed save. UI and support documentation must not promise zero loss.
- Chest purchases and Rebirth are critical operations. Do not report them as durably complete until a saved snapshot contains their operation receipt and revision. Until then use a concise pending state and prevent dependent spending or consuming a pending reward.
- Coalesce compatible saves through one coordinator with a maximum wait deadline, budget-aware retries, and jitter. Repeated activity must not postpone a critical save forever. Do not write to DataStore for every attack/training tick or assume a separate write for every chest is affordable.
- Prototype target: normal critical confirmation within 10 seconds. After 15 seconds show a delayed-save message; if no successful save for 180 seconds while dirty, pause further economy mutations. Validate these project targets against real request budgets and tune before launch.
- For errors with an uncertain write outcome, reconcile the durable receipt/revision before retrying or refunding. A timeout is not proof the write failed.
- Leave/shutdown handlers are additional protection, not the sole save strategy. Forced termination cannot guarantee a final write.

Acceptance: test session takeover, abrupt server termination, throttling, rejected writes, leave/rejoin during saves, and session loss. Confirm both the saved value and what the player was told.

## 5. Transaction safety and duplicate protection

Design chest opening and Rebirth as serialized player operations. A request ID alone does not make a transaction safe. Define a session-scoped monotonically increasing sequence, bounded recent-result cache, and a persisted high-water mark/receipt sufficient to reject expired replays. These identifiers prevent duplicates; they do not authenticate players.

Chest transaction contract:

1. Validate intent, profile ownership, permitted region, chest interaction eligibility, Gold, and inventory capacity.
2. Validate the server catalog/cost/loot pool before changing Gold. Resolve one result on the server; never reroll inside a retryable persistence callback.
3. Stage cost debit, inventory grant, allowed auto-equip, receipt, and revision together. Validate the candidate state before committing it through the coordinator.
4. The same operation retried returns its original result or pending status. A new request still needs eligibility, rate allowance, and funds. A closed session cannot submit another session's sequence.
5. Save related changes and receipt in the same profile snapshot. Publish durable success only after confirming that revision was saved. Bound pending work so save lag cannot grow an unlimited transaction queue.
6. An interrupted reveal does not determine whether the weapon exists; inventory and the saved receipt do. On reconnect, load the durable outcome.

Rebirth follows the same protocol: verify the requirement once; stage resets and permanent bonuses together; prevent chest/equip/travel mutations from interleaving an incompatible state. Keep the existing documented retained-weapon policy consistent with the reset preview.

This is an at-most-once application design within a defined replay scope, not a promise of universal exactly-once execution. One profile does not provide a multi-player atomic trade. Trading, gifts, marketplace transactions, and paid products remain outside this first security boundary and need their own reviewed protocols before introduction.

## 6. Remote, region, and combat enforcement

Roblox recommends server checks for input structure, values, context, and request frequency, including actions triggered by prompts. Its [client-server boundary guidance](https://create.roblox.com/docs/scripting/security/client-server-boundary) also covers non-finite numbers and weapon-hit validation.

Project requirements:

- Charge every incoming request, including malformed/unknown actions, against an aggregate per-player budget before deeper parsing. Keep per-action budgets and cooldowns too; bound expensive work across the server.
- Bound action names, payload keys, nesting, strings, and batch counts. Reject surplus fields rather than storing arbitrary client tables. Sample/aggregate rejection logs; malformed traffic cannot produce unlimited warning output.
- Verify ownership and eligibility inside the domain service as well as the ingress router. A prompt or future server caller must not bypass the same rules.
- The current design requires approaching a chest: enforce a server-side interaction radius and living character, together with region access. Use anchored interaction targets. Region labels alone and client-controlled character movement are insufficient; handle implausible movement and legitimate teleports with tolerances.
- Combat requests describe attempts. The server supplies damage, weapon/ability ownership, cooldown, valid targets, range, and allowed hit windows. Each attack ID limits hits per target; a barrage has a configured hit budget. Cap ability broadcasts and effect frequency.
- Prefer denying an invalid action to automatic permanent bans. Repeated patterns can trigger temporary restrictions and review; lag or one anomalous event is not enough evidence for a ban.

## 7. Privacy, replication, and credentials

Only collect gameplay data needed for this game. Do not collect passwords, email, real names, birth dates, IP addresses, or Roblox session cookies. UserId is an identifier to protect in operational exports, even when its Roblox profile is publicly visible.

Define separate allowlists for owner-only profile views and public presentation. Owner inventory/settings, transaction receipts, moderation notes, and save internals never broadcast to other players. Public display can include approved Power/Rebirth rankings, avatar, and equipped visuals. Gold and personal settings should be owner-only by default; remove unintended public player attributes/leaderstats. Snapshot and delta paths must use the same field allowlist so adding a server field cannot accidentally expose it.

Proposed retention: recent security events 30 days, privileged-action records 90 days, then delete or retain aggregates without account identifiers. Keep gameplay progress while needed to provide the account's game state. Define user-data deletion and recovery procedures before launch, including diagnostics and recovery copies; ensure restored backups cannot resurrect a completed deletion. Do not paste profile dumps or player identifiers into public GitHub issues.

For publishing automation, use a narrowly scoped Open Cloud credential for the intended experience and operation. Keep profile read/restore tools on separate credentials. Store secrets in a proper secret manager, limit access, rotate/revoke them after exposure, and use expiration/rotation deliberately. Never extract browser cookies to work around missing tooling authentication. Roblox describes scopes, secret storage, and key lifecycle in [Manage API keys](https://create.roblox.com/docs/cloud/auth/api-keys).

Production environment identifiers must be checked before publishing or applying migrations. Add secret scanning, pin/review dependencies and plugins, review imported asset scripts, and retain the source commit/build identifier for each deployed version.

## 8. Recovery and operational controls

Backups must be restorable, not merely present. Roblox supports version inspection/restoration with retention and snapshot behavior that must be understood; it is not a per-operation permanent audit log. See [data-store versioning](https://create.roblox.com/docs/cloud-services/data-stores/versioning-listing-and-caching).

Implement a tested restore procedure: restrict account writes; end its active session safely; capture current state; inspect a recovery copy; validate schema and economy; restore using tooling compatible with ProfileStore; resume and verify. Record actor, reason, revisions, operation ID, and result. Avoid raw edits beneath an active lock. Recovery exports use restricted storage and the same deletion policy as primary data.

Monitor save age/failure rate, session contention, migration failures, rejected intents by category, pending operation age, unexpected balance changes, and restore attempts. Keep logs bounded and omit secrets/full payloads. Subscribe operationally to the vendored ProfileStore error, overwrite, and critical-state signals.

Provide restricted controls to disable chest purchases or pause progression independently, then roll back a faulty release. Proposed launch drill target: pause affected mutations within five minutes of an alert and restore a single staging profile within 30 minutes. These are targets until demonstrated; a broad outage has no promised recovery time.

## 9. Current-code findings — open launch blockers

Static review of the local working tree; no live exploit test or cloud persistence test was performed for this specification. ChestService contains pre-existing uncommitted edits and is described as inspected.

| Finding | Evidence | Required follow-up |
| --- | --- | --- |
| Baseline identity/session handling exists | DataService keys profiles by Player.UserId, calls StartSessionAsync, and checks IsActive | Verify two-server contention and session-loss behavior in staging |
| Future-version protection missing | ProfileSchema.Migrate unconditionally replaces Version with 2 | Reject unsupported versions before mutation/autosave |
| Corrupt values can become fresh defaults | Migrate returns template for non-table input and replaces invalid economy numbers | Distinguish known migration defaults from corruption; quarantine with recovery evidence |
| Inventory validation incomplete | Weapon-count loop lacks finite checks; Validate checks containers, not catalog IDs/counts/ownership | Deep schema invariants, size/numeric caps, known-ID validation |
| Chest debit precedes roll validation | ChestService subtracts Gold before checking the returned weapon | Stage/validate full candidate transaction before mutation |
| No duplicate-operation protocol | ChestService uses a 0.35-second cooldown, no durable receipt or sequence | Add serialized operation handling and replay contract |
| Reward response precedes persistence | RequestSave schedules asynchronously; result is sent immediately | Revision-specific durable completion and pending UI |
| Critical-save debounce can keep moving | Each RequestSave increments generation and invalidates the prior delayed call | Coordinator with max wait and save-backlog controls |
| Invalid traffic bypasses action budgets | IntentGate validates before counting; GameService warns on each invalid request | Aggregate ingress budget and sampled rejection logs |
| Physical chest eligibility incomplete | ChestService checks stored CurrentRegion/unlocks, no character distance | Enforce the selected interaction model server-side |
| Replication needs a privacy boundary | Gold/settings become public attributes; StateView.Delta accepts any dirty key | Explicit owner/public views and delta allowlist |
| Monitoring/recovery not demonstrated | Diagnostics contains in-memory counters; DataService lacks operational subscriptions to global ProfileStore signals | Alerts, failure drills, restore procedure, and incident controls |

Files: [DataService](../src/server/Services/DataService.luau), [ProfileSchema](../src/shared/Util/ProfileSchema.luau), [ChestService](../src/server/Services/ChestService.luau), [IntentGate](../src/server/Components/IntentGate.luau), [GameService](../src/server/Services/GameService.luau), [StateReplicator](../src/server/Components/StateReplicator.luau), [StateView](../src/shared/Util/StateView.luau), [Diagnostics](../src/server/Components/Diagnostics.luau).

## 10. Story 1 delivery and acceptance

Complete the following before calling the foundation secure enough for release. Later story services must inherit these contracts.

| Substory | Deliverable | Required evidence |
| --- | --- | --- |
| SEC-01 Identity and environments | Server identity, permission checks, test/prod isolation, creator access review | Cross-account spoof requests rejected; staging cannot address production |
| SEC-02 Profile integrity | Strict schema, migrations, caps, quarantine | Future schema, corrupt counts, NaN, unknown IDs, oversize records rejected without resetting saves |
| SEC-03 Session and save safety | Single writer, save coordinator, durable revisions, degraded state | Two-server join, session loss, continuous activity, timeout/throttling, shutdown tests |
| SEC-04 Economy transactions | Chest/Rebirth coordinator and replay receipts | Same request repeated 100 times applies once; crash before/after durable save resolves consistently |
| SEC-05 Abuse boundaries | Aggregate/action budgets, context checks, bounded diagnostics | Malformed flood remains bounded; distant chest and unowned equip rejected |
| SEC-06 Privacy and credentials | Owner/public allowlists, secret handling, minimal data retention | A second client cannot inspect private state; build contains no credentials |
| SEC-07 Recovery and operations | Restricted restore tooling, alerts, mutation pause, deletion workflow | Restore and deletion drills in staging, including restore-after-deletion protection |

SEC-04 also tests two distinct valid purchases, insufficient funds, missing loot pool, duplicate Rebirth, reconnect, and a timeout where the write actually succeeded. Record when a reward is pending, usable, and durable. Test save-budget saturation at the expected server population.

For Story 4/5, add attack replay, out-of-range hits, unowned abilities, excessive barrage hits, and effect-spam tests. For Story 7, run the whole progression/rejoin/Rebirth journey under save failure as well as normal operation.

Security states must fit the existing 60% Clover-inspired fantasy / 25% Terraria readability / 15% modern Roblox usability direction. Use short messages such as “Saving your reward…” or “Progress is paused while saving reconnects.” Keep details and stack traces in restricted diagnostics. Never show “Saved” for an unconfirmed revision.
