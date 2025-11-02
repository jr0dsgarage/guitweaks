---@diagnostic disable: undefined-global
-- Garage UI Tweaks - UI Modifications
local addonName, addon = ...

-- Add background to objective tracker (quest progress popup)
function addon:SetObjectiveTrackerBackground(enabled, alpha)
    -- The frame we're looking for is UIErrorsFrame - shows errors and quest updates
    local errorFrame = UIErrorsFrame
    
    if not errorFrame then 
        print("|cffff0000GUIT:|r UIErrorsFrame not found!")
        return 
    end
    
    alpha = alpha or 0.7

    local function DebugBackgroundState(tag, info)
        if not addon.db or not addon.db.debugBackground then
            return
        end

        local now = GetTime and GetTime() or 0
        errorFrame.guit_lastDebugTimes = errorFrame.guit_lastDebugTimes or {}
        local lastTime = errorFrame.guit_lastDebugTimes[tag]
        if lastTime and now - lastTime < 0.2 then
            return
        end

        errorFrame.guit_lastDebugTimes[tag] = now
        local message = string.format("[GUIT BG] %s%s", tag, info and (": " .. info) or "")
        errorFrame.guit_debugLog = errorFrame.guit_debugLog or {}
        table.insert(errorFrame.guit_debugLog, message)
        if #errorFrame.guit_debugLog > 200 then
            table.remove(errorFrame.guit_debugLog, 1)
        end
    end
    
    if enabled then
        -- Create background if it doesn't exist
        if not errorFrame.guit_bg then
            errorFrame.guit_bg = errorFrame:CreateTexture(nil, "BACKGROUND")
        end
        
        -- Set to black with configured alpha
        errorFrame.guit_bg:SetColorTexture(0, 0, 0, alpha)
        
        -- Track fade state
        if not errorFrame.guit_fadeTimer then
            errorFrame.guit_fadeTimer = 0
            errorFrame.guit_targetAlpha = 0
            errorFrame.guit_currentAlpha = 0
            errorFrame.guit_lastMessageTime = 0
        end
        
        -- Hook to show/hide background based on text visibility
        if not errorFrame.guit_hooked then
            hooksecurefunc(errorFrame, "AddMessage", function(self)
                if errorFrame.guit_bg then
                    errorFrame.guit_targetAlpha = alpha
                    errorFrame.guit_fadeTimer = 0  -- Reset fade timer
                    errorFrame.guit_lastMessageTime = GetTime()
                    errorFrame.guit_lastDebugText = nil
                    DebugBackgroundState("AddMessage", string.format("alpha=%.2f", alpha))
                end
            end)
            
            -- Update background size and visibility based on text
            errorFrame:HookScript("OnUpdate", function(self, elapsed)
                local currentTime = GetTime()
                
                -- Find visible text regions and calculate bounds
                local minX, maxX, minY, maxY = nil, nil, nil, nil
                local hasVisibleMessages = false
                local padding = 10  -- Padding around text
                local maxAlpha = 0
                local foundAnyText = false
                
                for i = 1, self:GetNumRegions() do
                    local region = select(i, self:GetRegions())
                    if region and region:IsObjectType("FontString") then
                        local text = region:GetText()
                        if text and text ~= "" then
                            foundAnyText = true
                            local regionAlpha = region:GetAlpha()
                            if region:IsShown() and regionAlpha > 0.01 then
                                hasVisibleMessages = true
                                maxAlpha = math.max(maxAlpha, regionAlpha)
                                
                                -- Get text dimensions
                                local width = region:GetStringWidth()
                                local height = region:GetStringHeight()
                                local x, y = region:GetCenter()
                                
                                if x and y and width > 0 and height > 0 then
                                    local left = x - (width / 2)
                                    local right = x + (width / 2)
                                    local top = y + (height / 2)
                                    local bottom = y - (height / 2)
                                    
                                    minX = minX and math.min(minX, left) or left
                                    maxX = maxX and math.max(maxX, right) or right
                                    minY = minY and math.min(minY, bottom) or bottom
                                    maxY = maxY and math.max(maxY, top) or top
                                end

                                if addon.db and addon.db.debugBackground and not errorFrame.guit_lastDebugText then
                                    errorFrame.guit_lastDebugText = text
                                    DebugBackgroundState("VisibleMessage", string.format("alpha=%.2f text=%s", regionAlpha, text))
                                end
                            end
                        end
                    end
                end
                
                -- Aggressive timeout check - force hide after 5 seconds
                local timeSinceLastMessage = currentTime - (errorFrame.guit_lastMessageTime or 0)
                if timeSinceLastMessage > 5 then
                    foundAnyText = false
                    hasVisibleMessages = false
                    maxAlpha = 0
                end
                
                -- If no text exists at all, immediately hide
                if not foundAnyText then
                    hasVisibleMessages = false
                    maxAlpha = 0
                end
                
                if errorFrame.guit_bg then
                    if hasVisibleMessages and minX and maxAlpha > 0.01 then
                        -- Messages are visible, fade in
                        errorFrame.guit_targetAlpha = alpha * maxAlpha
                        errorFrame.guit_fadeTimer = 0
                        
                        -- Size background to fit the text with padding
                        local bgWidth = (maxX - minX) + (padding * 2)
                        local bgHeight = (maxY - minY) + (padding * 2)
                        local centerX = (minX + maxX) / 2
                        local centerY = (minY + maxY) / 2
                        
                        errorFrame.guit_bg:ClearAllPoints()
                        errorFrame.guit_bg:SetSize(bgWidth, bgHeight)
                        errorFrame.guit_bg:SetPoint("CENTER", UIParent, "BOTTOMLEFT", centerX, centerY)
                    elseif foundAnyText and not hasVisibleMessages then
                        DebugBackgroundState("NoVisibleAlpha", string.format("maxAlpha=%.2f timeSince=%.2f", maxAlpha or -1, timeSinceLastMessage or -1))
                    else
                        -- No visible messages, start fade out
                        errorFrame.guit_targetAlpha = 0
                        errorFrame.guit_fadeTimer = errorFrame.guit_fadeTimer + elapsed
                    end
                    
                    -- Smooth fade animation
                    local fadeSpeed = 5  -- Higher = faster fade (increased from 3)
                    if errorFrame.guit_currentAlpha < errorFrame.guit_targetAlpha then
                        -- Fade in
                        errorFrame.guit_currentAlpha = math.min(errorFrame.guit_targetAlpha, errorFrame.guit_currentAlpha + (elapsed * fadeSpeed))
                    elseif errorFrame.guit_currentAlpha > errorFrame.guit_targetAlpha then
                        -- Fade out
                        errorFrame.guit_currentAlpha = math.max(errorFrame.guit_targetAlpha, errorFrame.guit_currentAlpha - (elapsed * fadeSpeed))
                    end
                    
                    -- Update background alpha
                    if errorFrame.guit_currentAlpha > 0.005 then
                        errorFrame.guit_bg:SetAlpha(errorFrame.guit_currentAlpha)
                        errorFrame.guit_bg:Show()
                        if addon.db and addon.db.debugBackground then
                            DebugBackgroundState("Show", string.format("alpha=%.2f", errorFrame.guit_currentAlpha))
                        end
                    else
                        errorFrame.guit_bg:Hide()
                        errorFrame.guit_currentAlpha = 0  -- Force to zero
                        if addon.db and addon.db.debugBackground then
                            DebugBackgroundState("Hide", string.format("state=%s", foundAnyText and "text" or "none"))
                        end
                    end
                    
                    -- Force hide if no messages for a while, no text exists, or timeout
                    if (errorFrame.guit_fadeTimer > 0.3 and errorFrame.guit_currentAlpha <= 0.005) or not foundAnyText or timeSinceLastMessage > 5 then
                        errorFrame.guit_bg:Hide()
                        errorFrame.guit_currentAlpha = 0
                        errorFrame.guit_targetAlpha = 0
                        DebugBackgroundState("ForceHide", string.format("timer=%.2f foundAny=%s timeSince=%.2f", errorFrame.guit_fadeTimer or -1, tostring(foundAnyText), timeSinceLastMessage or -1))
                    end
                end
            end)
            
            errorFrame.guit_hooked = true
        end
        
        -- Initially hide until messages appear
        errorFrame.guit_bg:Hide()
    else
        -- Remove background if it exists
        if errorFrame.guit_bg then
            errorFrame.guit_bg:Hide()
        end
    end
