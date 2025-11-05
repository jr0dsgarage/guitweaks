---@diagnostic disable: undefined-global
-- Garage UI Tweaks - Speed Panel
local addonName, addon = ...

local BASE_RUN_SPEED = 7
local SPEED_UPDATE_INTERVAL = 0.05

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

    local speed = (GetUnitSpeed and GetUnitSpeed("player")) or 0
    if not speed or speed < 0 then
        speed = 0
    end

    local percent = 0
    if BASE_RUN_SPEED > 0 then
        percent = (speed / BASE_RUN_SPEED) * 100
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

    local width = frame.text:GetStringWidth()
    local height = frame.text:GetStringHeight()
    if width and width > 0 then
        frame:SetWidth(math.max(120, width + 24))
    end
    if height and height > 0 then
        frame:SetHeight(math.max(28, height + 16))
    end
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
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0, 0, 0, 0.55)
    frame:SetBackdropBorderColor(0.8, 0.8, 0.2, 0.9)
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
