---@diagnostic disable: undefined-global
-- Garage UI Tweaks - Speed Panel
local addonName, addon = ...

local BASE_RUN_SPEED = 7
local SPEED_UPDATE_INTERVAL = 0.05
local FALLBACK_SAMPLE_INTERVAL = 0.25
local MAX_SPEED_TEXT = "Speed: 9999% (999.9 yd/s)"

local DEFAULT_FONT_KEY = "GameFontHighlightLarge"
local DEFAULT_BACKGROUND_KEY = "dialog"
local DEFAULT_BORDER_KEY = "tooltip"

local SPEED_PANEL_FONT_OPTIONS = {
    { key = "GameFontHighlightLarge", name = "Game Font Large" },
    { key = "GameFontNormalLarge", name = "Game Font Normal Large" },
    { key = "GameFontNormal", name = "Game Font Normal" },
    { key = "GameFontHighlight", name = "Game Font Highlight" },
    { key = "NumberFontNormalLarge", name = "Number Font Large" },
}

local SPEED_PANEL_BACKGROUND_OPTIONS = {
    { key = "dialog", name = "Dialog", texture = "Interface\\DialogFrame\\UI-DialogBox-Background" },
    { key = "tooltip", name = "Tooltip", texture = "Interface\\Tooltips\\UI-Tooltip-Background" },
    { key = "solid", name = "Solid", texture = "Interface\\Buttons\\WHITE8x8" },
    { key = "none", name = "None", texture = nil },
}

local SPEED_PANEL_BORDER_OPTIONS = {
    { key = "tooltip", name = "Tooltip", texture = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } },
    { key = "dialog", name = "Dialog", texture = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 24, insets = { left = 12, right = 12, top = 12, bottom = 12 } },
    { key = "thin", name = "Thin", texture = "Interface\\AchievementFrame\\UI-Achievement-StatsBorder", edgeSize = 8, insets = { left = 3, right = 3, top = 3, bottom = 3 } },
    { key = "none", name = "None", texture = nil, edgeSize = 0, insets = { left = 0, right = 0, top = 0, bottom = 0 } },
}

local FONT_LOOKUP = {}
local BACKGROUND_LOOKUP = {}
local BORDER_LOOKUP = {}

local updateSpeedPanelText

for _, option in ipairs(SPEED_PANEL_FONT_OPTIONS) do
    FONT_LOOKUP[option.key] = option
end

local function sizeSpeedPanelFrame(frame)
    if not frame or not frame.text then
        return
    end

    local originalText = frame.text:GetText()
    frame.text:SetText(MAX_SPEED_TEXT)
    local width = frame.text:GetStringWidth() or 0
    local height = frame.text:GetStringHeight() or 0
    frame:SetSize(math.max(160, width + 24), math.max(36, height + 16))
    frame.text:SetText(originalText)
end

local function getFontOption(key)
    return (key and FONT_LOOKUP[key]) or FONT_LOOKUP[DEFAULT_FONT_KEY] or SPEED_PANEL_FONT_OPTIONS[1]
end

local function getBackgroundOption(key)
    return (key and BACKGROUND_LOOKUP[key]) or BACKGROUND_LOOKUP[DEFAULT_BACKGROUND_KEY] or SPEED_PANEL_BACKGROUND_OPTIONS[1]
end

local function getBorderOption(key)
    return (key and BORDER_LOOKUP[key]) or BORDER_LOOKUP[DEFAULT_BORDER_KEY] or SPEED_PANEL_BORDER_OPTIONS[1]
end

function addon:GetSpeedPanelFontOptions()
    return SPEED_PANEL_FONT_OPTIONS
end

function addon:GetSpeedPanelBackgroundOptions()
    return SPEED_PANEL_BACKGROUND_OPTIONS
end

function addon:GetSpeedPanelBorderOptions()
    return SPEED_PANEL_BORDER_OPTIONS
end

function addon:GetSpeedPanelFontName(key)
    local option = getFontOption(key)
    return option and option.name or key or "Unknown"
end

