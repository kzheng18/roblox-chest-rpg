# Studio verification — September 29, 2026

The September 30 colorful UI pass replaces the appearance described below. See [current styling, layout previews and verification limits](UI_STYLE.md). The earlier interaction evidence remains historical coverage; it does not establish complete input testing for the new layout.

Verified in the active **Chest RNG** Studio place (`100580886282621`) using Play mode, the running client/server, real UI input, and viewport captures. The local build and active Studio scripts were synchronized before testing.

## Missing UI fix

The old Studio copy of `UIController` failed to parse at line 714, stopping `Client.Main` before it could create `ChestRPGUI`. The corrected source separates parenthesized cast assignments with semicolons. Synchronizing the active place removed that error; fresh Play sessions create one enabled `ChestRPGUI`.

## Desktop interaction results

| Flow | Evidence |
| --- | --- |
| HUD and menu | Power, Gold, Luck, objective, MENU, Train, and Open Chest render. MENU and M open/close the inventory. |
| Navigation | Inventory, Chest, Regions, Rebirth, and Settings open through their buttons; X closes the menu. |
| Training | Clicking Train increases authoritative Power and Gold. After equipping Galevine Spear, a click increased Power from 1 to 2.55. |
| Chest purchase | Clicking Open Chest deducted 25 Gold, displayed the reward reveal, and added a weapon to the inventory. Continue dismissed the reveal. |
| World prompt | Pressing E near the starting chest purchased a weapon: Gold changed from 102 to 77 and the Galevine Spear reveal appeared. |
| Equipment | Equip Best updated the server's equipped ID and the inventory's EQUIPPED marker. |
| Settings | The reveal-animation toggle changed the server setting; volume + changed 0.8 to 0.9, and - restored it. |
| Player control | A 1.2-second D input moved the character about 19 studs. Player spawning reported Ready. |
| Final console | No game script errors in the fresh final session. Only the expected ProfileStore/API-access warnings for temporary Studio data. |

## In-engine feature checks

`tests/StudioPlaytest.luau` passed **15/15** checks through a temporary normal server Script. The test restored the mock progression after temporarily supplying milestone values. Its [machine-readable result](playtest/2026-09-29/feature-results.json) records:

- Living Humanoid/root; training Power and Gold increases.
- Nearby purchase debit and weapon grant; owned equipment.
- Malformed request rejection; locked travel rejection; distant purchase rejection without debit.
- Region unlock/arrival and respawn selection; higher-region chest purchase.
- Rebirth reset/permanent count and return to the starting region.
- Valid settings update and non-finite value rejection.
- Death followed by a controllable respawn.

Run the test in a normal server Script during Studio Play, after the player spawns. Assistant/plugin execution can load a separate module cache, so directly requiring stateful services from that context does not inspect the running game's module state. No verification grants or harnesses were added to production scripts or remotes.

## Compact layout

iPhone 17 Pro simulation was visually checked in landscape and portrait. The game's orientation is `Sensor`; `ChestRPGUI` uses `CoreUISafeInsets`, does not ignore the GUI inset, and clips to the device safe area.

The layout fixes reduce the compact HUD height, wrap the objective, enlarge the Menu target to 44 pixels, contain all five footer tabs, separate the Train title from its gain caption, constrain notifications/reveals to the viewport, and position the action dock clear of movement/jump controls. Desktop HUD and Rebirth card spacing also stay inside their panels.

Physical-device touch remains an acceptance check. The simulator's automated mouse input did not reliably activate the intended buttons, so M was used to open the compact menu for visual inspection. This is visual mobile coverage, not a claim that touch interaction has passed.

Studio was reset to the default desktop viewport and left in Play mode with the HUD visible. The corrected local `ChestRPG.rbxlx` is also available for subsequent sessions. These checks used temporary Studio profiles; cloud saves, multiplayer concurrency, progression pacing, and combat/weapon models are outside this verification.

## Captures

- [Desktop HUD](playtest/2026-09-29/desktop-hud.jpg)
- [Desktop equipped inventory](playtest/2026-09-29/desktop-inventory.jpg)
- [World chest reward](playtest/2026-09-29/chest-reward.jpg)
- [Phone landscape HUD](playtest/2026-09-29/phone-landscape-hud.jpg)
- [Phone landscape inventory](playtest/2026-09-29/phone-landscape-inventory.jpg)
- [Phone portrait HUD](playtest/2026-09-29/phone-portrait-hud.jpg)
- [Phone portrait inventory](playtest/2026-09-29/phone-portrait-inventory.jpg)
