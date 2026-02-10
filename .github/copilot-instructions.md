# Garage UI Tweaks - World of Warcraft Addon

## Architecture Overview

This is a World of Warcraft addon built using Lua and WoW's addon API. The addon provides quality-of-life UI tweaks including error text backgrounds, battleground map scaling, speed panels, and personal resource display customization.

**Core Components:**
- [`Core.lua`](../Core.lua): Main initialization, event handling, addon namespace setup
- [`Settings.lua`](../Settings.lua): Complex tabbed settings panel (1000+ lines) using WoW's Interface Options API
- [`Utils.lua`](../Utils.lua): Shared utilities for printing, CVars, frame positioning, and backdrops
- Feature modules: [`ErrorTextBackground.lua`](../ErrorTextBackground.lua), [`BattlegroundMap.lua`](../BattlegroundMap.lua), [`SpeedPanel.lua`](../SpeedPanel.lua), [`PersonalResourceDisplay.lua`](../PersonalResourceDisplay.lua), etc.

**Load Order:** Defined in [`garage_UI_tweaks.toc`](../garage_UI_tweaks.toc) - Core.lua loads first, then Utils, then feature modules, finally Settings.lua

## WoW Addon Conventions

**SavedVariables Pattern:**
- Global state persists in `GarageUITweaksDB` table (declared in .toc)
- Access via `addon.db` reference set during initialization
- Apply defaults for missing keys but preserve user settings on reload
- Use simple table structure, not nested profiles (see [`Core.lua:14-60`](../Core.lua#L14-L60))

**Event-Driven Architecture:**
```lua
-- Standard pattern: Register events on a frame, handle in OnEvent
GUITweaks:RegisterEvent("ADDON_LOADED")
GUITweaks:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        addon:OnInitialize()
    end
end)
```

**Namespace Pattern:**
- Every file starts with `local addonName, addon = ...`
- This provides access to shared addon namespace
- Store shared data in addon table (e.g., `addon.frame`, `addon.db`)
- Suppress lint warnings: `---@diagnostic disable: undefined-global` at top of files

## Critical Workflows

**Testing Changes:**
1. Save modified .lua files
2. In-game: `/reload` to reload UI
3. Access settings: `/guit` or `/guitweaks`
4. Check for Lua errors: Red error box or `/console scriptErrors 1`

**CVar Management:**
- Use `addon:SetCVar(cvar, value)` from Utils.lua (checks if value changed first)
- Common CVars: `nameplateShowSelf`, `nameplatePersonalShowInCombat`
- See [`PersonalResourceDisplay.lua:12-77`](../PersonalResourceDisplay.lua#L12-L77) for visibility control pattern

**Adding New Settings:**
1. Add default value to `defaults.profile` in [`Core.lua`](../Core.lua#L14-L60)
2. Create UI controls in appropriate tab section in [`Settings.lua`](../Settings.lua)
3. Use standard WoW templates: `InterfaceOptionsCheckButtonTemplate`, `InterfaceOptionsSliderTemplate`
4. Link checkbox/slider to `addon.db.yourSettingKey`

## Project-Specific Patterns

**Frame Positioning with Dragging:**
```lua
-- Standard pattern for moveable frames (see SpeedPanel.lua)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    addon:SaveFramePosition(self, "speedPanelPosition")
end)
```

**LibSharedMedia-3.0 Integration:**
- Optional dependency for custom fonts/textures (see Settings.lua)
- Always check if LSM exists: `local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)`
- Fallback to default WoW fonts if LSM not available

**Backdrop Pattern (Dragonflight+):**
```lua
-- Modern WoW requires BackdropTemplateMixin
if not frame.SetBackdrop then
    Mixin(frame, BackdropTemplateMixin)
end
frame:SetBackdrop({...})
```

**Personal Resource Display (PRD) Customization:**
- Hooks into Blizzard's nameplate system via `C_NamePlate.GetNamePlates()`
- Must handle both `NamePlateDriverFrame` and individual nameplate frames
- Texture application requires recursive search: `UnitFrame.healthBar`, `healthBars.healthBar`, `HealthBarsContainer.healthBar`
- See [`PersonalResourceDisplay.lua:99-134`](../PersonalResourceDisplay.lua#L99-L134) for texture application recursion

## Common WoW API Patterns

**Timer API:**
```lua
C_Timer.After(delaySeconds, function() ... end)  -- One-shot timer
C_Timer.NewTicker(interval, function() ... end)  -- Repeating ticker
```

**Unit API:**
- `UnitExists("player")`, `UnitExists("target")`
- `UnitAffectingCombat("player")` - check combat status
- `UnitCanAttack("player", "target")` - check if target is enemy

**Color Tables:**
```lua
{r=1.0, g=0.5, b=0.0, a=0.8}  -- Standard format for all color settings
```

## Debugging Tips

- Enable debug output: Check if `addon.db.debug` exists before printing
- Print helper: `addon:Print(msg)` adds green `[GarageT]` prefix
- Common issues: Frame not updating → check if events are registered, CVars reverting → check if other addons conflict
- PersonalResourceDisplay issues often caused by WoW API changes to nameplate structure paths
