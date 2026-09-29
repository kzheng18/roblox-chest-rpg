# Chest RPG — User Stories and Build Order

> Planning backlog for the next progression-game direction. The current Aura Ascension RNG implementation remains intact while this design is iterated and validated.

## Product north star

The game should be immediately understandable, satisfying within the first minute, and deep enough that obtaining a rare weapon feels like unlocking new gameplay instead of only receiving a larger number.

The core loop is:

```text
Gain Power
  -> earn Gold
  -> open the current region's Treasure Chest
  -> roll a Weapon using Luck
  -> equip a stronger or rarer Weapon
  -> fight more effectively and gain Power faster
  -> unlock the next Region
  -> Rebirth for permanent Power, Gold, and Luck growth
  -> repeat faster while hunting rare weapons and abilities
```

### Visual and UX direction

Every screen and interaction should follow the same reference mix:

- **60% Clover RPG fantasy interface:** fantasy-world mood, illustrated RPG framing, immersive menus, strong world identity.
- **25% Terraria inventory/readability:** compact slot grids, instantly readable icons, clear rarity treatment, dense information without clutter.
- **15% Project Slayers-style modern Roblox RPG usability:** large touch targets, clear navigation, responsive prompts, modern controller/mobile behavior.

These are references for hierarchy, pacing, and feel only. All art, panels, icons, models, names, animations, audio, VFX, and other shipped assets must be original.

## Global UX rules

- A first-time player should know what to do within roughly five seconds.
- The first meaningful reward should arrive in roughly one minute.
- The player should almost always have one obvious next goal.
- Teach systems when they become relevant instead of front-loading tutorials.
- Keep the always-visible HUD focused on **Power, Gold, and Luck**.
- Use readable number formatting such as 12.5K, 8.2M, and 1.4B.
- Core play must remain comfortable on keyboard/mouse, controller, and mobile.
- Complex depth can exist behind simple actions; the player should not need to understand formulas to progress.

---

## Story 1 — Core Game Logistics / Systems Foundation

**Priority:** P0 — foundation for every other story.

**User story:** As a player, I can join, load my progression, gain resources, leave, return, and continue from a valid saved state while every gameplay system uses the same source of truth.

### Required player state

| Data | Purpose |
| --- | --- |
| Power | Main progression stat and region gate |
| Gold | Main treasure-chest currency |
| Luck | Modifies rare weapon outcomes |
| Rebirths | Permanent meta-progression |
| Owned Weapons | Persistent weapon inventory |
| Equipped Weapon | Current primary weapon |
| Unlocked Regions | Region progression state |
| Settings | Player UX/accessibility preferences |

### System requirements

- Versioned player profile schema with safe migrations.
- Autosave, leave-save, session locking, and recovery behavior.
- Server-authoritative rewards, purchases, rolls, damage, and progression.
- Shared configuration for region requirements, weapon stats, rarity tables, chest costs, and progression formulas.
- Clear service boundaries for progression, regions, weapons, chests, combat, and UI-facing replication.
- Central number-formatting and stat-display utilities.
- Rebirth logic that can reset run progression while preserving intended permanent state.
- No client-provided currency amounts or reward outcomes.

### Architecture target

```text
Player Profile
  |- Power
  |- Gold
  |- Luck
  |- Rebirths
  |- Unlocked Regions
  |- Owned Weapons
  '- Equipped Weapon

        |
        v

Progression Service
Region Service
Chest Service
Weapon Service
Combat Service
        |
        v
Client Controllers / UI
```

### Definition of done

- A player can join, gain Power and Gold, change progression state, leave, rejoin, and recover the expected state.
- Invalid client requests cannot directly grant currency, weapons, unlocks, or damage.
- Balance values can be changed from configuration without rewriting multiple systems.
- Placeholder HUD can display Power, Gold, and Luck from replicated authoritative state.

---

## Story 2 — Regions / World Progression

**Priority:** P0.

**User story:** As a player, I always know which region I am in, what region comes next, and exactly what I need to unlock it.

### Region data

Each region owns or references:

- ID and display name.
- Required Power.
- Environment/theme identity.
- Regional treasure chest.
- Regional weapon pool.
- Economy scaling.
- Enemy roster.
- Boss reference for later combat content.
- Arrival/fast-travel point.
- Music, ambience, lighting, and VFX profile.

### UX requirements

- The next region should be physically visible whenever practical.
- A locked entrance clearly shows the region name, current Power, required Power, percentage complete, and remaining Power.
- Unlocking a region should feel like a world milestone, not a generic simulator door purchase.
- Entering a region briefly presents its name/theme without blocking control.
- Unlocked regions support simple fast travel.

Example:

```text
FROSTFALL KINGDOM
Requires 250K Power

Your Power: 184.2K
[###########----] 73%
65.8K remaining
```

### Definition of done

- At least three placeholder regions can be traversed in progression order.
- Requirements come from configuration.
- Unlock state persists correctly.
- Region UI communicates progression without a tutorial paragraph.
- Region 2 and Region 3 can be reached using Story 1 progression only.

---

## Story 3 — Treasure Chests + Weapons

**Priority:** P0.

