# Chest RPG — User Stories and Build Order

> Canonical backlog for the standalone Roblox Chest RPG. Stories describe acceptance targets; existing code is not proof that a story has passed. Iterate through the stages below and record validation before closing a story.

## Delivery stages and GitHub stories

| Stage | Stories | Playable checkpoint |
| --- | --- | --- |
| 1. Game logistics / systems | [#1 Foundation](https://github.com/kzheng18/roblox-chest-rpg/issues/1) | Join, train, earn, rebirth, save, and rejoin with consistent progression |
| 2. Regions | [#2 Regions](https://github.com/kzheng18/roblox-chest-rpg/issues/2) | Reach a Power gate, unlock it, travel, and see the next goal |
| 3. Weapons | [#3 Chests and weapons](https://github.com/kzheng18/roblox-chest-rpg/issues/3) | Open a regional chest, compare, equip, and feel faster progression |
| 4. Combat and animations | [#4 Combat](https://github.com/kzheng18/roblox-chest-rpg/issues/4), [#6 Enemies](https://github.com/kzheng18/roblox-chest-rpg/issues/6), [#5 Signature ability](https://github.com/kzheng18/roblox-chest-rpg/issues/5) | Use an original weapon moveset and one original barrage against real targets |
| 5. Everything together | [#7 Integration](https://github.com/kzheng18/roblox-chest-rpg/issues/7) | Complete the new-player loop through Region 2 and Rebirth |

Each checkpoint gets a playable review before expanding the next stage. Start with original placeholder art; invest in finished models, icons, animation, and effects after their interactions work. Build reusable UI components from Stage 1 so readability is tested throughout.

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

### Presentation acceptance for every player-facing story

The percentages express the intended creative balance, not a measurable asset quota or a claim about those games' exact interfaces.

- **Fantasy identity (60%):** original frames, restrained material textures, coherent typography, and world-themed accents. Decoration must leave text and controls readable.
- **Inventory/readability (25%):** consistent slots, recognizable weapon silhouettes, concise stat comparisons, and explicit selected/equipped states. Rarity is labeled as well as colored.
- **Roblox RPG usability (15%):** clear back/close actions, touch-friendly controls, controller focus, and prompts appropriate to the active input device. Essential information cannot require hovering.
- Verify the HUD, region gate, chest panel, inventory, Rebirth panel, and combat controls on desktop and a phone-sized viewport. Test controller navigation on each interactive screen.
- Use shared panel, button, slot, tooltip, progress-bar, and number-format components. Provide loading, empty, insufficient-Gold, locked-region, and action-failed states where relevant.
- Reduced motion/effects must preserve attack telegraphs and loot-result readability. No finished-asset requirement should prevent early interaction testing.

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

**Depends on:** None. Complete this checkpoint before expanding regions or the weapon catalog.

**Security contract:** [Core systems, player identity, and data security](CORE_SYSTEMS_SECURITY.md) defines required authentication boundaries, profile invariants, save durability, transactions, privacy, and recovery. Its SEC-01 through SEC-07 substories and open code findings are part of Story 1's acceptance criteria, not optional polish.

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

### Foundation iterations

- **1A — Economy contract:** document the repeatable training action, base Power/Gold income, multiplier order, and the distinction between Power gain and combat damage. Use the current training loop as the prototype baseline; do not require an unbuilt enemy system to earn the first chest.
- **1B — Durable progression:** implement and verify profiles, valid defaults, failed-load handling, and save recovery. A failed load must not overwrite an existing profile with defaults. Label Studio mock sessions as temporary; verify actual persistence in a separate test environment.
- **1C — Rebirth contract:** explicitly list every reset and retained field, including Gold, region unlocks, owned weapons, and equipped weapon. Preserve the weapon collection per the current prototype direction; resolve how retained weapons affect the next run and show the exact outcome before confirmation. Rebirth bonuses must improve Power gain, Gold gain, and Luck without compounding accidentally on rejoin.
- **1D — Usable shell:** deliver shared UI components, the Power/Gold/Luck HUD, one Next Goal, and clear loading/error states. Review hierarchy and touch usability using original placeholder art.

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
- A player with no Gold and no chest weapon can always resume earning; progression cannot dead-end after Rebirth.
- Rebirth's displayed resets/rewards match the server result, and duplicate requests do not grant duplicate bonuses.
- Record save/rejoin, failed-load, and Rebirth validation evidence before closing Story 1. Infrastructure for later services is sufficient here; combat itself belongs to Story 4.
- Pass SEC-01 through SEC-07 in the linked security contract. A code review alone cannot satisfy the live session, failure, persistence, and recovery drills.

---

## Story 2 — Regions / World Progression

**Priority:** P0.

**Depends on:** Story 1. Test with simple original world geometry before commissioning region art.

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

**Depends on:** Stories 1–2. Complete the reward-to-equip loop before expanding rarity tiers or models.

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
- The cost debit and weapon grant form one authoritative transaction; duplicate requests must not spend or grant twice.
- Displayed current odds use the same Luck-adjusted distribution as the server roll. Clearly distinguish base odds and rounded current odds.
- Insufficient Gold, unavailable regions, full inventory if capped, and interrupted reveals have clear outcomes. Skipping or disconnecting during a reveal cannot lose an already-granted weapon.

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

**Depends on:** Story 3. Start with a target dummy; develop Story 6's normal enemy alongside combat before the signature ability.

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
- First prove one family from equip to impact, then add the second family to validate reuse.
- Original wind-up, contact, and recovery timing aligns with server hit windows. Respawning, unequipping, or opening menus cannot leave an attack running or a control stuck.

---

## Story 5 — Rare Weapon Abilities

**Priority:** P0 for one showcase ability in the integrated slice; additional archetypes are P1.

**Depends on:** Story 4 and Story 6's working combat targets.

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

These are future options. Build only the barrage archetype for the first slice.

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

**Priority:** P0 for normal enemies and one boss in the integrated slice; elites and extra bosses are P1.

**Depends on:** Story 2's regions and Story 4's basic combat. Deliver a normal enemy first, then a boss after the basic interaction works.

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

**Depends on:** Stories 1–6, delivered through the five stages above.

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

### Validation record

- Run the journey with a fresh profile and again after Rebirth; record time to first chest, first useful upgrade, Region 2, and first Rebirth. The first-minute reward is a playtest target, not an asserted result.
- Observe new players without coaching and record where they hesitate, misread stats, or cannot find the next action.
- Check the presentation acceptance requirements above across desktop, touch, and controller.
- Test combat and shared rewards with at least two players, including respawn and reconnect during a chest reveal.
- Use a separate test profile to verify real save/rejoin behavior; Studio mock results alone cannot pass persistence.
- Attach results and remaining problems to the GitHub story. Closing the integration story requires evidence that the full loop works, including the faster second run.
- Include the security contract's transaction, privacy, and save-failure acceptance checks. Verify that pending rewards and saved rewards are distinguished throughout the journey.

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
