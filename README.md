# Roblox Chest RPG

A standalone Roblox progression RPG built around a simple loop:

`Power -> Gold -> regional treasure chests -> Luck-weighted weapons -> stronger progression -> new regions -> Rebirth`

This repository is intentionally separate from Aura Ascension. Aura Ascension is not a dependency and its game logic is not modified by this project.

## Current playable foundation

- Server-authoritative Power and Gold training.
- Persistent ProfileStore-backed player data with Studio mock saves.
- Three configured regions with Power gates and fast travel.
- One regional treasure chest per region.
- Server-side weapon rolls with Luck-adjusted reciprocal rarity display (`1/N`).
- Persistent weapon inventory and equip/equip-best flows.
- Rebirths that accelerate Power, Gold, and Luck while preserving weapon collection.
- Compact fantasy HUD/menu with large controls suitable for desktop and touch.
- Optional chest roll reveal animation that can be disabled in Settings.
- Placeholder generated world for fast Rojo/Studio iteration.

The product direction and staged build order live in [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md).

## Build

```bash
rojo build -o ChestRPG.rbxlx
```

Open the generated place in Roblox Studio for playtesting, or run `rojo serve` and connect with the Rojo Studio plugin.

