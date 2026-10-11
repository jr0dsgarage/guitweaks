---@diagnostic disable: undefined-global
-- Garage UI Tweaks - Client Compatibility
local addonName, addon = ...

addon.isRetail = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)

-- Features that aren't viable on every client. A feature with no entry here is
-- treated as supported everywhere. Test for the API the feature actually uses
-- where there is one; fall back to the client flag for features tied to a game system.
local features = {
    preyPercent = function() return addon.isRetail end,
    -- Forever exposes C_AssistedCombat but the highlight doesn't work there, so no API test
    armorSetHighlight = function() return addon.isRetail end,
    cooldownAtMouse = function() return C_Spell ~= nil and C_Spell.GetSpellCooldown ~= nil end,
    microMenuArt = function() return MicroMenu ~= nil and MicroMenu.BackgroundArt ~= nil end,
    chatButtonSide = function() return FCF_SetButtonSide ~= nil and FCF_UpdateButtonSide ~= nil end,
}

-- Checked on first use rather than at load, so Blizzard code that loads after us is counted
local supported = {}

function addon:IsFeatureSupported(id)
    local check = features[id]
    if not check then
        return true
    end

    if supported[id] == nil then
        supported[id] = check() and true or false
    end
    return supported[id]
end