**User story:** As a player, I can spend Gold on a region chest, have Luck influence the result, receive a weapon from that region, inspect it, equip it, and immediately feel stronger.

### Chest rules

- Each region has a distinct chest and weapon pool.
- Higher regions improve the baseline and maximum strength of available weapons.
- Luck affects weighted outcomes inside the current chest pool.
- The player can inspect base/current odds before opening.
- Chest cost is clear before purchase.
- Reward selection is performed on the server.
- Rare rewards escalate reveal animation, sound, and VFX.
- Multi-open can be added later without changing the underlying roll pipeline.

### Initial weapon data

- Weapon ID.
- Name.
- Region.
- Rarity.
- Power multiplier.
- Inventory icon.
- Equipped model reference.
- Weapon family/type.
- Optional ability ID.
- Optional passive ID.
- Animation profile.
- VFX profile.

Only the first six fields plus weapon family are required for the first playable version.

### Initial rarity direction

```text
Common -> Uncommon -> Rare -> Epic -> Legendary -> Mythic -> Divine -> Celestial -> Secret
```

Not every region needs every rarity.

### Inventory requirements

- Compact slot grid.
- Clear equipped state.
- Rarity readable by icon/frame/name treatment.
- Tap/hover details for important stats.
- Equip action.
- Equip Best.
- Lock/favorite support can follow once the base inventory is stable.

### Definition of done

- Region 1 player can earn Gold, open a chest, receive a server-selected weapon, and see it in inventory.
- Luck measurably changes weighted outcomes while preserving valid probability behavior.
- Equipping a stronger weapon increases the player's Power-gain effectiveness.
- A player can use Region 1 weapons to reach Region 2 and access Region 2's stronger chest.
- The full chest -> inventory -> equip path works on desktop and touch.

---

## Story 4 — Weapon Combat + Animation Framework

**Priority:** P0.

**User story:** As a player, when I equip a weapon, it appears on my character and gives me responsive, satisfying combat that can scale from simple weapons to rare signature abilities.

### First combat version

| Requirement | Expected behavior |
| --- | --- |
| Equip | Correct weapon model attaches to character |
| Idle | Weapon family provides a suitable equipped stance |
| Basic attack | Click/tap performs a readable attack |
| Combo | Initial three-hit light chain |
| Hit detection | Server validates legitimate hits |
| Damage | Derived from player/weapon/combat configuration |
| Reaction | Target visibly responds to impact |
| Feedback | Sound, small VFX, and readable damage feedback |
| Cooldown/rate limit | Prevents attack spam and invalid requests |
| Mobile | Large, accessible attack control |
| Controller | Standard attack binding works |

### Reusable weapon-family architecture

```text
Weapon
  -> Weapon Family
  -> Animation Profile
  -> Combat Profile
  -> VFX Profile
```

Example:

```text
Iron Sword
  Family: Sword
  Animation: LightSword
  Ability: none

Infernal Greatsword
  Family: Greatsword
  Animation: HeavySword
  Ability: Flame Rupture

Astral Gauntlets
  Family: Gauntlets
  Animation: FistCombat
  Ability: Hundred-Fist Barrage
```

### Input philosophy

The base game should remain simple:

```text
M1 / Tap -> Basic Attack
Q / Ability Button -> Signature Ability
```

Avoid turning the core loop into a many-key MMO action bar.

### Definition of done

- Chest reward -> inventory -> equip -> visible world model -> basic attack is one working path.
- At least two weapon families can share the framework while using different animation/combat profiles.
- Hits, damage, and cooldown enforcement are server-authoritative.
- Combat feels readable on desktop and mobile.

---

## Story 5 — Rare Weapon Abilities

**Priority:** P1 after base combat is proven.

**User story:** As a player, obtaining a rare weapon can unlock a memorable signature ability so the reward changes how I play instead of only increasing a number.

### Rarity gameplay identity

| Rarity range | Intended identity |
| --- | --- |
| Common / Uncommon | Primarily stats |
| Rare | Small visual identity |
| Epic | Passive or enhanced attack |
| Legendary | Signature ability |
| Mythic | Signature ability with stronger presentation |
| Divine | Ability + passive + premium VFX |
| Celestial | Large-scale showcase ability |
| Secret | Highest-tier signature/ultimate presentation |

### Reusable ability archetypes

- Barrage.
- Dash slash.
- Ground slam.
- Projectile.
- Beam.
- Meteor.
- AOE burst.
- Lightning strike.
- Summon.
- Transformation.
- Spin attack.
- Uppercut.

Individual weapons configure timing, visuals, sounds, damage, hit behavior, and animation while the framework supplies reusable mechanics.

### First showcase ability

Build one original barrage-style ability as the framework proof:

```text
Wind-up
  -> character pose
  -> projected/spectral strikes appear
  -> rapid multi-hit sequence
  -> heavy final impact
  -> camera/audio/VFX payoff
```

The fantasy can be inspired by rapid anime-style attacks, but names, animation, visuals, models, audio, and effects must be original.

### Definition of done

