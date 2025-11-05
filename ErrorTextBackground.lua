---@diagnostic disable: undefined-global
-- Garage UI Tweaks - Error Text Background
local addonName, addon = ...

local ERROR_BG_PADDING = 12
local DEFAULT_ERROR_BG_ALPHA = 0.7
local DEFAULT_ERROR_BG_DURATION = 3.0
local ERROR_BG_POLL_INTERVAL = 0.06

local tweenFrame = CreateFrame("Frame")
local tweenElapsed

local function getNow()
    return (GetTime and GetTime()) or 0
end

local function ensureErrorBackgroundTexture(frame)
    if frame.guitErrorBackground then
        return frame.guitErrorBackground
    end

    local texture = frame:CreateTexture(nil, "BACKGROUND")
    texture:SetColorTexture(0, 0, 0, 1)
    texture:Hide()
    frame.guitErrorBackground = texture
    return texture
end

local function hideErrorBackground(frame, state)
    if frame.guitErrorBackground then
        frame.guitErrorBackground:Hide()
    end
    state.bgVisible = false
    state.showUntil = nil
    state.lastBounds = nil
end

local function applyErrorBackground(frame, state, bounds, alpha)
    if not bounds then
        return
    end

    local texture = ensureErrorBackgroundTexture(frame)
    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", bounds.minX - ERROR_BG_PADDING, bounds.maxY + ERROR_BG_PADDING)
    texture:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", bounds.maxX + ERROR_BG_PADDING, bounds.minY - ERROR_BG_PADDING)
    texture:SetAlpha(alpha or state.baseAlpha or DEFAULT_ERROR_BG_ALPHA)
    texture:Show()

    state.bgVisible = true
    state.lastBounds = {
        minX = bounds.minX,
        maxX = bounds.maxX,
        minY = bounds.minY,
        maxY = bounds.maxY,
    }
end

local function computeFontStringBounds(region)
    if not region or not region.GetStringWidth then
        return
    end

    local width = region:GetStringWidth()
    local height = region:GetStringHeight()
    if not width or width <= 0 or not height or height <= 0 then
        return
    end

    local centerX, centerY = region:GetCenter()
    local effectiveScale = region.GetEffectiveScale and region:GetEffectiveScale() or 1
    local parentScale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    local scaleFactor = (effectiveScale > 0 and parentScale > 0) and (effectiveScale / parentScale) or 1

    width = width * scaleFactor
    height = height * scaleFactor

    if not centerX or not centerY then
        local left = region:GetLeft()
        local top = region:GetTop()
        if not left or not top then
            return
        end
        centerX = left + (width / 2)
        centerY = top - (height / 2)
    end

    local halfW = width / 2
    local halfH = height / 2

    return centerX - halfW, centerX + halfW, centerY - halfH, centerY + halfH
end

local function gatherErrorTextBounds(frame)
    local minLeft, maxRight, minBottom, maxTop
    local hasBounds = false
    local numRegions = frame:GetNumRegions()

    for i = 1, numRegions do
        local region = select(i, frame:GetRegions())
        if region and region:IsObjectType("FontString") then
            local text = region:GetText()
            if text and text ~= "" and region:IsShown() then
                local alpha = region:GetAlpha() or 1
                if alpha > 0.05 then
                    local left, right, bottom, top = computeFontStringBounds(region)
                    if left and right and top and bottom then
                        hasBounds = true
                        minLeft = minLeft and math.min(minLeft, left) or left
                        maxRight = maxRight and math.max(maxRight, right) or right
                        minBottom = minBottom and math.min(minBottom, bottom) or bottom
                        maxTop = maxTop and math.max(maxTop, top) or top
                    end
                end
            end
        end
    end

    if not hasBounds then
        return nil
    end

    return {
        minX = minLeft,
        maxX = maxRight,
        minY = minBottom,
        maxY = maxTop,
    }
end

local function scheduleErrorBackgroundRefresh(frame)
    local state = frame and frame.guitState
    if not state then
        return
    end

    if state.refreshScheduled then
        return
    end

    state.refreshScheduled = true
    C_Timer.After(0, function()
        if not frame or not frame.guitState then
            return
        end
        state.refreshScheduled = false
        if addon.db and addon.db.errorTextBackgroundEnabled then
            state.pendingRefresh = true
        end
    end)
end

