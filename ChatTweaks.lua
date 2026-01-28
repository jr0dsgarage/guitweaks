---@diagnostic disable: undefined-global
-- Garage UI Tweaks - Chat Tweaks
local addonName, addon = ...

local hookInstalled = false

-- Recalculate position to match the desired scaling anchor
local function EnforceAnchor(editBox, anchor, save)
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
    
    if save then
        addon:SaveFramePosition(editBox, "chatEditBoxPosition")
    end
end

local function UpdateVisuals()
    -- Loop through all chat frames to ensure consistency across tabs
    for i = 1, NUM_CHAT_WINDOWS do
        local editBox = _G["ChatFrame"..i.."EditBox"]
        if editBox then
            -- Skip positioning logic if this specific box is currently being dragged by the user
            if not editBox.isMoving then
                -- Set user placed immediately to discourage Blizzard interference where possible
                editBox:SetUserPlaced(true)

                -- Restore Position first if needed
                addon:RestoreFramePosition(editBox, "chatEditBoxPosition")
                
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
                if addon.db.chatEditBoxAnchor then
                    EnforceAnchor(editBox, addon.db.chatEditBoxAnchor, false) 
                end
            end
        end
    end
end

function addon:InitChatTweaks()
    if hookInstalled then 
        UpdateVisuals()
        addon:UpdateChatButtonBackgrounds()
        return 
    end
    
    for i = 1, NUM_CHAT_WINDOWS do
        local editBox = _G["ChatFrame"..i.."EditBox"]
        if editBox then
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
                         EnforceAnchor(self, addon.db.chatEditBoxAnchor, true)
                    else
                         addon:SaveFramePosition(self, "chatEditBoxPosition")
                    end
                    UpdateVisuals()
                end
            end)
            
            -- Hook OnShow to force alignment when switching tabs
            editBox:HookScript("OnShow", function(self)
                -- Defer slightly to override Blizzard's default positioning for the active tab
                C_Timer.After(0.01, function() 
                    if not self.isMoving then
                        -- We specifically target 'self' here to ensure the active one is caught, 
                        -- but UpdateVisuals handles everything anyway.
                        UpdateVisuals() 
                    end
                end)
            end)
        end
    end
    
    -- Hook OnShow for Chat Buttons to ensure they stay hidden if disabled
    if ChatFrameMenuButton then
        ChatFrameMenuButton:HookScript("OnShow", function(self)
            if addon.db.hideChatFrameMenuButton then
                self:Hide()
            end
        end)
    end
    
    if ChatFrameChannelButton then
        ChatFrameChannelButton:HookScript("OnShow", function(self)
            if addon.db.hideChatFrameChannelButton then
                self:Hide()
            end
        end)
    end

    hookInstalled = true
    UpdateVisuals()
    addon:UpdateChatButtonBackgrounds()
end

function addon:UpdateChatButtonBackgrounds()
    for i = 1, NUM_CHAT_WINDOWS do
        -- Hide the background texture
        local background = _G["ChatFrame" .. i .. "ButtonFrameBackground"]
        if background then
            if addon.db.hideChatButtonFrameBackground then
                background:Hide()
            else
                background:Show()
            end
        end
        
        -- Hide the border textures (Top, Bottom, Left, Right, Middle if exists)
        -- Assuming standard naming convention for some frames or backdrop
        local btnFrame = _G["ChatFrame" .. i .. "ButtonFrame"]
        if btnFrame then
            local textures = {
                _G[btnFrame:GetName() .. "Top"],
                _G[btnFrame:GetName() .. "Bottom"],
                _G[btnFrame:GetName() .. "Left"],
                _G[btnFrame:GetName() .. "Right"],
                _G[btnFrame:GetName() .. "Middle"], 
                _G[btnFrame:GetName() .. "TopLeft"],
                _G[btnFrame:GetName() .. "TopRight"],
                _G[btnFrame:GetName() .. "BottomLeft"],
                _G[btnFrame:GetName() .. "BottomRight"],
                _G[btnFrame:GetName() .. "TopTexture"],
                _G[btnFrame:GetName() .. "BottomTexture"],
                _G[btnFrame:GetName() .. "LeftTexture"],
                _G[btnFrame:GetName() .. "RightTexture"],
                _G[btnFrame:GetName() .. "MiddleTexture"], 
                _G[btnFrame:GetName() .. "TopLeftTexture"],
                _G[btnFrame:GetName() .. "TopRightTexture"],
                _G[btnFrame:GetName() .. "BottomLeftTexture"],
                _G[btnFrame:GetName() .. "BottomRightTexture"],
            }
            
            for _, tex in pairs(textures) do
                if addon.db.hideChatButtonFrameBackground then
                    tex:Hide()
                else
                    tex:Show()
                end
            end
            
            -- If it uses Backdrops
            if btnFrame.GetBackdrop and btnFrame:GetBackdrop() then
                 if addon.db.hideChatButtonFrameBackground then
                     btnFrame:SetBackdropBorderColor(0,0,0,0)
                     btnFrame:SetBackdropColor(0,0,0,0)
                 else
                     -- Can't easily restore original without storing it, but usually standard
                     btnFrame:SetBackdropBorderColor(1,1,1,1)
                     btnFrame:SetBackdropColor(0,0,0,0.5) 
                 end
            end
        end

        -- Hide the minimize button
        local minimize = _G["ChatFrame" .. i .. "ButtonFrameMinimizeButton"]
        if minimize then
            if addon.db.hideChatButtonFrameBackground then
                minimize:Hide()
            else
                minimize:Show()
            end
        end
    end
    
    -- Main Chat Frame Buttons
    if ChatFrameMenuButton then
        if addon.db.hideChatFrameMenuButton then
            ChatFrameMenuButton:Hide()
        else
            ChatFrameMenuButton:Show()
        end
    end
    
    if ChatFrameChannelButton then
        if addon.db.hideChatFrameChannelButton then
            ChatFrameChannelButton:Hide()
        else
            ChatFrameChannelButton:Show()
        end
    end
end

-- Listener for UI updates that might reset the anchor
hooksecurefunc("ChatEdit_UpdateHeader", function(editBox)
    if addon.db.chatEditBoxPosition then
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