- One Legendary/Mythic weapon has a complete signature ability.
- Ability includes animation, VFX, sound, cooldown, server-validated hits/damage, enemy reactions, desktop input, and mobile input.
- Framework can drive a second visual variant without duplicating the entire ability implementation.
- The reward is visually and mechanically desirable enough to justify hunting the weapon.

---

## Story 6 — Enemies + Combat Targets

**Priority:** P1, developed alongside Story 4/5 validation.

**User story:** As a player, every region contains readable enemies appropriate to my progression so the weapons I obtain have a meaningful use.

### Initial enemy classes

- **Normal:** frequent target for basic combat and progression.
- **Elite:** stronger enemy with better reward pressure and clearer telegraphing.
- **Region Boss:** milestone encounter that tests the player's current weapon/combat progression.

### Enemy requirements

- Region and Power band.
- Max health.
- Damage.
- Movement/aggro behavior.
- Attack cadence.
- Reward configuration.
- Hit reactions.
- Death feedback.
- Server-owned combat state.
- Reset/respawn behavior.

Normal enemies should remain simple. Bosses may introduce a few readable attacks, movement checks, and larger telegraphs without turning progression into a high-complexity combat game.

Bosses should supplement the chest loop rather than replace it. Potential rewards include Gold, temporary Luck, cosmetics/titles, and rare boss-specific chest access.

### Definition of done

- At least one normal enemy and one boss can be fought using Story 4 combat.
- Enemy tuning clearly differs across two regions.
- Weapon upgrades produce a noticeable combat advantage.
- Boss attacks are readable on mobile-sized screens.
- Rewards feed back into the Gold/chest/progression loop.

---

## Story 7 — Vertical Slice Integration / Does the Game Actually Work Together?

**Priority:** P0 release gate for expanding content.

**User story:** As a new player, I can experience the entire intended progression loop from first join through a new region, better weapon, meaningful combat, and first Rebirth without encountering contradictory systems or confusing UI.

This is the proof that Stories 1–6 form a game rather than separate features.

### Vertical slice content

- Two polished-enough regions plus one visible locked future region.
- One chest per playable region.
- Roughly 6–8 weapons per playable region.
- At least two weapon families.
- One Legendary/Mythic signature ability.
- Normal enemies in each region.
- One region boss.
- Inventory + Equip Best.
- Power, Gold, Luck, and Rebirth.
- Saving/loading.
- Region unlock and fast travel.
- One contextual onboarding path.
- Minimal settings for effects, motion, audio, and mobile usability.

### Required end-to-end journey

```text
Join
  -> understand how to gain Power
  -> earn first Gold
  -> open first chest
  -> equip better weapon
  -> notice faster progression
  -> fight enemies with that weapon
  -> reach next-region requirement
  -> unlock Region 2
  -> open stronger Region 2 chest
  -> obtain/see an aspirational rare ability weapon
  -> defeat region boss
  -> reach Rebirth requirement
  -> Rebirth
  -> immediately feel the permanent Power/Gold/Luck acceleration
```

### UX acceptance criteria

- New player can identify the next action without external explanation.
- No required screen is overloaded with unrelated buttons.
- The HUD remains visually quiet during world traversal/combat.
- Inventory is dense and scannable rather than oversized card spam.
- Chest odds, cost, current Luck, and reward strength are understandable.
- Rebirth clearly states what resets and what permanently improves.
- Keyboard, controller, and touch users can complete the vertical slice.

### Fun acceptance criteria

Before producing many regions, weapons, or expensive VFX/models, the slice must answer yes to:

1. Does opening a chest feel exciting?
2. Does equipping a better weapon create an immediately noticeable improvement?
3. Is using the weapon fun even when the next chest roll is several minutes away?
4. Does reaching a new region feel like entering a better place rather than unlocking a reskin?
5. Does a rare ability create genuine aspiration?
6. Does Rebirth make the next run materially faster and more rewarding?
7. Can a first-time player understand all of this with minimal reading?

If the answer to a core question is no, fix the loop before multiplying content.

---

## Later retention stories — hold until the vertical slice is fun

These are intentionally not prerequisites for the first integrated build:

- Random server/world events such as Luck Storms, fallen treasure, and temporary chest modifiers.
- Weapon Index / regional collection completion.
- Daily and weekly goals.
- Rebirth milestone rewards and a deeper Ascension tree.
- Roaming rare chests or treasure creatures.
- Titles, achievements, cosmetics, and leaderboards.
- Additional boss encounters.
- Trading only after economy abuse/security implications are understood.

The rule for future features is simple: they should create a new decision, goal, social moment, or memorable event. They should not exist only to add another button or currency.

## Implementation order

1. **Story 1 — Core Game Logistics / Systems Foundation**
2. **Story 2 — Regions / World Progression**
3. **Story 3 — Treasure Chests + Weapons**
4. **Story 4 — Weapon Combat + Animation Framework**
5. **Story 6 — Enemies + Combat Targets**
6. **Story 5 — Rare Weapon Abilities**
7. **Story 7 — Vertical Slice Integration**

Story numbering preserves the product discussion order; implementation puts enemies before the showcase ability so the ability has a real target and validation environment.

Do not expand to a large content catalog until Story 7 passes the UX and fun acceptance criteria.