function addon:GetSpeedPanelBackgroundName(key)
    local option = getBackgroundOption(key)
    return option and option.name or key or "Unknown"
end

function addon:GetSpeedPanelBorderName(key)
    local option = getBorderOption(key)
    return option and option.name or key or "Unknown"
end

function addon:SetSpeedPanelFont(key)
    if not FONT_LOOKUP[key] then
        return
    end
    if not addon.db then
        return
    end
    addon.db.speedPanelFontKey = key
    addon:ApplySpeedPanelAppearance()
end

function addon:SetSpeedPanelBackground(key)
    if not BACKGROUND_LOOKUP[key] then
        return
    end
    if not addon.db then
        return
    end
    addon.db.speedPanelBackgroundKey = key
    addon:ApplySpeedPanelAppearance()
end

function addon:SetSpeedPanelBorder(key)
    if not BORDER_LOOKUP[key] then
        return
    end
    if not addon.db then
        return
    end
    addon.db.speedPanelBorderKey = key
    addon:ApplySpeedPanelAppearance()
end

for _, option in ipairs(SPEED_PANEL_BACKGROUND_OPTIONS) do
    BACKGROUND_LOOKUP[option.key] = option
end

for _, option in ipairs(SPEED_PANEL_BORDER_OPTIONS) do
    BORDER_LOOKUP[option.key] = option
end

local function updateFallbackTracker(speedTracker, x, y, z, instanceID, now)
    speedTracker.lastX = x
    speedTracker.lastY = y
    speedTracker.lastZ = z
    speedTracker.instance = instanceID
    speedTracker.lastTime = now
end

local function computeFallbackSpeed(active)
    if not UnitPosition or not GetTime then
        return nil
    end

    local x, y, z, instanceID = UnitPosition("player")
    local now = GetTime()

    if not x or not y or not now then
        return nil
    end

    addon.speedTracker = addon.speedTracker or {}
    local tracker = addon.speedTracker
    local hasPrevious = tracker.lastX and tracker.lastY and tracker.lastTime and tracker.lastTime < now
    local shouldCompute = active and hasPrevious and (not tracker.lastCompute or (now - tracker.lastCompute) >= FALLBACK_SAMPLE_INTERVAL)

    if tracker.instance and tracker.instance ~= instanceID then
        tracker.lastSpeed = nil
        tracker.lastCompute = nil
        updateFallbackTracker(tracker, x, y, z, instanceID, now)
        return nil
    end

    local speed
    if shouldCompute then
        local deltaX = x - tracker.lastX
        local deltaY = y - tracker.lastY
        local deltaZ = 0
        if z and tracker.lastZ then
            deltaZ = z - tracker.lastZ
        end
        local distance = math.sqrt(deltaX * deltaX + deltaY * deltaY + deltaZ * deltaZ)
        local elapsed = now - tracker.lastTime
        if elapsed > 0 then
            speed = distance / elapsed
        end
    end

    updateFallbackTracker(tracker, x, y, z, instanceID, now)

    if shouldCompute then
        tracker.lastSpeed = speed or tracker.lastSpeed
        tracker.lastCompute = now
    end

    return tracker.lastSpeed
end

local function chooseBaseline(...)
    local baseline
    for i = 1, select('#', ...) do
        local value = select(i, ...)
        if type(value) == "number" and value > 0 then
            baseline = baseline and math.min(baseline, value) or value
        end
    end
    return baseline or BASE_RUN_SPEED
end

