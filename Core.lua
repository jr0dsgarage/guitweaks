---@diagnostic disable: undefined-global
-- Garage UI Tweaks - Core
-- Saved settings, start-up and slash commands.
--
-- Each tweak lives in its own file and has an addon:Update<Tweak>() that applies the saved
-- settings. It can run any number of times, and while a tweak is off and has never been on
-- it leaves Blizzard's frames untouched. The settings panel stores a value and then calls
-- the matching Update; ApplyTweaks calls them all at load.
local addonName, addon = ...

_G.GarageUITweaks = addon

-- Every saved setting and its default. Settings with no entry here start out unset:
-- chatEditBoxPosition and speedPanelPosition (nothing saved yet) and speedPanelFont (the
-- game's font).
local DEFAULTS = {
    -- Error text background (ErrorTextBackground.lua)
    errorTextBackgroundEnabled = false,
    errorTextBackgroundAlpha = 0.7,
    errorTextBackgroundDuration = 3.0,

    -- Blizzard frame adjustments (FrameTweaks.lua)
    overrideActionBarYOffset = 0,
    hideMicroMenuBackgroundArt = false,
    hideMicroMenuBorderArt = false,
    battlegroundMapScale = 1.0,
    battlegroundMapForceLowestStrata = false,
    experienceBarsForceHighestStrata = false,
    topCenterWidgetOffset = 0,

    -- Raid and party frame centering (RaidPartyFrames.lua)
    centerPartyFramesEnabled = false,
    centerRaidFramesEnabled = false,
    centerFramesDebug = false,

    -- Action bars and encounter bar (ArmorSetHighlight.lua, PreyPercent.lua)
    armorSetActionHighlightEnabled = false,
    encounterBarPreyPercentEnabled = false,

    -- Speed panel (SpeedPanel.lua)
    speedPanelEnabled = false,
    speedPanelLocked = false,
    speedPanelFontSize = 16,
    speedPanelFontOutline = "NONE",
    speedPanelTextColor = { r = 1, g = 1, b = 1, a = 1 },
    speedPanelBackgroundColor = { r = 0, g = 0, b = 0, a = 0.55 },
    speedPanelBorderColor = { r = 0.4, g = 0.4, b = 0.4, a = 0.9 },
    speedPanelBackgroundKey = "dialog",
    speedPanelBorderKey = "tooltip",

    -- Cooldown timer at the mouse (CooldownAtMouse.lua)
    cooldownAtMouseEnabled = false,
    cooldownAtMouseDuration = 3.0,
    cooldownAtMouseOffset = 40,
    cooldownAtMouseAngle = 90,
    cooldownAtMouseFont = "Fonts\\FRIZQT__.TTF",
    cooldownAtMouseFontSize = 22,

    -- Your own scrolling combat text (SelfCombatText.lua)
    selfCombatTextOffsetX = 0,
    selfCombatTextOffsetY = 0,
    selfCombatTextTravel = 100,

    -- Chat (ChatTweaks.lua)
    chatEditBoxUnlock = false,
    chatEditBoxWidth = 450,
    chatEditBoxAnchor = "CENTER",
    chatEditBoxHideBorder = false,
    hideChatButtonFrameBackground = false,
    hideChatFrameMenuButton = false,
    hideChatFrameChannelButton = false,
    hideQuickJoinToastButton = false,
    chatButtonsOnRight = false,
    chatFonts = {}, -- [chat window id] = { font = file, size = number }
    extendDefaultChatPane = false,
    hideChatTabs = false,
    showChatTabsOnHover = false,

    -- Background panel (BackgroundPanel.lua)
    backgroundPanelEnabled = false,
    backgroundPanelLocked = false,
    backgroundPanelColor = { r = 0, g = 0, b = 0, a = 0.5 },
    backgroundPanelWidth = 400,
    backgroundPanelHeight = 100,
    backgroundPanelForceWidth = false,
    backgroundPanelForceHeight = false,
    backgroundPanelAnchor = "CENTER",
    backgroundPanelX = 0,
    backgroundPanelY = 0,

    -- Friendly nameplates (Nameplates.lua)
    nameplateFriendlyNamesEnabled = true,
    nameplateFriendlyNamesShowTitle = false,
    nameplateFriendlyNamesShowGuild = false,
    nameplateUseClassColorForFriendlyPlayerUnitNames = false,
    nameplateFullFriendlyInInstances = false,
    nameplateFriendlyScale = 1.0,
    nameplateFriendlyNameFont = "Fonts\\FRIZQT__.TTF",
    nameplateFriendlyNameSize = 13,
    nameplateFriendlyNameOutline = "OUTLINE",
    nameplateFriendlyNameColor = { r = 1, g = 1, b = 1, a = 1 },
    nameplateFriendlyNameOffsetX = 0,
    nameplateFriendlyNameOffsetY = 10,
    nameplateFriendlyNameJustify = "CENTER",
}
addon.defaults = DEFAULTS

-- Settings earlier versions saved that nothing uses any more
local OBSOLETE = {
    "enabled", -- the old "Enable Garage UI Tweaks" checkbox, which never did anything
    "chatPaneExtend",
}

local function InitDatabase()
    if type(GarageUITweaksDB) ~= "table" then
        GarageUITweaksDB = {}
    end
    local db = GarageUITweaksDB
    addon.db = db

    for key, value in pairs(DEFAULTS) do
        if db[key] == nil then
            db[key] = addon.DeepCopy(value)
        end
    end

    for _, key in ipairs(OBSOLETE) do
        db[key] = nil
    end

    -- Older versions could save these in lower case
    db.nameplateFriendlyNameOutline = db.nameplateFriendlyNameOutline:upper()
    db.nameplateFriendlyNameJustify = db.nameplateFriendlyNameJustify:upper()
end

local TWEAKS = {
    "UpdateErrorTextBackground",
    "UpdateBattlegroundMap",
    "UpdateExperienceBarStrata",
    "UpdateTopCenterWidgetOffset",
    "UpdateOverrideActionBar",
    "UpdateMicroMenuArt",
    "UpdateRaidPartyFrameCentering",
    "UpdateArmorSetHighlights",
    "UpdatePreyPercent",
    "UpdateSpeedPanel",
    "UpdateCooldownAtMouse",
    "UpdateSelfCombatText",
    "UpdateChatTweaks",
    "UpdateBackgroundPanel",
    "UpdateFriendlyClassColor", -- also draws the friendly names
}

function addon:ApplyTweaks()
    for _, method in ipairs(TWEAKS) do
        -- One tweak failing (after a game patch, say) still reports its error but doesn't stop the rest
        xpcall(function() self[method](self) end, geterrorhandler())
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, _, loadedAddon)
    if loadedAddon ~= addonName then
        return
    end
    self:UnregisterEvent("ADDON_LOADED")

    InitDatabase()
    addon:ApplyTweaks()
    addon:Print("loaded. Type |cffffffff/guit|r to open settings.")
end)

local function PrintHelp()
    addon:Print("commands:")
    print("  |cffffffff/guit|r - open settings")
    print("  |cffffffff/guit debug|r - list the raid and party frames' positions, for troubleshooting centering")
end

SLASH_GUIT1 = "/guit"
SLASH_GUIT2 = "/guitweaks"
SLASH_GUIT3 = "/garageui"
SlashCmdList["GUIT"] = function(msg)
    local command = strtrim(msg or ""):lower()
    if command == "" or command == "config" or command == "options" or command == "settings" then
        addon:OpenSettings()
    elseif command == "debug" then
        addon:DumpRaidPartyFrameDebug()
    else
        PrintHelp()
    end
end
