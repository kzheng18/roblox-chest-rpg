# Anime Powers and Showcase Plan

> Direction for adding anime-inspired powers to Chest RPG, one anime per update, and for showing those powers off in game. This doc covers design intent. Build order and acceptance targets stay in [GAME_DESIGN.md](GAME_DESIGN.md).

## Core idea

Each content update adds a new anime theme. Every theme brings its own powers, models and boosts, all inspired by that anime but using **original names and designs**. Powers drop from regional chests the same way weapons do: better regions hold better loot.

The first theme is a pirate / devil-fruit style anime. It starts with simple elemental fruits. A second layer, a willpower ability inspired by haki, unlocks later.

## Decisions

| Topic | Decision |
| --- | --- |
| Rolling animation | **One shared roll and reveal sequence for every anime.** Only the item model, colors and sounds change per theme. |
| Item models | Each anime has its own model set for its items, such as fruits, blades or scrolls. |
| Power scaling | **Each anime has its own power curve.** Balance each theme against the regions where it drops, not against a single global table. |
| Naming | **No real anime names.** Use descriptive original names. See the naming rules below. |
| Architecture | One shared power framework. A new anime is a config entry plus a VFX module, never a new system. |
| Stacking | **Each anime has its own equip slot, and the slots multiply together.** A Fruit and a Grimoire equipped at once stack on top of the weapon and rebirth bonuses. |

## Naming rules (copyright safety)

- Never use character names, attack names, fruit names, crew names, logos, or music from the source anime.
- Name powers after what they do or what they are made of.
- Inspired visuals are fine. Copied designs, recolors of official art, and official audio are not.

| Source idea | Original name to use |
| --- | --- |
| Gum-Gum style rubber fruit | **Rubber Fruit** |
| Flame fruit | **Flame Fruit** |
| Ice fruit | **Frost Fruit** |
| Smoke fruit | **Smoke Fruit** |
| Light fruit | **Radiance Fruit** |
| Haki | **Willpower** (tiers such as Guard, Sense and Sovereign Will) |
| Sword-style techniques | **Blade Arts** |

Add a row here whenever a new power is named, so every update follows the same rules.

## How players show off powers

These patterns come from popular Roblox games. All of them read from the shared framework, so every new anime gets them for free.

### 1. Rare-roll cutscenes
Inspired by Sol's RNG. The reveal gets more dramatic the rarer the drop.
- Common: quick popup.
- Rare and Epic: brief glow, color flash, sound sting.
- Legendary and Mythic: screen darkens, camera zooms on the chest, the item model spins out with the anime's theme colors, and the drop odds are shown ("1 in 4,000").

### 2. Server-wide announcements
Inspired by Pet Simulator 99 and Sol's RNG. Rare pulls are announced to everyone in the server, for example "Player pulled **Flame Fruit** (1 in 4,000)!" The very rarest pulls can be announced across all servers.

### 3. Always-on auras
Inspired by Anime Fighting Simulator and Sol's RNG. An equipped power gives a constant, lightweight effect, such as embers drifting from a Flame Fruit user or frost mist around a Frost Fruit user.

### 4. Equip / "eat" moment
Inspired by Blox Fruits. Equipping a new power plays a short transformation: the character consumes or absorbs the item, then the aura bursts on.

### 5. Signature skill on a key
One flashy move per power that nearby players can see, such as a fire pillar or an ice spike burst. Before combat exists it can give a short training boost. Once combat (Stage 4) lands it becomes a real attack.

### 6. Titles above heads
Show the player's rarest owned power or achievement above their name, in its rarity color, for example "Frost Sovereign" or "Sovereign Will".

### 7. Collection index
A book of every power from every anime. Unfound entries show as silhouettes. Completing an anime's page can grant a small permanent boost. This gives collectors a goal that grows with every update.

### 8. Hub showcase
A pedestal area or leaderboard in the hub that displays top players and their rarest pulls.

## Suggested build order