end

local function CollectBackgroundDebugLines()
    local lines = {}
    local errorFrame = UIErrorsFrame

    if not errorFrame then
        lines[#lines + 1] = "[GUIT BG] UIErrorsFrame unavailable"
        return lines
    end

    lines[#lines + 1] = "[GUIT BG] ---- snapshot ----"
    lines[#lines + 1] = string.format("[GUIT BG] enabled=%s currentAlpha=%.2f targetAlpha=%.2f fadeTimer=%.2f", tostring(addon.db and addon.db.objectiveTrackerBG), errorFrame.guit_currentAlpha or -1, errorFrame.guit_targetAlpha or -1, errorFrame.guit_fadeTimer or -1)

    if errorFrame.guit_bg then
        lines[#lines + 1] = string.format("[GUIT BG] bg shown=%s alpha=%.2f", errorFrame.guit_bg:IsShown() and "true" or "false", errorFrame.guit_bg:GetAlpha() or -1)
    else
        lines[#lines + 1] = "[GUIT BG] bg texture not created"
    end

    local index = 0
    for i = 1, errorFrame:GetNumRegions() do
        local region = select(i, errorFrame:GetRegions())
        if region and region:IsObjectType("FontString") then
            index = index + 1
            local text = region:GetText()
            if text and text ~= "" then
                local alpha = region:GetAlpha() or 0
                local shown = region:IsShown() and "shown" or "hidden"
                local shortText = text
                if shortText:len() > 80 then
                    shortText = shortText:sub(1, 77) .. "..."
                end
                lines[#lines + 1] = string.format("[GUIT BG] text[%d] %s alpha=%.2f -> %s", index, shown, alpha, shortText)
            end
        end
    end

    if index == 0 then
        lines[#lines + 1] = "[GUIT BG] no font strings detected"
    end

    local log = errorFrame.guit_debugLog
    if log and #log > 0 then
        lines[#lines + 1] = "[GUIT BG] recent events:"
        local startIndex = math.max(1, #log - 50)
        for i = startIndex, #log do
            lines[#lines + 1] = log[i]
        end
    else
        lines[#lines + 1] = "[GUIT BG] recent events: (none)"
    end

    lines[#lines + 1] = "[GUIT BG] ---- end ----"
    return lines
end

function addon:DumpBackgroundDebug(quiet)
    local lines = CollectBackgroundDebugLines()
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
    local errorFrame = UIErrorsFrame
    if not errorFrame then
        return
    end

    errorFrame.guit_debugLog = {}
    errorFrame.guit_lastDebugTimes = {}
    errorFrame.guit_lastDebugText = nil
end

-- Apply all tweaks based on saved settings
function addon:ApplyTweaks()
    if not self.db then return end
    
    -- Apply objective tracker background
    self:SetObjectiveTrackerBackground(self.db.objectiveTrackerBG, self.db.objectiveTrackerAlpha)
end
