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
        overrideActionBarYOffset = 0,
        battlegroundMapScale = 1.0,
        battlegroundMapForceLowestStrata = false,
        experienceBarsForceHighestStrata = false,
        centerPartyFramesEnabled = false,
        centerRaidFramesEnabled = false,
        centerFramesDebug = false,
        topCenterWidgetOffset = 0,
        speedPanelEnabled = false,
        speedPanelLocked = false,
        speedPanelDebug = false,
        speedPanelFontKey = "GameFontHighlightLarge",
        speedPanelBackgroundKey = "dialog",
        speedPanelBorderKey = "tooltip",
        prdTextureHealth = "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill",
        prdBackgroundHealth = "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill",
        prdBackgroundHealthColor = {r=0, g=0, b=0, a=0.5},
        prdMatchHealth = false,
        prdTexturePower = "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill",
        prdBackgroundPower = "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill",
        prdBackgroundPowerColor = {r=0, g=0, b=0, a=0.5},
        prdMatchPower = false,
        prdTextureAlternate = "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill",
        prdBackgroundAlternate = "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill",
        prdBackgroundAlternateColor = {r=0, g=0, b=0, a=0.5},
        prdMatchAlternate = false,
        chatEditBoxUnlock = false,
        chatEditBoxPosition = nil,
        chatEditBoxWidth = 450,
        chatEditBoxAnchor = "CENTER",
        chatEditBoxHideBorder = false,
        hideChatButtonFrameBackground = false,
        hideChatFrameMenuButton = false,
        hideChatFrameChannelButton = false,
        hideQuickJoinToastButton = false,
        prdShowWithTargetEnemy = false,
        prdShowWithTargetFriendly = false,
        backgroundPanelEnabled = false,
        backgroundPanelLocked = false,
        backgroundPanelColor = {r=0, g=0, b=0, a=0.5},
        backgroundPanelWidth = 400,
        backgroundPanelHeight = 100,
        backgroundPanelForceWidth = false,
        backgroundPanelAnchor = "CENTER",
        backgroundPanelX = 0,
        backgroundPanelY = 0,
        nameplateSimplifiedScale = 1.0,
        nameplateUseClassColorForFriendlyPlayerUnitNames = false,
        nameplateFriendlyNamesEnabled = true,
        nameplateFriendlyNameFont = "Fonts\\FRIZQT__.TTF",
        nameplateFriendlyNameSize = 13,
        nameplateFriendlyNameOutline = "OUTLINE",
        nameplateFriendlyNameColor = {r=1, g=1, b=1, a=1},
        nameplateFriendlyNameOffsetX = 0,
        nameplateFriendlyNameOffsetY = 10,
        nameplateFriendlyNameJustify = "CENTER",
        encounterBarPreyPercentEnabled = false,
        professionRecipeQualityColorEnabled = true,
        rememberCraftingOrderFilters = true,
        craftingOrderFilters = {},
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
    print("  |cffffffff/guit speeddebug [on|off]|r - toggle speed panel debug output")
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

    if msg:sub(1, 10) == "speeddebug" then
        local value = msg:match("speeddebug%s+(%S+)")
        if value == "on" then
            addon.db.speedPanelDebug = true
            print("|cff00ff00GUIT:|r Speed panel debug enabled.")
        elseif value == "off" then
            addon.db.speedPanelDebug = false
            print("|cff00ff00GUIT:|r Speed panel debug disabled.")
        else
            print("|cffff0000GUIT:|r Usage: /guit speeddebug on|off")
        end
        return
    end

    PrintHelp()
end

-- Global reference
_G.GarageUITweaks = addon