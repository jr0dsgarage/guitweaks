---@diagnostic disable: undefined-global
-- Garage UI Tweaks - UI Modifications
local addonName, addon = ...

local PADDING = 12
local INVISIBLE_TIMEOUT = 0.35

local function getNow()
    return (GetTime and GetTime()) or 0
end

local function shorten(text)
    if not text or text == "" then
        return nil
    end

    text = text:gsub("\n", " ")
    if #text > 80 then
        text = text:sub(1, 77) .. "..."
    end

    return text
end

local function ensureFrameState(frame)
    frame.guitState = frame.guitState or {}
    local state = frame.guitState

    state.timeSinceInvisible = state.timeSinceInvisible or INVISIBLE_TIMEOUT
    state.debugLog = state.debugLog or {}
    state.lastDebugAt = state.lastDebugAt or {}
    state.lastMessageTime = state.lastMessageTime or getNow()
    state.lastVisibleAgo = state.lastVisibleAgo or state.timeSinceInvisible

    return state
end

local function debugLog(state, message)
    if not addon.db or not addon.db.debugBackground then
        return
    end

    local tag = message:match("%[(.-)%]") or message
    local now = (GetTime and GetTime()) or 0
    local last = state.lastDebugAt[tag]

    if last and now - last < 0.1 then
        return
    end

    state.lastDebugAt[tag] = now

    local log = state.debugLog
    log[#log + 1] = message
    if #log > 150 then
        table.remove(log, 1)
    end
end

local function ensureBackgroundTexture(frame)
    if not frame.guit_bg then
        frame.guit_bg = frame:CreateTexture(nil, "BACKGROUND")
        frame.guit_bg:SetColorTexture(0, 0, 0, 1)
        frame.guit_bg:Hide()
    end

    return frame.guit_bg
end

-- Return tight screen-space bounds for a font string using its measured size.
local function computeRegionBounds(region)
    local width = region:GetStringWidth()
    local height = region:GetStringHeight()
    if not width or width <= 0 or not height or height <= 0 then
        return
    end

    local centerX, centerY = region:GetCenter()
    if not centerX or not centerY then
        local left = region:GetLeft()
        local top = region:GetTop()
        if not left or not top then
            return
        end
        centerX = left + width / 2
        centerY = top - height / 2
    end

    local halfW = width / 2
    local halfH = height / 2

    return centerX - halfW, centerX + halfW, centerY - halfH, centerY + halfH
end

local function forEachFontString(frame, callback)
    if frame.fontStringPool and frame.fontStringPool.EnumerateActive then
        for fontString in frame.fontStringPool:EnumerateActive() do
            callback(fontString)
        end
        return
    end

    local numRegions = frame:GetNumRegions()
    for i = 1, numRegions do
        local region = select(i, frame:GetRegions())
        if region and region:IsObjectType("FontString") then
            callback(region)
        end
    end
end

local function gatherFontStringInfo(frame)
    local hasText = false
    local hasVisible = false
    local maxAlpha = 0
    local firstAnyText
    local firstVisibleText
    local minLeft, maxRight, minBottom, maxTop
    local visibleCount = 0
    local totalCount = 0

    forEachFontString(frame, function(region)
        totalCount = totalCount + 1
        if not region or not region.GetText then
            return
        end

        local text = region:GetText()
        if text and text ~= "" then
            hasText = true
            firstAnyText = firstAnyText or text

            if region:IsVisible() then
                local alpha = region:GetAlpha() or 0
                if alpha > 0.05 then
                    hasVisible = true
                    visibleCount = visibleCount + 1
                    maxAlpha = math.max(maxAlpha, alpha)
                    firstVisibleText = firstVisibleText or text

                    local left, right, bottom, top = computeRegionBounds(region)
                    if left and right and bottom and top then
                        minLeft = minLeft and math.min(minLeft, left) or left
                        maxRight = maxRight and math.max(maxRight, right) or right
                        minBottom = minBottom and math.min(minBottom, bottom) or bottom
                        maxTop = maxTop and math.max(maxTop, top) or top
                    end
                end
            end
        end
    end)

    local bounds
    if hasVisible and minLeft and maxRight and minBottom and maxTop then
        bounds = {
            minX = minLeft,
            maxX = maxRight,
            minY = minBottom,
            maxY = maxTop,
        }
    end

    return {
        hasText = hasText,
        hasVisible = hasVisible,
        maxAlpha = maxAlpha,
        bounds = bounds,
        sampleText = firstVisibleText or firstAnyText,
        visibleCount = visibleCount,
        totalCount = totalCount,
    }
end

local function hideBackground(frame, state)
    if frame.guit_bg and frame.guit_bg:IsShown() then
        frame.guit_bg:Hide()
        debugLog(state, "[Hide]")
    end

    state.bgVisible = false
    state.sampleText = nil
    state.lastBounds = nil
end

local function showBackground(frame, state, info, baseAlpha)
    local bounds = info.bounds or state.lastBounds
    if not bounds then
        return
    end

    local texture = ensureBackgroundTexture(frame)
    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", bounds.minX - PADDING, bounds.maxY + PADDING)
    texture:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", bounds.maxX + PADDING, bounds.minY - PADDING)
    texture:SetAlpha(baseAlpha)

    if not texture:IsShown() then
        texture:Show()
        debugLog(state, string.format("[Show] alpha=%.2f", baseAlpha))
    end

    state.bgVisible = true
    if info.bounds then
        state.lastBounds = {
            minX = info.bounds.minX,
            maxX = info.bounds.maxX,
            minY = info.bounds.minY,
            maxY = info.bounds.maxY,
        }
    end
end

local function backgroundOnUpdate(frame, elapsed)
    local state = ensureFrameState(frame)

    if not addon.db or not addon.db.objectiveTrackerBG then
        if state.bgVisible then
            hideBackground(frame, state)
        end
        state.timeSinceInvisible = INVISIBLE_TIMEOUT
        state.lastVisibleAgo = state.timeSinceInvisible
        state.lastMessageAgo = getNow() - (state.lastMessageTime or getNow())
        return
    end

    local now = getNow()
    local info = gatherFontStringInfo(frame)

    state.sampleText = shorten(info.sampleText) or state.sampleText
    state.hasText = info.hasText
    state.hasVisible = info.hasVisible
    state.visibleCount = info.visibleCount or 0
    state.totalCount = info.totalCount or 0
    state.maxAlpha = info.maxAlpha or 0
    state.frameAlpha = frame.GetAlpha and frame:GetAlpha() or 1
    state.frameShown = frame:IsShown() or false
    state.lastMessageAgo = now - (state.lastMessageTime or now)

    local timeSinceInvisible = (state.timeSinceInvisible or 0) + elapsed
    local shouldShow = state.visibleCount > 0 and (info.bounds or state.lastBounds)

    if shouldShow then
        state.timeSinceInvisible = 0
        state.lastVisibleAgo = 0
        local baseAlpha = addon.db.objectiveTrackerAlpha or 0.7
        local brightness = (state.maxAlpha > 0) and state.maxAlpha or 1
        local adjustedAlpha = math.min(1, baseAlpha * brightness)
        showBackground(frame, state, info, adjustedAlpha)
    else
        state.timeSinceInvisible = timeSinceInvisible
        state.lastVisibleAgo = state.timeSinceInvisible

        if state.timeSinceInvisible >= INVISIBLE_TIMEOUT then
            if state.bgVisible then
                hideBackground(frame, state)
            end
            if state.visibleCount == 0 then
                state.sampleText = nil
                state.lastBounds = nil
            end
        end
    end
end

local function onAddMessage(frame, text)
    if not frame then
        return
    end

    local state = ensureFrameState(frame)
    state.timeSinceInvisible = 0
    state.lastMessageTime = getNow()

    local short = shorten(text)
    state.lastAddedMessage = short or state.lastAddedMessage

    if short then
        debugLog(state, string.format("[AddMessage] %s", short))
    end
end

local function ensureErrorFrame()
    local frame = UIErrorsFrame
    if not frame then
        print("|cffff0000GUIT:|r UIErrorsFrame not found!")
        return
    end

    local state = ensureFrameState(frame)
    ensureBackgroundTexture(frame)

    if not frame.guitHooked then
        frame:HookScript("OnUpdate", backgroundOnUpdate)
        frame:HookScript("OnHide", function(self)
            local hideState = ensureFrameState(self)
            if hideState.bgVisible then
                hideBackground(self, hideState)
            end
            hideState.timeSinceInvisible = INVISIBLE_TIMEOUT
            hideState.lastVisibleAgo = hideState.timeSinceInvisible
        end)
        hooksecurefunc(frame, "AddMessage", onAddMessage)
        frame.guitHooked = true
    end

    return frame, state
end

function addon:SetObjectiveTrackerBackground(enabled, alpha)
    local frame, state = ensureErrorFrame()
    if not frame or not state then
        return
    end

    state.alpha = alpha or state.alpha or 0.7

    if not enabled then
        hideBackground(frame, state)
        return
    end

    hideBackground(frame, state)
    state.timeSinceInvisible = INVISIBLE_TIMEOUT
    debugLog(state, string.format("[Enable] alpha=%.2f", state.alpha))
end

local function collectBackgroundDebugLines()
    local lines = {}
    local frame = UIErrorsFrame

    if not frame then
        lines[#lines + 1] = "[GUIT BG] UIErrorsFrame unavailable"
        return lines
    end

    local state = frame.guitState or {}
    lines[#lines + 1] = "[GUIT BG] ---- snapshot ----"
    lines[#lines + 1] = string.format("[GUIT BG] enabled=%s alphaSetting=%.2f", tostring(addon.db and addon.db.objectiveTrackerBG), state.alpha or 0)

    if frame.guit_bg then
        lines[#lines + 1] = string.format("[GUIT BG] bg shown=%s alpha=%.2f", frame.guit_bg:IsShown() and "true" or "false", frame.guit_bg:GetAlpha() or 0)
    else
        lines[#lines + 1] = "[GUIT BG] bg texture missing"
    end

    lines[#lines + 1] = string.format("[GUIT BG] hasText=%s hasVisible=%s maxAlpha=%.2f", tostring(state.hasText), tostring(state.hasVisible), state.maxAlpha or 0)
    lines[#lines + 1] = string.format("[GUIT BG] visibleCount=%d totalCount=%d", state.visibleCount or -1, state.totalCount or -1)
    lines[#lines + 1] = string.format("[GUIT BG] bgVisible=%s", tostring(state.bgVisible))
    lines[#lines + 1] = string.format("[GUIT BG] lastMsgAgo=%.2f lastVisAgo=%.2f", state.lastMessageAgo or -1, state.lastVisibleAgo or -1)
    lines[#lines + 1] = string.format("[GUIT BG] frameShown=%s frameAlpha=%.2f", tostring(state.frameShown), state.frameAlpha or -1)
    lines[#lines + 1] = string.format("[GUIT BG] timeSinceInvisible=%.2f", state.timeSinceInvisible or 0)

    if state.sampleText then
        lines[#lines + 1] = string.format("[GUIT BG] sample text: %s", state.sampleText)
    end

    if state.lastBounds then
        lines[#lines + 1] = string.format("[GUIT BG] cached bounds: (%.0f, %.0f)-(%.0f, %.0f)", state.lastBounds.minX or 0, state.lastBounds.minY or 0, state.lastBounds.maxX or 0, state.lastBounds.maxY or 0)
    end

    local log = state.debugLog
    if log and #log > 0 then
        lines[#lines + 1] = "[GUIT BG] recent events:"
        for i = math.max(1, #log - 50), #log do
            lines[#lines + 1] = log[i]
        end
    else
        lines[#lines + 1] = "[GUIT BG] recent events: (none)"
    end

    lines[#lines + 1] = "[GUIT BG] ---- end ----"
    return lines
end

function addon:DumpBackgroundDebug(quiet)
    local lines = collectBackgroundDebugLines()
    local text = table.concat(lines, "\n")
    self.lastDumpText = text

    if quiet then
        return text
    end

    for _, line in ipairs(lines) do
        print(line)
    end

    return text
end

function addon:ResetBackgroundDebugLog()
    local frame = UIErrorsFrame
    if not frame or not frame.guitState then
        return
    end

    frame.guitState.debugLog = {}
    frame.guitState.lastDebugAt = {}
end

function addon:ApplyTweaks()
    if not self.db then
        return
    end

    self:SetObjectiveTrackerBackground(self.db.objectiveTrackerBG, self.db.objectiveTrackerAlpha)
    self:SetBattlegroundMapScale(self.db.battlegroundMapScale)
end

function addon:SetBattlegroundMapScale(scale)
    scale = scale or 1.0

    if BattlefieldMapFrame then
        BattlefieldMapFrame:SetScale(scale)
    end

    if not addon.battlegroundMapHooked then
        local frame = CreateFrame("Frame")
        frame:RegisterEvent("PLAYER_ENTERING_BATTLEGROUND")
        frame:SetScript("OnEvent", function()
            C_Timer.After(0.1, function()
                if BattlefieldMapFrame and addon.db and addon.db.battlegroundMapScale then
                    BattlefieldMapFrame:SetScale(addon.db.battlegroundMapScale)
                end
            end)
        end)

        addon.battlegroundMapHooked = true
    end
end
