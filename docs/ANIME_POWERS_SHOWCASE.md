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
