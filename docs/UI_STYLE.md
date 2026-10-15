# UI style — current direction, October 14, 2026

The current UI uses a subdued charcoal, slate and plum palette, muted gold accents,
and thinner borders. Rarity colors remain distinct so players can recognize valuable
weapons at a glance without making every menu element equally bright.

The main menu is a centered, capped-size modal with an inset content area. Five
navigation options (Inventory, Chest, Regions, Rebirth, Settings) are stacked
vertically in a dedicated dark left sidebar, with icons and a clear selected state.
The right side contains the current page title and a padded, scrollable content area.
Spacing between content sections is 15 pixels. The modal and sidebar adapt to
compact and portrait viewports, and the Inventory rearranges its weapon details
and collection into a vertical layout on narrow screens. The persistent HUD and
quick-action controls remain accessible while the modal is closed.

The theme, components, and layout are defined in
`src/client/UI/Theme.luau`, `src/client/UI/Components.luau`, and
`src/client/Controllers/UIController.luau`. The latest Rojo build succeeded and
`git diff --check` passed. The October 15 Studio session synchronized the latest
controller and exercised all five menu pages with real desktop mouse input.
The [current agent handoff](AGENT_HANDOFF_2026-10-15.md) links those captures and
records the remaining populated-inventory and mobile checks. The captures below
document the older colorful UI only.

## Earlier colorful prototype — September 30, 2026

The user's supplied Roblox screenshot is the current styling reference. Its bright colors, thick dark outlines, rounded square icon buttons and prominent progress indicators replace the earlier muted HUD treatment. The fantasy-world identity and inventory/readability goals remain.

## Implemented presentation

- Always-visible menu: Inventory, Chest, Regions, Rebirth, Settings and Equip Best. Original backpack, chest, map, rebirth, gear and sword drawings use scalable Roblox GUI shapes, with no borrowed icons or external image assets.
- Fredoka display lettering, white/yellow text and dark outlines; orange training, purple chest actions and distinct menu colors.
- Gold, Luck and Rebirth counters at the left; current region and one next goal at the top.
- Large Power total and a live bar showing Power against the next locked region's requirement, or the Rebirth requirement once all regions are unlocked. This uses actual progression data; it does not introduce a separate XP/level system.
- Bright modal tabs, rarity-tinted weapon cards with ownership/equipped states, region progress, Rebirth information and existing settings.
- Desktop and portrait use a two-column icon menu. Short landscape screens use three columns and two rows to leave room for Roblox's movement control. Action controls stay between movement and jump controls, and portrait actions sit above them.

Menu tiles and modal tabs have at least 44-pixel targets in the supported layouts. Keyboard M still opens/closes Inventory. Existing remote actions and server validation remain the gameplay contract. This styling pass does not add trades, paid boosts, auto-training, or new rewards.

## Verification and limits

The four changed client modules compile with the Luau CLI, and the Rojo place builds successfully. Studio Play renders the HUD and Inventory. A temporary client preview rendered the production screen builders at logical 960 × 620 desktop and 393 × 690 portrait sizes, scaled to fit the current Studio viewport. This is layout inspection, not physical-device touch testing.

The live short landscape view was checked against Roblox's visible movement/jump controls; an initial overlap was corrected by moving to a three-column icon grid. Automated pointer/controller input was unreliable in this phone preview, so complete mouse, touch and controller activation remain acceptance checks. Screens inspected through the temporary preview are not evidence that their tabs were activated by physical input.

A temporary normal server Script exercised the validated training/chest gateway while the player was near the chest. Power increased from 0 to 1, Gold changed from 100 to 77 after training and the 25-Gold purchase, and Galevine Spear appeared in the inventory with `EQUIPPED`, rarity `1/12` and `x1.55 Power`. The live reward event displayed the styled reveal. [Replication evidence](playtest/2026-09-30/colorful-ui/reward-replication.json), [reward capture](playtest/2026-09-30/colorful-ui/reward.jpg). This verifies data-to-UI rendering, not a click on the Train or Chest button.

The preview and smoke drivers exist only in the temporary Play session; no test navigation hooks, reward grants or preview viewport overrides are part of the shipped modules. Studio mock data is temporary, and this pass does not validate cloud persistence.

The final fresh Play session had one enabled HUD, six quick-menu buttons, 44-pixel modal tabs, a Ready player and no temporary preview. M opened Inventory and closed it again. Console output contained only the expected Studio API/mock-save warning. [Final session evidence](playtest/2026-09-30/colorful-ui/final-play.json).

## Captures

- [Live HUD](playtest/2026-09-30/colorful-ui/hud.jpg)
- [Desktop inventory](playtest/2026-09-30/colorful-ui/desktop-inventory.jpg)
- [Desktop chest](playtest/2026-09-30/colorful-ui/desktop-chest.jpg)
- [Desktop regions](playtest/2026-09-30/colorful-ui/desktop-regions.jpg)
- [Desktop Rebirth](playtest/2026-09-30/colorful-ui/desktop-rebirth.jpg)
- [Desktop settings](playtest/2026-09-30/colorful-ui/desktop-settings.jpg)
- [Portrait inventory](playtest/2026-09-30/colorful-ui/portrait-inventory.jpg)
- [Portrait regions](playtest/2026-09-30/colorful-ui/portrait-regions.jpg)
- [Portrait settings](playtest/2026-09-30/colorful-ui/portrait-settings.jpg)
