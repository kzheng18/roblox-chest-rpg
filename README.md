# Roblox Chest RPG

A standalone Roblox progression RPG built around a simple loop:

`Power -> Gold -> regional treasure chests -> Luck-weighted weapons -> stronger progression -> new regions -> Rebirth`

This repository is intentionally separate from Aura Ascension. Aura Ascension is not a dependency and its game logic is not modified by this project.

## Current playable foundation

- Profile-aware player spawning with standard Roblox movement/camera, a regional respawn point, and a three-second death respawn.
- Nearby chest interaction using the default E/gamepad/touch prompt, routed through the validated gameplay gateway.
- Server-authoritative Power and Gold training.
- Persistent ProfileStore-backed player data with Studio mock saves.
- Three configured regions with Power gates and fast travel.
- One regional treasure chest per region.
- Server-side weapon rolls with Luck-adjusted reciprocal rarity display (`1/N`).
- Persistent weapon inventory and equip/equip-best flows.
- Eleven original modeled swords with curved blades, swept guards and wrapped grips; server-owned equip visuals are wired. Play rendering requires **Allow Mesh & Image APIs** in Experience Settings. See [models and verification status](docs/SWORD_MODELS.md).
- Rebirths that accelerate Power, Gold, and Luck while preserving weapon collection.
- Dark charcoal/slate inventory and menus with muted gold accents, vertical sidebar navigation, searchable/sortable weapon cards, and responsive detail panels. See [the current UI direction](docs/UI_STYLE.md).
- Optional chest roll reveal animation that can be disabled in Settings.
- One starting base with sell/upgrade stalls and a continuous road through Verdant, Frostfall and Emberreach; regional chest clearings, Power gates and reserved encounter/boss areas.
- Distinct woodland, frozen-ruin and volcanic-forge scenery with original landmarks and themed chests. Later regions are 35% shorter than the earlier blockout; the starting plaza stays spacious.
- Walking between unlocked regions updates the HUD and respawn without teleporting; locked crossings are returned before the entrance.

The product direction and staged build order live in [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md).

## Autosaving, inventory ownership, and performance

Automatic ProfileStore saves/session-lock refreshes run on a 60-second schedule.
Critical checkpoints coalesce behind a fixed four-second deadline, with budget-aware
retries and revision-aware save status. Profiles are bound to Roblox UserId; failed
loads never become writable empty inventories. Chest requests use persisted sequence
numbers so network retries cannot debit or grant twice. Existing weapon stacks remain
stacks; individually upgraded items do not exist yet.

Settings offers Auto/Low/High effects and the locally measured frame rate. The target
is 240 FPS on a defined capable Windows PC, not a guarantee for every device. Quality
changes affect local shadows and particles; rendering never grants progression.

See [implementation, recovery, and verification limits](docs/INVENTORY_SAVING_PERFORMANCE.md).

The [map layout](docs/MAP_LAYOUT.md) defines the current world and iteration points. Sell/upgrade stalls are layout placeholders; mob combat, equipment transactions and weapon animations come next.

Story 1's [core systems and security contract](docs/CORE_SYSTEMS_SECURITY.md) defines identity, data integrity, transaction safety, privacy, and recovery requirements, with current code gaps and release acceptance checks. These are requirements under development, not a claim that the prototype has passed a security audit.

## Client validation

Gameplay requests use strict action/payload schemas, catalog ID checks, per-player and server token budgets, and active server-owned profiles. Training and travel require a living character; chest purchases also require the player to be within 24 studs of the anchored regional chest. The menu displays a move-closer message when a purchase is attempted too far away. Equipment requires a finite, positive integer ownership count. Invalid requests are rejected without unbounded warning output.

New client-triggered entry points must route through `GameService.Handle` (including rate limits); domain services also validate payloads and authoritative context. No combat endpoint exists yet. Chest requests use persisted sequence/receipt checks in addition to cooldowns; proximity checks are not full movement anti-cheat. See [validation evidence and remaining work](docs/CLIENT_VALIDATION.md).

The [October 15 agent handoff](docs/AGENT_HANDOFF_2026-10-15.md) records the current checks, remaining UI acceptance work, and review of the anime-power proposal. This is a development snapshot; the game has not been publicly released.

Run the regression suite using the official Luau CLI:

```sh
python3 tools/test_local.py /path/to/luau
```

This executes production modules with explicit Roblox I/O doubles. It does not test engine networking, physics, or cloud saves. In Studio, the existing unit cases can also be run with `require(game.ServerStorage.UnitTest.RunUnitTest)()`.

## Build

```bash
rojo build -o ChestRPG.rbxlx
```

Open the generated place in Roblox Studio for playtesting, or run `rojo serve` and connect with the Rojo Studio plugin.

## Play in Studio

Open `ChestRPG.rbxlx` and choose **Play (F5)**, not Run; Play creates the controllable test player. Move with the default Roblox controls, use the **TRAIN** button to earn Power/Gold, and approach a chest to press **E** (or its touch/gamepad prompt). Inventory offers Equip Best; Regions offers unlock/travel; Rebirth resets the run and returns the avatar to the starting region. Death respawns at the current unlocked region. Studio profiles are temporary.

For a scripted feature check, wait until your character has spawned, then run this from a temporary **server Script** during Play:

```lua
require(game.ServerStorage.UnitTest.StudioPlaytest)()
```

The runner checks training, chests, ownership, rejected requests, region travel, Rebirth, settings, and respawn. It temporarily supplies milestone Power to exercise later features, then restores the mock progression. It refuses production sessions. This tests feature wiring, not normal progression pacing or real cloud saves.

Use a normal server Script so the check shares the running game's module state; an Assistant/plugin command can load a separate module cache. Delete the temporary Script after testing.

Live Studio verification on September 29, 2026 passed all 15 scripted feature checks and exercised the desktop HUD, menu tabs, training, chest button/reveal, E chest prompt, equipment, settings, keyboard shortcuts, and movement. Phone landscape/portrait layouts were visually checked in the iPhone 17 Pro simulator. Physical-device touch and cloud persistence remain unverified. See [verification evidence](docs/STUDIO_VERIFICATION.md).
