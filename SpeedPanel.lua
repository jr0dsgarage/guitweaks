---@diagnostic disable: undefined-global
-- Garage UI Tweaks - Speed Panel
-- A movable panel showing your movement speed, as a percentage of normal run speed and in
-- yards per second.
local addonName, addon = ...

local BASE_RUN_SPEED = 7 -- yards per second on foot with no bonuses; this is 100%
local UPDATE_INTERVAL = 0.05
local SAMPLE_INTERVAL = 0.25
local WIDEST_TEXT = "Speed: 9999% (999.9 yd/s)" -- sizes the panel, so it never resizes while you move
local DEFAULT_POSITION = { "CENTER", 0, -200 }
local UNLOCKED_BORDER_COLOR = { 0.8, 0.8, 0.2, 0.9 } -- yellow marks the panel as movable

local OUTLINE_OPTIONS = {
    { key = "NONE", name = "None", flags = "" },
    { key = "OUTLINE", name = "Outline", flags = "OUTLINE" },
    { key = "THICKOUTLINE", name = "Thick Outline", flags = "THICKOUTLINE" },
}

local BACKGROUND_OPTIONS = {
    { key = "dialog", name = "Dialog", texture = "Interface\\DialogFrame\\UI-DialogBox-Background" },
    { key = "tooltip", name = "Tooltip", texture = "Interface\\Tooltips\\UI-Tooltip-Background" },
    { key = "solid", name = "Solid", texture = "Interface\\Buttons\\WHITE8x8" },
    { key = "none", name = "None", texture = nil },
}

local BORDER_OPTIONS = {
    { key = "tooltip", name = "Tooltip", texture = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } },
    { key = "dialog", name = "Dialog", texture = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 24, insets = { left = 12, right = 12, top = 12, bottom = 12 } },
    { key = "thin", name = "Thin", texture = "Interface\\AchievementFrame\\UI-Achievement-StatsBorder", edgeSize = 8, insets = { left = 3, right = 3, top = 3, bottom = 3 } },
    { key = "none", name = "None", texture = nil, edgeSize = 0, insets = { left = 0, right = 0, top = 0, bottom = 0 } },
}

local function IndexByKey(options)
    local byKey = {}
    for _, option in ipairs(options) do
        byKey[option.key] = option
    end
    return byKey
end

local OUTLINES = IndexByKey(OUTLINE_OPTIONS)
local BACKGROUNDS = IndexByKey(BACKGROUND_OPTIONS)
local BORDERS = IndexByKey(BORDER_OPTIONS)

local panel -- created on first use
local sample = {} -- the last position sampled, for GetSampledSpeed
local shownPercent, shownYards
local sinceUpdate = 0

-- For the settings panel's dropdowns: lists of { key, name }
function addon:GetSpeedPanelOutlineOptions()
    return OUTLINE_OPTIONS
end

function addon:GetSpeedPanelBackgroundOptions()
    return BACKGROUND_OPTIONS
end

function addon:GetSpeedPanelBorderOptions()
    return BORDER_OPTIONS
end

-- ============================================================================
-- Measuring speed
-- ============================================================================

-- Speed from how far you've moved since the last sample, for when GetUnitSpeed reports
-- nothing (some flying and vehicle cases). Nil inside instances, where positions are hidden.
local function GetSampledSpeed()
    local x, y, z, instanceID = UnitPosition("player")
    local now = GetTime()
    if not x or not y then
        return nil
    end

    if sample.instance and sample.instance ~= instanceID then
        sample = { x = x, y = y, z = z, instance = instanceID, time = now }
        return nil
    end

    local due = sample.time and sample.time < now and (not sample.computedAt or now - sample.computedAt >= SAMPLE_INTERVAL)
    if due then
        local dx, dy, dz = x - sample.x, y - sample.y, (z and sample.z) and (z - sample.z) or 0
        sample.speed = math.sqrt(dx * dx + dy * dy + dz * dz) / (now - sample.time)
        sample.computedAt = now
    end

    sample.x, sample.y, sample.z, sample.instance, sample.time = x, y, z, instanceID, now
    return sample.speed
end

-- GetUnitSpeed can return secret values; anything that isn't a plain number becomes 0
local function ToNumber(value)
    local ok, number = pcall(tonumber, value)
    if ok and type(number) == "number" then
        return number
    end
    ok, number = pcall(function() return value + 0 end)
    if ok and type(number) == "number" then
        return number
    end
    return 0