local function ensureErrorWatcher()
    if tweenFrame.guitWatcherActive then
        return
    end

    tweenFrame.guitWatcherActive = true
    tweenFrame:SetScript("OnUpdate", function(_, elapsed)
        tweenElapsed = (tweenElapsed or 0) + elapsed

        if tweenElapsed < ERROR_BG_POLL_INTERVAL then
            return
        end

        tweenElapsed = 0

        if not addon.db or not addon.db.errorTextBackgroundEnabled then
            return
        end

        local frame = UIErrorsFrame
        if not frame or not frame.guitState then
            return
        end

        local state = frame.guitState
        local now = getNow()

        if state.showUntil and now >= state.showUntil then
            hideErrorBackground(frame, state)
            return
        end

        local bounds = gatherErrorTextBounds(frame)
        if not bounds then
            if state.bgVisible then
                hideErrorBackground(frame, state)
            end
            return
        end

        if not state.bgVisible then
            applyErrorBackground(frame, state, bounds, state.baseAlpha)
            state.showUntil = state.showUntil or (now + state.fadeDelay)
            return
        end

        local widthChange = math.abs((bounds.maxX - bounds.minX) - (state.lastBounds.maxX - state.lastBounds.minX))
        local heightChange = math.abs((bounds.maxY - bounds.minY) - (state.lastBounds.maxY - state.lastBounds.minY))
        if widthChange > 2 or heightChange > 2 then
            applyErrorBackground(frame, state, bounds, state.baseAlpha)
        end
    end)
end

local function ensureErrorFrame()
    local frame = UIErrorsFrame
    if not frame then
        return
    end

    frame.guitState = frame.guitState or {}
    local state = frame.guitState
    state.baseAlpha = (addon.db and addon.db.errorTextBackgroundAlpha) or state.baseAlpha or DEFAULT_ERROR_BG_ALPHA
    state.fadeDelay = (addon.db and addon.db.errorTextBackgroundDuration) or state.fadeDelay or DEFAULT_ERROR_BG_DURATION

    if frame.guitHooked then
        return frame, state
    end

    frame.guitHooked = true
    ensureErrorWatcher()

    frame:HookScript("OnUpdate", function(self)
        local frameState = self.guitState
        if not frameState then
            return
        end

        if not addon.db or not addon.db.errorTextBackgroundEnabled then
            if frameState.bgVisible then
                hideErrorBackground(self, frameState)
            end
            return
        end

        frameState.baseAlpha = addon.db.errorTextBackgroundAlpha or DEFAULT_ERROR_BG_ALPHA
        frameState.fadeDelay = addon.db.errorTextBackgroundDuration or DEFAULT_ERROR_BG_DURATION

        local now = getNow()

        if frameState.pendingRefresh and (not frameState.nextAttempt or now >= frameState.nextAttempt) then
            local bounds = gatherErrorTextBounds(self)
            if bounds then
                applyErrorBackground(self, frameState, bounds, frameState.baseAlpha)
                frameState.pendingRefresh = false
                frameState.showUntil = frameState.showUntil or (now + frameState.fadeDelay)
            else
                frameState.nextAttempt = now + ERROR_BG_POLL_INTERVAL
            end
        end

        if frameState.bgVisible and frameState.showUntil and now >= frameState.showUntil then
            hideErrorBackground(self, frameState)
        end
    end)

    frame:HookScript("OnHide", function(self)
        local frameState = self.guitState
        if frameState then
            hideErrorBackground(self, frameState)
        end
    end)

    hooksecurefunc(frame, "AddMessage", function(self)
        local frameState = self.guitState
        if not frameState then
            return
        end

        if not addon.db or not addon.db.errorTextBackgroundEnabled then
            return
        end

        frameState.showUntil = getNow() + (addon.db.errorTextBackgroundDuration or DEFAULT_ERROR_BG_DURATION)
        frameState.pendingRefresh = true
        frameState.nextAttempt = getNow()
        scheduleErrorBackgroundRefresh(self)
    end)

    return frame, state
end

function addon:SetErrorTextBackground(enabled, alpha, duration)
    local frame, state = ensureErrorFrame()
    if not frame or not state then
        return
    end

    state.baseAlpha = alpha or DEFAULT_ERROR_BG_ALPHA
    state.fadeDelay = duration or DEFAULT_ERROR_BG_DURATION

    if not enabled then
        hideErrorBackground(frame, state)
        state.enabled = false
        return
    end

    state.enabled = true

    local bounds = gatherErrorTextBounds(frame)
    if bounds then
        applyErrorBackground(frame, state, bounds, state.baseAlpha)
        state.showUntil = getNow() + state.fadeDelay
    else
        hideErrorBackground(frame, state)
    end

    if frame.guitErrorBackground then
        frame.guitErrorBackground:SetAlpha(state.baseAlpha)
    end

    scheduleErrorBackgroundRefresh(frame)
end
