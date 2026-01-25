---@diagnostic disable: undefined-global
-- Garage UI Tweaks - Chat Tweaks
local addonName, addon = ...

local editBox = ChatFrame1EditBox
local hookInstalled = false

-- Recalculate position to match the desired scaling anchor
local function EnforceAnchor(anchor)
    if not anchor then anchor = "CENTER" end
    
    local x = editBox:GetLeft()
    local y = editBox:GetTop()
    local w = editBox:GetWidth()
    local h = editBox:GetHeight()
    
    if not x or not y then return end -- Frame not visible/set yet
    
    editBox:ClearAllPoints()
    
    if anchor == "LEFT" then
        -- Keep Left edge same
        editBox:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
    elseif anchor == "RIGHT" then
        -- Keep Right edge same
        editBox:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", x + w, y)
    else -- CENTER
        -- Keep Center same
        editBox:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x + w/2, y - h/2)
    end
    
    addon:SaveFramePosition(editBox, "chatEditBoxPosition")
end

local function UpdateVisuals()
    -- Restore Position first if needed
    addon:RestoreFramePosition(editBox, "chatEditBoxPosition")
    editBox:SetUserPlaced(true)
    
    -- Apply Border
    local hide = addon.db.chatEditBoxHideBorder
    local texLeft = _G[editBox:GetName().."Left"]
    local texRight = _G[editBox:GetName().."Right"]
    local texMid = _G[editBox:GetName().."Mid"]
    
    if texLeft then texLeft:SetShown(not hide) end
    if texRight then texRight:SetShown(not hide) end
    if texMid then texMid:SetShown(not hide) end
    
    editBox:SetWidth(addon.db.chatEditBoxWidth or 450)
    
    -- When just updating visuals, we might want to ensure the anchor is correct so future width changes scale correctly
    -- But if we just restored "TOPLEFT" from drag, and user wants "CENTER" anchor scaling, we should convert it.
    if addon.db.chatEditBoxAnchor then
        local currentPoint = editBox:GetPoint()
        -- Simplistic check: if current point doesn't match roughly the desired scaling anchor behavior
        -- We just brute force re-anchor it to the desired pivot point at current location
        EnforceAnchor(addon.db.chatEditBoxAnchor) 
    end
end

function addon:InitChatTweaks()
    if hookInstalled then 
        UpdateVisuals()
        return 
    end
    
    -- Enable movement capabilities
    editBox:SetMovable(true)
    editBox:SetClampedToScreen(true)
    
    -- Hook Mouse Events
    editBox:HookScript("OnMouseDown", function(self, button)
        if addon.db.chatEditBoxUnlock and IsShiftKeyDown() and button == "LeftButton" then
            self:StartMoving()
            self.isMoving = true
        end
    end)
    
    editBox:HookScript("OnMouseUp", function(self, button)
        if self.isMoving then
            self:StopMovingOrSizing()
            self.isMoving = false
            -- After dragging, the anchor is likely TOPLEFT. Re-enforce our desired scaling anchor
            if addon.db.chatEditBoxAnchor then
                 EnforceAnchor(addon.db.chatEditBoxAnchor)
            else
                 addon:SaveFramePosition(self, "chatEditBoxPosition")
            end
        end
    end)
    
    hookInstalled = true
    UpdateVisuals()
end

-- Listener for UI updates that might reset the anchor
hooksecurefunc("ChatEdit_UpdateHeader", function(editBox)
    if editBox == ChatFrame1EditBox and addon.db.chatEditBoxPosition then
        -- This blizzard function resets anchors. We need to re-apply ours.
        -- But we must be careful not to create infinite loops or fight it too hard during transient states.
        -- Using a ticker or just re-applying simply usually works.
        C_Timer.After(0.01, function() UpdateVisuals() end)
    end
end)

function addon:SetChatEditBoxUnlock(enabled)
    if enabled then self:InitChatTweaks() end
end

function addon:UpdateChatEditBox()
    if not hookInstalled then self:InitChatTweaks() else UpdateVisuals() end
end