local function getPlayerSpeed()
    if not GetUnitSpeed then
        local fallback = computeFallbackSpeed(true)
        return fallback or 0, BASE_RUN_SPEED, 0, 0, 0, fallback or 0
    end

    local current, runSpeed, flightSpeed, swimSpeed = GetUnitSpeed("player")

    if UnitInVehicle and UnitInVehicle("player") and UnitExists and UnitExists("vehicle") then
        local vehCurrent, vehRun, vehFlight, vehSwim = GetUnitSpeed("vehicle")
        if type(vehCurrent) == "number" and vehCurrent > (current or 0) then
            current = vehCurrent
        end
        if type(vehRun) == "number" and vehRun > (runSpeed or 0) then
            runSpeed = vehRun
        end
        if type(vehFlight) == "number" and vehFlight > (flightSpeed or 0) then
            flightSpeed = vehFlight
        end
        if type(vehSwim) == "number" and vehSwim > (swimSpeed or 0) then
            swimSpeed = vehSwim
        end
    end

    if type(current) ~= "number" then
        current = 0
    end

    if current < 0 then
        current = 0
    end

    runSpeed = type(runSpeed) == "number" and runSpeed or 0
    flightSpeed = type(flightSpeed) == "number" and flightSpeed or 0
    swimSpeed = type(swimSpeed) == "number" and swimSpeed or 0

    local baseline = chooseBaseline(runSpeed, flightSpeed, swimSpeed, BASE_RUN_SPEED)

    local fallback
    if (current <= 0.1) and (
        (IsFlying and IsFlying()) or
        (UnitInVehicle and UnitInVehicle("player"))
    ) then
        fallback = computeFallbackSpeed(true)
        if fallback and fallback > current then
            current = fallback
        end
    end

    return current, baseline, runSpeed, flightSpeed, swimSpeed, fallback
end

function addon:DebugSpeedPanel(current, baseline, runSpeed, flightSpeed, swimSpeed, fallback)
    if not self.db or not self.db.speedPanelDebug or not DEFAULT_CHAT_FRAME then
        return
    end

    local now = GetTime and GetTime() or 0
    if now and self.lastSpeedDebug and (now - self.lastSpeedDebug) < 0.5 then
        return
    end

    self.lastSpeedDebug = now
    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff00GUIT Speed Debug|r current=%.2f run=%.2f flight=%.2f swim=%.2f baseline=%.2f fallback=%.2f", current or 0, runSpeed or 0, flightSpeed or 0, swimSpeed or 0, baseline or 0, fallback or 0))
end

