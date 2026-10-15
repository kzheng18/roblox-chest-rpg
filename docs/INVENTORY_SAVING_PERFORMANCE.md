# Inventory, automatic saving, and performance — October 13, 2026

This implementation preserves the existing map, original sword geometry, drop
balance, and equipment families. It does not add trading, paid products, unique
weapon rolls, selling, upgrades, mobs, or damage systems.

## Ownership and migrations

- Profile keys remain `Player_<Roblox UserId>` in `ChestRPG_PlayerData_v1`.
- Schema 3 adds a server-only `OwnerUserId`, a chest transaction sequence and the
  last receipt. Legacy profiles receive their authenticated owner's ID without
  changing valid item counts or earned balances.
- Active profile ownership must match the requesting Player for gameplay access.
  Roblox supplies that Player; remote payloads cannot choose another owner.
- Invalid progression, invalid counts, cyclic/nested inventory, future schemas,
  and mismatched owners stop loading. No default inventory overwrites the record.
  Presentation preferences can be repaired independently of earned progression.
- Inventory maps are independent per profile. Detailed state goes only through
  `FireClient(owner, ...)`; public character equipment remains visible in the world.
  Save receipts and owner bindings are excluded from snapshot/delta payloads.
- Retired weapon identifiers remain stored for recovery but do not confer usable
  equipment ownership. Inventory/region dictionaries have a 512-key integrity
  guard; this is not a gameplay storage limit or an automatic item deletion rule.
- Ordinary identical items remain counted stacks. Persistent individual item IDs
  belong with future per-item upgrades/attributes and are not fabricated here.

## Save behavior

- ProfileStore's autosave/session-lock schedule is 60 seconds. Its existing
  staggering, leave saves, shutdown handling, and lock ownership remain in use.
- All commits mark a newer revision pending. Critical rewards, equipment, settings,
  unlocks and Rebirth request checkpoints.
- The first checkpoint starts a fixed four-second scheduling deadline. Later
  requests coalesce without postponing it. Scheduler resolution is one second;
  network/storage completion is asynchronous and can take longer.
- Critical requests check UpdateAsync request budget. Unavailable budget leaves
  them queued. Attempts without acknowledgement after 15 seconds retry with
  exponential delay, capped at 30 seconds. Late acknowledgements can still satisfy
  a pending checkpoint. These are scheduling settings, not durability guarantees.
- `SavedRevision` reflects the acknowledged snapshot, not whatever revision the
  current profile happens to contain. A newer change remains Pending/Queued even
  when an older snapshot completes successfully.
- The HUD distinguishes Pending, Queued, Saving, Saved and Delayed. Studio mock
  saves are explicitly labelled as Studio tests; they are not cloud save evidence.
- Reward reveals compare the receipt's commit revision with `SavedRevision`, so
  a reward can show saved while newer ordinary progression still awaits autosave.

