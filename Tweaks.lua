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
                    else
                        errorFrame.guit_bg:Hide()
                        errorFrame.guit_currentAlpha = 0  -- Force to zero
                    end
                    
                    -- Force hide if no messages for a while, no text exists, or timeout
                    if (errorFrame.guit_fadeTimer > 0.3 and errorFrame.guit_currentAlpha <= 0.005) or not foundAnyText or timeSinceLastMessage > 5 then
                        errorFrame.guit_bg:Hide()
                        errorFrame.guit_currentAlpha = 0
                        errorFrame.guit_targetAlpha = 0
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

-- Apply all tweaks based on saved settings
function addon:ApplyTweaks()
    if not self.db then return end
    
    -- Apply objective tracker background
    self:SetObjectiveTrackerBackground(self.db.objectiveTrackerBG, self.db.objectiveTrackerAlpha)
end