end

-- Yards per second: the faster of you and your vehicle
local function GetPlayerSpeed()
    local ok, speed = pcall(function()
        local current = ToNumber(GetUnitSpeed("player"))
        local inVehicle = UnitInVehicle and UnitInVehicle("player")
        if inVehicle and UnitExists("vehicle") then
            current = math.max(current, ToNumber(GetUnitSpeed("vehicle")))
        end
        current = math.max(current, 0)

        if current <= 0.1 and ((IsFlying and IsFlying()) or inVehicle) then
            current = math.max(current, GetSampledSpeed() or 0)
        end
        return current
    end)

    if ok then
        return speed
    end
    return GetSampledSpeed() or 0
end

-- ============================================================================
-- The panel
-- ============================================================================

local function UpdateText(force)
    local speed = GetPlayerSpeed()
    local percent = speed / BASE_RUN_SPEED * 100
    if percent ~= percent then -- NaN
        percent = 0
    end
    percent = math.floor(percent + 0.5)

    if not force and shownPercent == percent and math.abs((shownYards or 0) - speed) < 0.1 then
        return
    end
    shownPercent, shownYards = percent, speed
    panel.text:SetFormattedText("Speed: %d%% (%.1f yd/s)", percent, speed)
end

local function ApplyAppearance()
    local db = addon.db

    local defaultFont = GameFontHighlightLarge:GetFont()
    local outline = OUTLINES[db.speedPanelFontOutline] or OUTLINES.NONE
    addon.SetFontOrFallback(panel.text, db.speedPanelFont or defaultFont, db.speedPanelFontSize, outline.flags, defaultFont)
    local color = db.speedPanelTextColor
    panel.text:SetTextColor(color.r, color.g, color.b, color.a)

    local background = BACKGROUNDS[db.speedPanelBackgroundKey] or BACKGROUNDS.dialog
    local border = BORDERS[db.speedPanelBorderKey] or BORDERS.tooltip
    panel:SetBackdrop({ bgFile = background.texture, edgeFile = border.texture, edgeSize = border.edgeSize, insets = border.insets })
    color = db.speedPanelBackgroundColor
    panel:SetBackdropColor(color.r, color.g, color.b, color.a)

    -- The chosen border color shows once the panel is locked
    if db.speedPanelLocked then
        color = db.speedPanelBorderColor
        panel:SetBackdropBorderColor(color.r, color.g, color.b, color.a)
    else
        panel:SetBackdropBorderColor(unpack(UNLOCKED_BORDER_COLOR))
    end
    panel:SetMovable(not db.speedPanelLocked)

    -- Sized for the widest text it can show
    local text = panel.text:GetText()
    panel.text:SetText(WIDEST_TEXT)
    panel:SetSize(math.max(160, panel.text:GetStringWidth() + 24), math.max(36, panel.text:GetStringHeight() + 16))
    panel.text:SetText(text)
end

local function CreatePanel()
    panel = CreateFrame("Frame", "GarageUITweaksSpeedPanel", UIParent, "BackdropTemplate")
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:Hide()

    panel.text = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    panel.text:SetPoint("CENTER")

    panel:SetScript("OnDragStart", function(self)
        if not addon.db.speedPanelLocked then
            self:StartMoving()
        end
    end)
    panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        addon:AnchorToScreenCenter(self)
        addon:SaveFramePosition(self, "speedPanelPosition")
    end)

    panel:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Speed Panel")
        if addon.db.speedPanelLocked then
            GameTooltip:AddLine("Unlock the panel in settings to move it.", 1, 1, 1, true)
        else
            GameTooltip:AddLine("Drag with Left Click to reposition.", 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)
    panel:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    panel:SetScript("OnShow", function()
        UpdateText(true)
    end)
    -- Runs only while the panel is shown
    panel:SetScript("OnUpdate", function(_, elapsed)
        sinceUpdate = sinceUpdate + elapsed
        if sinceUpdate >= UPDATE_INTERVAL then
            sinceUpdate = 0
            UpdateText()
        end
    end)
end

function addon:UpdateSpeedPanel()
    if not self.db.speedPanelEnabled then
        if panel then
            panel:Hide()
        end
        return
    end

    if not panel then
        CreatePanel()
    end
    ApplyAppearance()
    self:RestoreFramePosition(panel, "speedPanelPosition", DEFAULT_POSITION)
    panel:Show()
    UpdateText(true)
end