Sudden process termination or a prolonged Roblox outage can still lose unacknowledged
changes. A reward currently enters the active session immediately; its cloud durability
is only confirmed by the save acknowledgement. There are no paid products to process.
Any future paid receipt handler must persist the grant and processed receipt before
acknowledging the purchase, per [Roblox purchasing guidance](https://create.roblox.com/docs/cloud-services/data-stores/player-data-purchasing).

## Chest transaction contract

Client `OpenChest` payload: `{RegionId = "verdant", Sequence = lastSequence + 1}`.
Only those two fields are accepted. Sequence must be a positive safe integer.

The next sequence validates region, active profile, proximity, cooldown, balance,
loot and item count before a non-yielding debit/grant/receipt update. The receipt
and high-water mark save in the same profile as the currency and inventory.

Retrying the latest sequence returns the recorded reward without another debit,
grant or save request. Older sequences are rejected forever; skipped sequences
request a state refresh. Failed purchases do not advance the sequence. Rebirth
preserves it. The client suppresses repeated reveal events and retries with the
same sequence. Trusted server prompts/playtests may use region-string shorthand;
the actual remote entry rejects that legacy form.

This prevents replay of a persisted transaction. It cannot recover a transaction
that never reached durable storage before a crash.

## Recovery

Roblox's datastore version history is the recovery source; no extra inventory
datastore or per-roll backup key is introduced. Version history has platform
granularity and retention limits, not one guaranteed backup for every reward.

`Server.Components.RecoveryPlan.Prepare(current, archive, ownerUserId)` prepares an
independent, schema-validated restoration. It rejects another owner's archive and
preserves the current chest sequence/receipt so restoring old inventory cannot
re-enable old purchase requests. It changes neither live data nor cloud storage.
There is deliberately no player-callable recovery/transfer endpoint.

Operator procedure: locate versions for the exact UserId key, retain the current
record, compare/prepare the proposed restoration, and ensure active sessions are
ended before applying an offline recovery through the datastore management tools.
Do not use a view-mode overwrite against an active session. The preparation logic
is tested locally; an actual cloud version restore is still a published-test-server
acceptance check. [Roblox data-store guidance](https://create.roblox.com/docs/cloud-services/data-stores/best-practices)

## Performance

- Reference target: 240 FPS at a stated resolution and graphics preset on a
  designated capable Windows PC. A frame budget is approximately 4.17 ms.
- This does not force the player's Roblox cap, monitor refresh rate or graphics
  settings. Roblox server heartbeat is separate from client rendering.
- Settings offers Auto/Low/High. Auto uses low effects on mobile when graphics is
  automatic, and follows a manually selected low graphics level (1–4).
- Low reduces continuous particle emitter rates to 25% and disables local shadows on
  game-owned scenery, weapon visuals and explicitly tagged `RPGEffect` objects.
  High restores original values. Hit cues are not disabled. Other lighting stays
  untouched. Streaming additions receive the current setting.
- Quality application yields every 200 descendants. Render sampling uses one
  fixed-size histogram and publishes local measurements once per second. It sends
  no gameplay remotes, performs no datastore calls and grants no rewards.
- `ClientFPS`, `ClientFrameP95Ms` and `ClientFrameWorstMs` are client-only diagnostic
  attributes. P95 is quantized in quarter-millisecond buckets; the overflow bucket
  conservatively reports the window's worst frame. Use MicroProfiler for precise
  CPU/GPU attribution. Settings shows measured FPS, not the target as a result.
- Power/Gold threshold controls update in place while menus are open. They do not
  recreate inventory cards on every training delta.

Reference benchmarks must use the standalone Roblox client, including populated
combat, not an empty Studio view. Test identical progression inputs at 30/60/144/240
FPS, plus a physical mobile session. No real 240 FPS benchmark has passed yet.
[Roblox performance guidance](https://create.roblox.com/docs/performance-optimization/identify)

## Reproducible local verification

```sh
python3 tools/test_local.py /path/to/luau
python3 tools/test_data_service.py /path/to/luau
python3 tools/test_performance.py /path/to/luau
python3 tools/audit_model_scripts.py
rojo build -o ChestRPG.rbxlx
```

The I/O doubles execute production Luau and intentionally separate code-level
verification from Roblox physics, live cloud storage, actual session-lock races
and hardware performance. The model audit permits only exact JSON literal-return
modules in the sword package and rejects other executable scripts in packaged
`.rbxmx` assets. It is not an audit of arbitrary installed plugins or privileged
third-party server code.

Current local results: **88 regression + 14 persistence-wiring + 7 effects-controller
checks passed (109 total)**. All **61 Luau files compiled**, the Rojo place built,
and the packaged-model audit passed for 55 JSON-only geometry modules. Evidence:
[local results](playtest/2026-10-13/inventory-saving-performance/local-results.json).
The Studio bridge was reachable but reported **Place is not open**. No Studio
installation, fresh Play session, live cloud save, or hardware FPS benchmark is
claimed for this implementation.

Before release: two real clients, save/rejoin, failed writes, delayed responses,
server shutdown, competing session acquisition, version restoration, visible
HUD/settings controls, and device profiling must pass in an isolated published
test experience. Production data is never the test target.
