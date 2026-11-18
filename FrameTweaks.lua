---@diagnostic disable: undefined-global
-- Garage UI Tweaks - Frame Tweaks
-- Small scale, strata, position and art changes to Blizzard frames: the battleground map,
-- the experience bars, the top center widgets, the override action bar and the micro menu.
-- Each one leaves its frame alone until its setting first moves off the default, and puts
-- back what it changed when the setting returns to it.
local addonName, addon = ...

local function RegisterEvents(frame, events)
    for _, event in ipairs(events) do
        frame:RegisterEvent(event)
    end
end

-- ============================================================================
-- Battleground map (Shift+M)
-- ============================================================================
-- Blizzard_BattlefieldMap loads on demand, the first time the map is opened.

local mapStrata -- the map's own strata, while it is forced to the lowest

function addon:UpdateBattlegroundMap()
    local map = BattlefieldMapFrame
    if not map then
        return
    end

    map:SetScale(self.db.battlegroundMapScale)

    if self.db.battlegroundMapForceLowestStrata then
        mapStrata = mapStrata or map:GetFrameStrata()
        map:SetFrameStrata("BACKGROUND")
    elseif mapStrata then
        map:SetFrameStrata(mapStrata)
        mapStrata = nil
    end
end

local mapEvents = CreateFrame("Frame")
mapEvents:RegisterEvent("ADDON_LOADED")
mapEvents:RegisterEvent("PLAYER_ENTERING_BATTLEGROUND")
mapEvents:SetScript("OnEvent", function(_, event, loadedAddon)
    if not addon.db then
        return
    end
    if event == "PLAYER_ENTERING_BATTLEGROUND" then
        C_Timer.After(0.1, function() addon:UpdateBattlegroundMap() end)
    elseif loadedAddon == "Blizzard_BattlefieldMap" then
        addon:UpdateBattlegroundMap()
    end
end)

-- ============================================================================
-- Experience bars above everything
-- ============================================================================

-- Only the top-level containers; the bars inside follow them
local EXPERIENCE_BAR_FRAMES = { "MainStatusTrackingBarContainer", "StatusTrackingBarManager", "StatusTrackingBarContainer" }
local EXPERIENCE_BAR_EVENTS = {
    "PLAYER_ENTERING_WORLD", "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "UPDATE_FACTION", "HONOR_XP_UPDATE",
    "UPDATE_UI_WIDGET", "UPDATE_ALL_UI_WIDGETS", "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED",
}

local experienceBarStrata = {} -- [frame] = its own strata, while raised
local experienceBarEvents = CreateFrame("Frame")
local raiseAgainPending = false

local function RaiseExperienceBars()
    for _, name in ipairs(EXPERIENCE_BAR_FRAMES) do
        local frame = _G[name]
        if frame then
            experienceBarStrata[frame] = experienceBarStrata[frame] or frame:GetFrameStrata()
            frame:SetFrameStrata("TOOLTIP")
        end
    end
end

-- Blizzard can reset the strata while it updates the bars: raise them again right away,
-- and once more after the update settles
experienceBarEvents:SetScript("OnEvent", function()
    RaiseExperienceBars()
    if raiseAgainPending then
        return
    end
    raiseAgainPending = true
    C_Timer.After(0.1, function()
        raiseAgainPending = false
        if addon.db.experienceBarsForceHighestStrata then
            RaiseExperienceBars()
        end
    end)
end)

function addon:UpdateExperienceBarStrata()
    if self.db.experienceBarsForceHighestStrata then
        RaiseExperienceBars()
        RegisterEvents(experienceBarEvents, EXPERIENCE_BAR_EVENTS)
    else
        experienceBarEvents:UnregisterAllEvents()
        for frame, strata in pairs(experienceBarStrata) do
            frame:SetFrameStrata(strata)
        end
        wipe(experienceBarStrata)
    end
end

-- ============================================================================
-- Top center widgets (battleground scores, zone objectives)
-- ============================================================================

local TOP_CENTER_EVENTS = { "PLAYER_ENTERING_WORLD", "UPDATE_UI_WIDGET", "UPDATE_ALL_UI_WIDGETS", "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED" }

local topCenterAnchor -- UIWidgetTopCenterContainerFrame's own anchor, captured before it is first moved
local topCenterEvents = CreateFrame("Frame")

local function ApplyTopCenterWidgetOffset()
    local frame = UIWidgetTopCenterContainerFrame
    if not frame then
        return
    end

    if not topCenterAnchor then
        local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
        if not point then
            return
        end
        topCenterAnchor = { point = point, relativeTo = relativeTo, relativePoint = relativePoint or point, x = x or 0, y = y or 0 }
    end

    local anchor = topCenterAnchor
    frame:ClearAllPoints()
    frame:SetPoint(anchor.point, anchor.relativeTo, anchor.relativePoint, anchor.x, anchor.y - addon.db.topCenterWidgetOffset)
end

-- Blizzard re-anchors the frame as widgets come and go; put the offset back afterwards
topCenterEvents:SetScript("OnEvent", addon.NextFrameOnce(ApplyTopCenterWidgetOffset))

function addon:UpdateTopCenterWidgetOffset()
    if self.db.topCenterWidgetOffset ~= 0 then
        ApplyTopCenterWidgetOffset()
        RegisterEvents(topCenterEvents, TOP_CENTER_EVENTS)
    elseif topCenterAnchor then
        ApplyTopCenterWidgetOffset() -- back on its own anchor
        topCenterEvents:UnregisterAllEvents()
        topCenterAnchor = nil
    end
end

-- ============================================================================
-- Override action bar (vehicles and other override bars)
-- ============================================================================

local overrideBarMoved = false
local overrideBarEvents = CreateFrame("Frame") -- retries a move refused in combat

function addon:UpdateOverrideActionBar()
    local offset = self.db.overrideActionBarYOffset
    if not OverrideActionBar or (offset == 0 and not overrideBarMoved) then
        return
    end

    -- A protected frame: it can only be moved out of combat
    if InCombatLockdown() then
        overrideBarEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    overrideBarEvents:UnregisterEvent("PLAYER_REGEN_ENABLED")

    OverrideActionBar:ClearAllPoints()
    OverrideActionBar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, offset)
    overrideBarMoved = offset ~= 0
end

overrideBarEvents:SetScript("OnEvent", function() addon:UpdateOverrideActionBar() end)

-- ============================================================================
-- Micro menu art
-- ============================================================================
-- Faded rather than hidden, so it stays gone if Blizzard shows it again.

local microMenuFaded = false

function addon:UpdateMicroMenuArt()
    if not self:IsFeatureSupported("microMenuArt") then
        return
    end

    local hideBackground = self.db.hideMicroMenuBackgroundArt
    local hideBorder = self.db.hideMicroMenuBorderArt
    if not (hideBackground or hideBorder or microMenuFaded) then
        return
    end

    MicroMenu.BackgroundArt:SetAlpha(hideBackground and 0 or 1)
    if MicroMenu.BorderArt then
        MicroMenu.BorderArt:SetAlpha(hideBorder and 0 or 1)
    end
    microMenuFaded = hideBackground or hideBorder
end
