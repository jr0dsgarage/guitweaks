# Garage UI Tweaks - World of Warcraft Addon

## Architecture Overview

A World of Warcraft addon (Lua, WoW addon API) of independent quality-of-life UI tweaks. It loads on both Retail and WoW Forever.

**Files** (load order is [`guitweaks.toc`](../guitweaks.toc)):
- [`Core.lua`](../Core.lua): every saved setting and its default (`DEFAULTS`), database start-up, `ApplyTweaks`, slash commands
- [`Compat.lua`](../Compat.lua): features that only work on one client
- [`Utils.lua`](../Utils.lua): shared helpers (printing, saved frame positions, `NextFrameOnce`, `SetFontOrFallback`, `ResetSettings`)
- One file per tweak: `ErrorTextBackground`, `FrameTweaks` (small changes to Blizzard frames), `SpeedPanel`, `CooldownAtMouse`, `DamageNumbers`, `SelfCombatText`, `ChatTweaks`, `Nameplates`, `ArmorSetHighlight`, `RaidPartyFrames`, `BackgroundPanel`
- [`SettingsWidgets.lua`](../SettingsWidgets.lua): settings controls shared by every j__r0d's garage addon. Kept identical across them; edit one copy, then copy it to the others.
- [`Settings.lua`](../Settings.lua): the settings pages, one builder function per page

## Conventions

**One update function per tweak.** Each tweak has `addon:Update<Tweak>()`, which applies the saved settings and can run any number of times. `ApplyTweaks` in Core.lua calls them all at load. A settings control stores its value in `addon.db` and then calls its tweak's Update. Don't call `ApplyTweaks` from a control.

**Leave Blizzard alone until asked.** While a tweak is off and has never been on, it doesn't touch Blizzard's frames, hooks or CVars. When it's turned off again, it puts back only what it changed. Examples: `FrameTweaks.lua` captures a frame's own anchor or strata before the first change, and `ChatTweaks.lua` shows a button again only if it was showing when hidden. Register events only while a tweak is on.

**Settings and defaults.** Every setting has its default in `DEFAULTS` in Core.lua, and nowhere else: code reads `addon.db.key` without `or default` fallbacks. Reset buttons use `addon:ResetSettings({ keys })`. A setting earlier versions saved that nothing uses goes in `OBSOLETE`.

**State lives in locals.** Keep per-frame bookkeeping in file-local (weak-keyed where frames come and go) tables, not as fields on Blizzard's frames.

**Saved positions are measured from the screen's center** (`addon:AnchorToScreenCenter`, `SaveFramePosition`, `RestoreFramePosition`), so frames keep their place when the resolution changes.

**Client differences.** A tweak that only works on one client gets a predicate in Compat.lua's `features` table (test for the API it uses; use `addon.isRetail` only when there is no API to test). Its Update returns early when `addon:IsFeatureSupported("id")` is false, and its settings section passes the feature id as `CreateSection`'s last argument so it is left out of the page.

**Adding a setting:**
1. Add its default to `DEFAULTS` in Core.lua.
2. Add a control in the page's builder in Settings.lua: `CreateDBCheckbox`, `CreateDBSlider`, `CreateDBChoiceDropdown`, `CreateDBFontDropdown` or `CreateColorSwatch`, passing the tweak's Update as the apply function.
3. Read `addon.db.yourSetting` in the tweak's Update.

**Style:** every file starts with `---@diagnostic disable: undefined-global`, a `-- Garage UI Tweaks - <Name>` line and a comment on what the file does, then `local addonName, addon = ...`. Local functions are PascalCase. Comments say why, not what.

## Testing

1. Save the changed files.
2. In game: `/reload`.
3. `/guit` opens the settings; `/guit debug` lists the raid and party frames' positions.
4. Lua errors: `/console scriptErrors 1`.
