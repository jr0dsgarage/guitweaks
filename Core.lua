---@diagnostic disable: undefined-global
-- Garage UI Tweaks Core
local addonName, addon = ...

-- Create the main addon frame
local GUITweaks = CreateFrame("Frame", "GarageUITweaks", UIParent)
addon.frame = GUITweaks

-- Addon namespace
addon.L = addon.L or {}
addon.db = addon.db or {}

-- Default settings
local defaults = {
    profile = {
        enabled = true,
        errorTextBackgroundEnabled = false,
        errorTextBackgroundAlpha = 0.7,
        errorTextBackgroundDuration = 3.0,
        battlegroundMapScale = 1.0,
        speedPanelEnabled = false,
        speedPanelLocked = false,
    }
}

-- Initialize the addon
function addon:OnInitialize()
    -- Initialize saved variables
    if not GarageUITweaksDB then
        GarageUITweaksDB = {}
    end
    
    -- Set up database
    self.db = GarageUITweaksDB
    
    -- Apply defaults
    for key, value in pairs(defaults.profile) do
        if self.db[key] == nil then
            self.db[key] = value
        end
    end
    
    -- Apply tweaks
    self:ApplyTweaks()
    
    -- Delayed reapply for frames that load late
    C_Timer.After(1, function()
        if addon.db and addon.db.battlegroundMapScale then
            addon:SetBattlegroundMapScale(addon.db.battlegroundMapScale)
        end
    end)
    
    print("|cff00ff00Garage UI Tweaks|r loaded! Type |cffffffff/guit|r or |cffffffff/guitweaks|r to open settings.")
end

-- Event handling
GUITweaks:RegisterEvent("ADDON_LOADED")
GUITweaks:RegisterEvent("PLAYER_LOGIN")

GUITweaks:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == addonName then
            addon:OnInitialize()
        end
    end
end)

-- Slash command registration
local function SanitizeCommand(msg)
    msg = tostring(msg or "")
    msg = msg:gsub("^%s+", ""):gsub("%s+$", "")
    return msg
end

local function PrintHelp()
    print("|cff00ff00Garage UI Tweaks|r commands:")
    print("  |cffffffff/guit|r or |cffffffff/guitweaks|r - open settings")
    print("  |cffffffff/guit config|r - open settings")
end

SLASH_GUIT1 = "/guit"
SLASH_GUIT2 = "/guitweaks"
SLASH_GUIT3 = "/garageui"

SlashCmdList["GUIT"] = function(msg)
    msg = SanitizeCommand(msg):lower()

    if msg == "" or msg == "config" or msg == "options" or msg == "settings" then
        addon:OpenSettings()
        if msg == "" then
            PrintHelp()
        end
        return
    end

    PrintHelp()
end

-- Global reference
_G.GarageUITweaks = addon