1. Shared power framework: power config table with the same fields as weapons (region, rarity, rate, luck exponent, multiplier, anime theme), plus a per-power VFX module slot.
2. Rare-roll cutscenes and server announcements, hooked into the existing chest reveal.
3. Always-on auras and titles.
4. Equip moment and signature skill key.
5. Collection index and hub showcase.

## Risks and guardrails

- **Update treadmill.** If each anime needs custom code, updates slow down and break old content. Keep every anime data-driven on top of the shared framework.
- **Power creep.** Tie each new anime to new regions as the next tier, so old content still has a place and numbers stay readable.
- **Performance.** Many players with auras and skills can lag phones. Keep auras light, limit particle counts, reduce effects at distance, and add a setting to hide other players' effects.
- **Copyright.** Risk grows with every recognizable franchise added. Follow the naming rules above for every update.
- **Animations.** Custom animations play in Studio testing, but must be published to the game owner's Roblox account to get animation IDs for the live game.

## Implementation status (branch `feature/power-framework`)

Built and covered by local tests. Not yet synced into the Studio place or playtested live.

| Piece | Where |
| --- | --- |
| Power catalog: themes, slots, per-region pools, drop chances | `src/shared/Config/Powers.luau` |
| Exact final odds and the power roll | `src/shared/Util/PowerOdds.luau` |
| Reveal tiers and announcement thresholds | `src/shared/Config/Showcase.luau` |
| Stacking math: `PowerStackMultiplier`, `PowerGain` | `src/shared/Util/Progression.luau` |
| Save schema v4: `OwnedPowers`, `EquippedPowers`, power in chest receipt | `src/shared/Util/ProfileSchema.luau` |
| Bonus power roll, per-slot auto-equip, replay-safe receipt | `src/server/Services/ChestService.luau` |
| Server and cross-server rare-pull announcements | `src/server/Services/AnnouncementService.luau` |
| Equip Best fills every anime slot | `src/server/Services/ProgressionService.luau` |
| Tiered reveal queue: weapon first, then bonus power | `src/client/Controllers/UIController.luau` |
| Camera push, darken, burst, shockwave | `src/client/Controllers/CinematicController.luau` |
| Shared spinning turntable, plus fruit, grimoire and weapon models | `src/client/UI/ItemModels.luau` |
| Announcement banners and chat line | `src/client/Controllers/AnnouncementController.luau` |

### How a chest opening works now

1. The weapon roll is unchanged.
2. A separate bonus roll can also grant a power. Chance per opening: Verdant 12%, Frostfall 14%, Emberreach 16%.
3. If a power drops, it goes into that anime's slot when it beats what is equipped there.
4. Every reveal uses one universal layout: the same background, panel, and spinning turntable. Only the item inside changes. During the roll the turntable spins through candidate items, and a power roll only shows items from that anime. Before a Legendary or Mythic reveal, the item spins as a dark silhouette.
5. The reveal plays the weapon, then the power. Common and Uncommon get the normal roll. Rare and Epic add a color flash. Legendary and Mythic get the cinematic. Every reveal can be skipped, and Reduced motion keeps the camera still.
6. Legendary, Mythic, or 1-in-1,000 pulls are announced to the server. Mythic or 1-in-5,000 pulls are also sent to every server. Cross-server messages are off in Studio.

Power odds shown to players are exact final odds. Weapon odds keep the existing per-check display, which the scaling review flags separately.

### Adding the next anime

1. Add a theme to `Powers.Themes` with a new `ModelKind`.
2. Add its powers to `Powers.List` with original names, regions, weights and multipliers.
3. Add one model builder for the `ModelKind` in `src/client/UI/ItemModels.luau`.

Rolling, saving, stacking, reveals and announcements need no changes.

### Not built yet

- An inventory page for powers. Powers equip automatically, and Equip Best fills every slot.
- Auras, titles, the equip moment, skill keys, the index and the hub showcase.
- Sounds for reveals. No audio asset IDs have been chosen.
