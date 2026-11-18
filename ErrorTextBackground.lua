---@diagnostic disable: undefined-global
-- Garage UI Tweaks - Error Text Background
-- A dark box behind the red error messages at the top of the screen (UIErrorsFrame). Each
-- new message shows it for the chosen duration; meanwhile it is redrawn to fit the
-- messages still on screen, and goes early once they have all faded.
local addonName, addon = ...

local PADDING = 12
local POLL_INTERVAL = 0.06
local MIN_TEXT_ALPHA = 0.05 -- a message fainter than this has faded out

local background -- texture on UIErrorsFrame, created on first use
local hideAt -- when the box goes; each new message pushes it back
local drawnLeft, drawnRight, drawnBottom, drawnTop
local hooked = false
local sincePoll = 0

-- Runs only between a message arriving and the box going
local watcher = CreateFrame("Frame")
watcher:Hide()

-- The rectangle around every message still on screen, in UIErrorsFrame's coordinates,
-- or nothing when there is none
local function GetTextBounds()
    local left, right, bottom, top
    for _, region in ipairs({ UIErrorsFrame:GetRegions() }) do
        if region:IsObjectType("FontString") and region:IsShown() and (region:GetAlpha() or 1) > MIN_TEXT_ALPHA then
            local text = region:GetText()
            local width, height = region:GetStringWidth(), region:GetStringHeight()
            local centerX, centerY = region:GetCenter()
            if text and text ~= "" and width and width > 0 and height and height > 0 and centerX then
                left = math.min(left or math.huge, centerX - width / 2)
                right = math.max(right or -math.huge, centerX + width / 2)
                bottom = math.min(bottom or math.huge, centerY - height / 2)
                top = math.max(top or -math.huge, centerY + height / 2)
            end
        end
    end
    return left, right, bottom, top
end

local function HideBox()
    if background then
        background:Hide()
    end
    drawnLeft = nil
end

local function Stop()
    HideBox()
    hideAt = nil
    watcher:Hide()
end

local function Refresh()
    if GetTime() >= hideAt then
        Stop()
        return
    end

    -- A message is laid out a frame after it arrives, so keep looking until hideAt
    local left, right, bottom, top = GetTextBounds()
    if not left then
        HideBox()
        return
    end

    if drawnLeft and math.abs(left - drawnLeft) < 1 and math.abs(right - drawnRight) < 1
        and math.abs(bottom - drawnBottom) < 1 and math.abs(top - drawnTop) < 1 then
        return
    end

    if not background then
        background = UIErrorsFrame:CreateTexture(nil, "BACKGROUND")
        background:SetColorTexture(0, 0, 0, 1)
    end
    background:ClearAllPoints()
    background:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left - PADDING, top + PADDING)
    background:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", right + PADDING, bottom - PADDING)
    background:SetAlpha(addon.db.errorTextBackgroundAlpha)
    background:Show()
    drawnLeft, drawnRight, drawnBottom, drawnTop = left, right, bottom, top
end

watcher:SetScript("OnUpdate", function(_, elapsed)
    sincePoll = sincePoll + elapsed
    if sincePoll >= POLL_INTERVAL then
        sincePoll = 0
        Refresh()
    end
end)

local function OnMessageAdded()
    if not addon.db.errorTextBackgroundEnabled then
        return
    end
    hideAt = GetTime() + addon.db.errorTextBackgroundDuration
    sincePoll = POLL_INTERVAL -- check on the next frame
    watcher:Show()
end

function addon:UpdateErrorTextBackground()
    if not UIErrorsFrame then
        return
    end

    if not self.db.errorTextBackgroundEnabled then
        Stop()
        return
    end

    if not hooked then
        hooksecurefunc(UIErrorsFrame, "AddMessage", OnMessageAdded)
        hooked = true
    end
    if background then
        background:SetAlpha(self.db.errorTextBackgroundAlpha)
    end
end