local function applySpeedPanelPosition(frame)
    if not frame then
        return
    end

    frame:ClearAllPoints()

    local pos = addon.db and addon.db.speedPanelPosition
    if pos and pos.point then
        local relative = UIParent
        if pos.relative and _G[pos.relative] then
            relative = _G[pos.relative]
        end
        frame:SetPoint(pos.point, relative, pos.relativePoint or pos.point, pos.x or 0, pos.y or 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
    end
end

local function saveSpeedPanelPosition(frame)
    if not addon.db then
        return
    end

    local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()
    if not point then
        return
    end

    addon.db.speedPanelPosition = {
        point = point,
        relative = relativeTo and relativeTo:GetName() or nil,
        relativePoint = relativePoint,
        x = xOfs,
        y = yOfs,
    }
end

function addon:ApplySpeedPanelPosition()
    if not self.speedPanel then
        return
    end

    applySpeedPanelPosition(self.speedPanel)
end

local function updateSpeedPanelText(frame, force)
    if not frame or not frame.text then
        return
    end

    local speed, baseline, runSpeed, flightSpeed, swimSpeed, fallback = getPlayerSpeed()

    local percent = 0
    if baseline > 0 then
        percent = (speed / baseline) * 100
    end

    if percent ~= percent then -- NaN guard
        percent = 0
    end

    local roundedPercent = math.floor(percent + 0.5)
    local yardsPerSecond = speed

    if not force and frame.lastPercent == roundedPercent and math.abs((frame.lastYards or 0) - yardsPerSecond) < 0.1 then
        return
    end

    frame.lastPercent = roundedPercent
    frame.lastYards = yardsPerSecond

    frame.text:SetText(string.format("Speed: %d%% (%.1f yd/s)", roundedPercent, yardsPerSecond))

    addon:DebugSpeedPanel(speed, baseline, runSpeed, flightSpeed, swimSpeed, fallback)

end

local function applySpeedPanelAppearance(frame)
    if not frame or not frame.text then
        return
    end

    local db = addon.db or {}
    local fontOption = getFontOption(db.speedPanelFontKey)
    local fontObject = _G[fontOption.key] or _G[DEFAULT_FONT_KEY] or GameFontHighlightLarge
    if fontObject then
        frame.text:SetFontObject(fontObject)
    end

    local backgroundOption = getBackgroundOption(db.speedPanelBackgroundKey)
    local borderOption = getBorderOption(db.speedPanelBorderKey)

    frame:SetBackdrop({
        bgFile = backgroundOption.texture,
        edgeFile = borderOption.texture,
        edgeSize = borderOption.edgeSize or 12,
        insets = borderOption.insets or { left = 3, right = 3, top = 3, bottom = 3 },
    })

    if backgroundOption.key == "solid" then
        frame:SetBackdropColor(0, 0, 0, 0.55)
    else
        frame:SetBackdropColor(0, 0, 0, 0.55)
    end

    sizeSpeedPanelFrame(frame)
    addon:RefreshSpeedPanelLock()
end

function addon:ApplySpeedPanelAppearance()
    if not self.speedPanel then
        return
    end
    applySpeedPanelAppearance(self.speedPanel)
    updateSpeedPanelText(self.speedPanel, true)
end

local function speedPanelOnUpdate(self, elapsed)
    if not self:IsShown() then
        return
    end

    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed < SPEED_UPDATE_INTERVAL then
        return
    end

    self.elapsed = 0
    updateSpeedPanelText(self)
end

local function ensureSpeedPanel()
    if addon.speedPanel then
        return addon.speedPanel
    end

    local frame = CreateFrame("Frame", "GarageUITweaksSpeedPanel", UIParent, "BackdropTemplate")
    frame:SetSize(160, 36)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        if addon.db and addon.db.speedPanelLocked then
            return
        end
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        saveSpeedPanelPosition(self)
    end)

    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    text:SetPoint("CENTER")
    text:SetText("Speed: 0% (0.0 yd/s)")
    frame.text = text

    frame.elapsed = 0

    frame:SetScript("OnShow", function(self)
        updateSpeedPanelText(self, true)
    end)

    frame:SetScript("OnEnter", function(self)
        if not GameTooltip then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Speed Panel")
        if addon.db and addon.db.speedPanelLocked then
            GameTooltip:AddLine("Unlock the panel in settings to move it.", 1, 1, 1, true)
        else
            GameTooltip:AddLine("Drag with Left Click to reposition.", 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)

    frame:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    frame:Hide()

    addon.speedPanel = frame
    applySpeedPanelPosition(frame)
    applySpeedPanelAppearance(frame)
    updateSpeedPanelText(frame, true)
    return frame
end

function addon:SetSpeedPanelEnabled(enabled)
    if not self.db then
        return
    end

    if enabled then
        local frame = ensureSpeedPanel()
        if not frame then
            return
        end

        applySpeedPanelPosition(frame)
        addon:ApplySpeedPanelAppearance()
        frame.elapsed = 0
        frame:SetScript("OnUpdate", speedPanelOnUpdate)
        updateSpeedPanelText(frame, true)
        frame:Show()
    else
        local frame = self.speedPanel
        if frame then
            frame:SetScript("OnUpdate", nil)
            frame:Hide()
        end
    end

    self:RefreshSpeedPanelLock()
end

function addon:RefreshSpeedPanelLock()
    local frame = self.speedPanel
    if not frame then
        return
    end

    local locked = self.db and self.db.speedPanelLocked
    frame.isLocked = locked and true or false

    if locked then
        frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.9)
        frame:SetMovable(false)
    else
        frame:SetBackdropBorderColor(0.8, 0.8, 0.2, 0.9)
        frame:SetMovable(true)
    end
end

function addon:ResetSpeedPanelPosition()
    if not self.db then
        return
    end

    self.db.speedPanelPosition = nil

    if self.speedPanel then
        applySpeedPanelPosition(self.speedPanel)
        if self.speedPanel:IsShown() then
            updateSpeedPanelText(self.speedPanel, true)
        end
    end
end
