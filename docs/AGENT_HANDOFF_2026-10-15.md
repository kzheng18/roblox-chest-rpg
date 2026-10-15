# Development handoff — October 15, 2026

This snapshot preserves the existing local game work on top of Claude's
`4f66b2f` design-document commit. GitHub synchronization is for agent
collaboration. The user has explicitly deferred public release.

## Included work

- Dark inventory/menu UI: charcoal/slate/plum panels, muted gold, a vertical
  sidebar, search/sort, weapon details, responsive stacking, canvas updates,
  and scroll restoration.
- Existing local player lifecycle, validated server requests, inventory
  ownership, autosave/recovery, chest receipt, and performance work.
- Existing local linear-region world assets, sword geometry, equip visuals,
  regression cases, verification tools, documentation, and historical captures.
- [Review of Claude's anime-power proposal](POWER_SCALING_REVIEW.md). Its proposed
  limits are suggestions; they have not been applied to gameplay.

## Checks rerun for this GitHub handoff

| Check | Result |
| --- | --- |
| `python3 tools/test_local.py /path/to/luau` | 88 passed, 0 failed |
| `python3 tools/test_data_service.py /path/to/luau` | 14 passed, 0 failed |
| `python3 tools/test_performance.py /path/to/luau` | 7 passed, 0 failed |
| Official Luau compiler over `src/**/*.luau` and `tests/**/*.luau` | 61 files compiled |
| `rojo build default.project.json -o /private/tmp/chest-github-handoff-20261015.rbxlx` | Passed |
| `python3 tools/audit_model_scripts.py` | Passed; 55 JSON-only model modules |
| `git diff --check` | Passed before documentation updates; rerun before commit |

Local suites use Roblox I/O doubles. They do not establish cloud durability,
engine physics correctness, mobile input, multiplayer rendering, or 240 FPS.

## Earlier private Studio session

The previous session synchronized `UIController` into Chest RNG place
`100580886282621` and verified source readback. Theme, Components, and Icons
already matched. It exercised Inventory, Chest, Regions, Rebirth, and Settings
with the real menu callbacks. The copied [navigation report](playtest/2026-10-15/dark-ui/report.json)
and captures are evidence from that session, not a new live test in this handoff.
The viewport changed during the session; use each inspection's recorded size.

- [Inventory](playtest/2026-10-15/dark-ui/page_inventory.jpg)
- [Chest](playtest/2026-10-15/dark-ui/page_chest.jpg)
- [Regions](playtest/2026-10-15/dark-ui/page_regions.jpg)
- [Rebirth](playtest/2026-10-15/dark-ui/page_rebirth.jpg)
- [Settings](playtest/2026-10-15/dark-ui/page_settings.jpg)

The inventory was empty. This session proves desktop rendering/navigation,
not populated-card scaling. Console output included Roblox CorePackages
FoundationProvider warnings; these have not been diagnosed as game errors.

## Remaining acceptance work

1. Import or use a base sword in a temporary private Studio test. No test sword
   was imported during the interrupted connection attempts.
2. Populate a temporary inventory sufficiently to test multiple rows, final-row
   reachability, resizing, search, sorting, details, and equip/equip-best flows.
   Preserve saved player inventories and remove temporary fixtures afterward.
3. Verify the current controller on phone portrait and landscape, including a
   viewport narrower than 360 pixels and a short landscape screen. Historical
   September mobile captures do not validate this dark UI revision.
4. Test physical touch/controller input and real persistence/concurrency before
   release. No live release is authorized by this handoff.

## Studio tooling caveat

The `sync_dark_ui_studio.py`, `verify_dark_ui_play.py`,
`verify_dark_ui_navigation.py`, and input-tool inspector rely on the local
`/private/tmp/chest_rng_studio_sync_20261014.py` MCP helper. It is machine-local
and is not bundled in this repository. These are current-machine tools, not
portable setup scripts. Other agents need an available Studio MCP connection.
The sync tool also guards against explicitly reviewed source digests: inspect
and reconcile the live sources before another sync; do not bypass its guard.

Use `rtk` before shell commands on this workstation, per its local instructions.
The official Luau executables used for these checks are in
`/private/tmp/chest-luau-0742/`; fresh machines need their own Luau installation.
