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
        objectiveTrackerBG = false,
        objectiveTrackerAlpha = 0.7,
        debugBackground = false,
        debugPanelVisible = false,
        battlegroundMapScale = 1.0,
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
    
    -- Restore debug panel visibility if it was open
    if self.db.debugPanelVisible then
        self:OpenDebugPanel()
    end
    
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
    print("  |cffffffff/guit debug|r - open debug panel")
    print("  |cffffffff/guit debugbg|r - toggle background debug logging")
    print("  |cffffffff/guit dump|r - print UIErrorsFrame debug snapshot")
    print("  |cffffffff/guit dumpbg|r - print UIErrorsFrame debug snapshot")
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

    if msg == "debug" then
        addon:OpenDebugPanel()
        return
    end

    if msg == "debugbg" then
        addon.db.debugBackground = not addon.db.debugBackground
        addon:ResetBackgroundDebugLog()
        print(string.format("|cff00ff00Garage UI Tweaks|r background debug %s", addon.db.debugBackground and "enabled" or "disabled"))
        if addon.db.objectiveTrackerBG then
            addon:ApplyTweaks()
        end
        return
    end

    if msg == "dump" or msg == "dumpbg" then
        addon:DumpBackgroundDebug()
        return
    end

    PrintHelp()
end

local function EnsureDebugFrame()
    if addon.debugFrame then
        return addon.debugFrame
    end

    local frame = CreateFrame("Frame", "GarageUITweaksDebugFrame", UIParent, "BackdropTemplate")
    frame:SetSize(620, 320)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if addon.db then
            local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint()
            addon.db.debugFramePosition = { point, relativeTo and relativeTo:GetName(), relativePoint, xOfs, yOfs }
        end
    end)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 16, -12)
    title:SetText("Garage UI Tweaks Debug")

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -6, -6)
    closeButton:SetScript("OnClick", function()
        addon.db.debugPanelVisible = false
        frame:Hide()
    end)

    local configButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    configButton:SetSize(80, 22)
    configButton:SetPoint("TOPRIGHT", -226, -12)
    configButton:SetText("Config")
    configButton:SetScript("OnClick", function()
        addon:OpenSettings()
    end)

    local reloadButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    reloadButton:SetSize(80, 22)
    reloadButton:SetPoint("TOPRIGHT", -138, -12)
    reloadButton:SetText("Reload")
    reloadButton:SetScript("OnClick", ReloadUI)

    local dumpButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    dumpButton:SetSize(80, 22)
    dumpButton:SetPoint("TOPRIGHT", -50, -12)
    dumpButton:SetText("Dump")

    local scroll = CreateFrame("ScrollFrame", "GarageUITweaksDebugScroll", frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", title, "BOTTOMLEFT", -4, -10)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, 32)

    local editBox = CreateFrame("EditBox", nil, scroll)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject("GameFontHighlightSmall")
    editBox:SetWidth(560)
    editBox:SetHeight(400)
    editBox:SetMaxLetters(0)
    editBox:EnableMouse(true)
    editBox:SetScript("OnEscapePressed", editBox.ClearFocus)
    editBox:SetScript("OnEnterPressed", editBox.ClearFocus)
    editBox:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
    end)
    editBox:SetScript("OnEditFocusLost", function(self)
        self:HighlightText(0, 0)
    end)
    scroll:SetScrollChild(editBox)

    dumpButton:SetScript("OnClick", function()
        addon:RefreshDebugDump()
    end)

    frame:SetScript("OnShow", function()
        addon:RefreshDebugDump()
    end)

    local resizeHandle = CreateFrame("Frame", nil, frame)
    resizeHandle:SetSize(16, 16)
    resizeHandle:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 6)

    local handleTexture = resizeHandle:CreateTexture(nil, "OVERLAY")
    handleTexture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    handleTexture:SetAllPoints(resizeHandle)

    resizeHandle:EnableMouse(true)
    resizeHandle:SetScript("OnMouseDown", function()
        frame:StartSizing("BOTTOMRIGHT")
    end)
    resizeHandle:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        addon:UpdateDebugFrameLayout()
    end)
    resizeHandle:SetScript("OnEnter", function()
        handleTexture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    end)
    resizeHandle:SetScript("OnLeave", function()
        handleTexture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    end)

    if frame.SetResizeBounds then
        frame:SetResizeBounds(420, 260, 900, 700)
    else
        if frame.SetMinResize then
            frame:SetMinResize(420, 260)
        end
        if frame.SetMaxResize then
            frame:SetMaxResize(900, 700)
        end
    end

    frame:SetScript("OnSizeChanged", function()
        addon:UpdateDebugFrameLayout()
    end)

    frame.editBox = editBox
    frame.scroll = scroll
    frame.resizeHandle = resizeHandle
    addon.debugFrame = frame
    return frame
end

function addon:RefreshDebugDump()
    local frame = EnsureDebugFrame()
    if not frame then
        return
    end

    local text = self:DumpBackgroundDebug(true)
    if not text or text == "" then
        text = "[GUIT BG] No debug data available"
    end

    frame.editBox:SetText(text)
    frame.editBox:SetCursorPosition(0)
    self:UpdateDebugFrameLayout()
end

function addon:OpenDebugPanel()
    local frame = EnsureDebugFrame()
    addon.db.debugPanelVisible = true
    frame:Show()

    if self.db and self.db.debugFramePosition and self.db.debugFramePosition[1] then
        frame:ClearAllPoints()
        local relative = self.db.debugFramePosition[2] and _G[self.db.debugFramePosition[2]] or UIParent
        frame:SetPoint(self.db.debugFramePosition[1], relative, self.db.debugFramePosition[3], self.db.debugFramePosition[4], self.db.debugFramePosition[5])
    else
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    self:RefreshDebugDump()
end

function addon:UpdateDebugFrameLayout()
    if not self.debugFrame then
        return
    end

    local frame = self.debugFrame
    local scroll = frame.scroll
    local editBox = frame.editBox
    if not scroll or not editBox then
        return
    end

    local width = math.max(260, frame:GetWidth() - 60)
    local height = math.max(240, frame:GetHeight() - 110)

    editBox:SetWidth(width)
    editBox:SetHeight(height)
end

-- Global reference
_G.GarageUITweaks = addon