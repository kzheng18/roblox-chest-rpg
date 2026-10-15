# Linear world layout — version 3

One starting base leads into one continuous road through the regions. The user's references, including [+1 Loot to Forge](https://www.roblox.com/games/118805555015549/1-Loot-To-Forge), inform the flow; the geometry, signs, props and themes are ours.

```text
STARTING BASE
  Sell equipment / upgrade forge / spawn plaza
       |
VERDANT CROSSROADS
  Encounter areas / regional chest / boss clearing
       |
FROSTFALL GATE — 2,500 Power
       |
FROSTFALL KINGDOM
  Encounter areas / regional chest / boss clearing
       |
EMBERREACH GATE — 12,000 Power
       |
EMBERREACH DOMINION
  Encounter areas / regional chest / boss clearing
       |
FUTURE REGIONS
```

## Layout and movement

- There is exactly one base and one pair of sell/upgrade stalls, at the beginning of Verdant.
- All three regions share the road's X coordinate. Their ground sections touch edge-to-edge, with no gaps or intervening back walls.
- The starting plaza retains its 43-stud radius and spacious stalls. Verdant measures 260 × 340 studs; Frostfall and Emberreach each measure 200 × 260 studs. Later regions are 35% shorter and about 23% narrower than the earlier 260 × 400 blockout. The full route is 860 studs long, down from 1,200.
- The 20-stud road continues through each entrance. Chests are in clearings beside it, so they do not obstruct forward travel.
- Each region reserves four encounter positions and a separate boss clearing. Mobs and combat are still future work.
- Later regions have compact arrival/respawn waypoints instead of repeated base plazas. Menu fast travel remains available for unlocked regions.
- Walking into an unlocked region updates CurrentRegion, the HUD, and the regional respawn location without teleporting the avatar. Walking backward works the same way.
- Gates expose the existing unlock/travel prompt. Unlocking requires the preceding region and the configured Power requirement. Crossing a locked boundary returns the player just before the first locked entrance.
- Rebirth explicitly returns the avatar to the starting base, including when rebirthing while already in Verdant.

Sell/upgrade stalls remain marked **Coming soon**. Layout changes do not add equipment transactions, mob rewards, sword models or attacks. Gold training and Gold-funded chest rolls remain the playable prototype economy.

## Regional identity

| Region | Original scenery and focal point | Chest |
| --- | --- | --- |
| Verdant Crossroads | Ancient oak, moss-capped rocks, woodland trees, wildflowers, stream and mossy ruins. The base has a fountain and wooden lamps. | Wooden and gold Grovekeeper Cache with leaf detailing. |
| Frostfall Kingdom | Snow-covered angular pines, ice faces, a frozen pond, crystal markers and the Glacier Watchspire. | Silver-blue Glacier Reliquary with a crystal crest. |
| Emberreach Dominion | Jagged basalt, a lava channel, charred trees, braziers and the Cinder Furnace with its molten crown. | Dark iron Cinder Vault with copper trim, horns and molten seams. |

Entrance arches use each region's materials and accents. Open fields keep four reserved encounter positions and a boss clearing around the central road; chests remain close beside it. Decorative foliage, crystals and lights do not block paths. Lava, ice and the stream are visual scenery only, with no damage or sliding mechanics yet.

This is an original stylized geometry pass built with Roblox parts and native meshes. It establishes silhouettes, palette and navigation before mobs and weapon animations are added.

## Implementation and extension

`src/shared/Config/Regions.luau` owns the ordered region catalog and centers: Verdant at Z=0, Frostfall at Z=-300, Emberreach at Z=-560. `WorldLayout.Get(regionId)` owns each region's width, front/back bounds, spawn, chest, encounter and gate offsets. Verdant ends at Z=-235, Frostfall at Z=-495 and Emberreach at Z=-755. Adding a later region also requires its layout, economy and weapon catalog; the future entrance alone does not supply those systems.

`WorldBuilder` generates the single base and connected region road in Edit and Play. `WorldService` attaches prompts and polls server-observed character positions. `RegionService` uses active server profiles to accept unlocked crossings or return locked crossings. Walking does not grant unlocks, currency or equipment.

The crossing guard is progression enforcement, not a complete movement anti-cheat. Gameplay rewards still validate their own authoritative context. The approach follows [Roblox's guidance to validate on the server and correct invalid progression](https://create.roblox.com/docs/scripting/security/server-side-detection).

The committed `src/world/ChestRPGWorld.rbxmx` is an Edit-mode snapshot. Play rebuilds attributes and interactions from the source builder. To refresh the snapshot, build an Edit preview, capture its JSON using `tools/capture_world.luau`, then run:

```sh
python3 tools/export_world.py capture.json src/world/ChestRPGWorld.rbxmx
rojo build -o ChestRPG.rbxlx
```

The exporter also accepts an ordered batch of small MCP response chunks when the snapshot exceeds tool output limits.

## Verification

Run the engine check from a normal server Script during Studio Play:

```lua
print(require(game.ServerStorage.UnitTest.MapPlaytest)(game.Players:GetPlayers()[1]))
```

The Studio mock-only runner temporarily supplies unlock requirements and restores the original profile. It checks one base, connected ground, collision-aware routes, a real walk to the chest, forward/backward seam crossing, no teleport on walking, respawn selection and rejected locked/skipped progression.

September 30, 2026 — compact region art pass:

- **32/32 live map checks passed.** [Results](playtest/2026-09-30/region-art/map-results.json). These include collision-aware routes in all three regions, a real walk to the chest, forward/backward crossings, respawn selection and locked/skipped-region rejection.
- **63/63 local regression checks passed**, including the revised boundaries and progression checks.
- **15/15 live gameplay checks passed.** [Results](playtest/2026-09-30/region-art/features-results.json). These include nearby and higher-region chests, training, ownership, rejected requests, travel, Rebirth and settings. Tests use temporary Studio mock profiles.
- [Full route overview](playtest/2026-09-30/region-art/overview.jpg), [Verdant](playtest/2026-09-30/region-art/verdant.jpg), [Frostfall](playtest/2026-09-30/region-art/frostfall.jpg) and [Emberreach](playtest/2026-09-30/region-art/emberreach.jpg).
- Fresh Play showed the HUD and new scenery correctly. Pressing **E** within range of the Grovekeeper Cache spent 25 Gold (100 → 75) and displayed an Ironleaf Sword reward. [Interaction result](playtest/2026-09-30/region-art/chest-prompt.json), [base in Play](playtest/2026-09-30/region-art/base-play.jpg), [woodland chest](playtest/2026-09-30/region-art/grove-play.jpg).
- The 917-instance Edit snapshot includes the native foliage meshes and wedge models; the final Rojo build and whitespace validation passed.
- Studio was left in Play at the starting base with `SpawnStatus = Ready` and the reward panel closed. [Final session result](playtest/2026-09-30/region-art/final-play.json). Console output contained only the expected Studio API/mock-save warning.

The previous linear blockout and gate-prompt evidence remain in [September 29's artifacts](playtest/2026-09-29/linear/). This pass does not verify physical-device touch, multiplayer walking, live cloud persistence, mob AI, combat or equipment transactions. The earlier non-linear blockout evidence remains in the previous `map/` artifact directory.
