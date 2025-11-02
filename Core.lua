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
        objectiveTrackerBG = false,
        objectiveTrackerAlpha = 0.7,
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
    
    print("|cff00ff00Garage UI Tweaks|r loaded! Type |cffffffff/guit|r to open settings.")
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
SLASH_GUIT1 = "/guit"
SLASH_GUIT2 = "/garageui"
SlashCmdList["GUIT"] = function(msg)
    addon:OpenSettings()
end

-- Global reference
_G.GarageUITweaks = addon