local addonName, addon = ...

-- Helper to create the main panel
function addon:UpdateBackgroundPanel()
    local db = addon.db
    
    -- Create frame if it doesn't exist
    if not addon.backgroundPanel then
        local f = CreateFrame("Frame", "GarageUITweaksBackgroundPanel", UIParent)
        f:SetFrameStrata("BACKGROUND")
        f:SetFrameLevel(0)
        
        -- Background texture
        f.texture = f:CreateTexture(nil, "BACKGROUND")
        f.texture:SetAllPoints(f)
        
        -- Mover/Resizer functionality
        f:SetMovable(true)
        f:SetClampedToScreen(true)
        f:SetResizable(true)
        f:SetUserPlaced(false) -- We manage position manually via DB
        
        -- Helper to calculate relative position based on anchor
        local function SavePosition(self)
            self:StopMovingOrSizing()
            
            local anchor = db.backgroundPanelAnchor or "CENTER"
            local screenWidth, screenHeight = GetScreenWidth(), GetScreenHeight()
            -- local uiScale = UIParent:GetScale() -- GetScreenWidth/Height is already effective screen size usually in modern clients for layout purposes relative to UIParent
            
            local left, bottom, width, height = self:GetLeft(), self:GetBottom(), self:GetWidth(), self:GetHeight()
            if not left or not bottom then return end
            
            local centerX, centerY = left + (width / 2), bottom + (height / 2)
            
            local x, y = 0, 0
            
            if anchor == "CENTER" then
                x = centerX - (screenWidth / 2)
                y = centerY - (screenHeight / 2)
            elseif anchor == "TOPLEFT" then
                x = left
                y = (bottom + height) - screenHeight
            elseif anchor == "TOP" then
                x = centerX - (screenWidth / 2)
                y = (bottom + height) - screenHeight
            elseif anchor == "TOPRIGHT" then
                x = (left + width) - screenWidth
                y = (bottom + height) - screenHeight
            elseif anchor == "LEFT" then
                x = left
                y = centerY - (screenHeight / 2)
            elseif anchor == "RIGHT" then
                x = (left + width) - screenWidth
                y = centerY - (screenHeight / 2)
            elseif anchor == "BOTTOMLEFT" then
                x = left
                y = bottom
            elseif anchor == "BOTTOM" then
                x = centerX - (screenWidth / 2)
                y = bottom
            elseif anchor == "BOTTOMRIGHT" then
                x = (left + width) - screenWidth
                y = bottom
            end
            
            db.backgroundPanelX = x
            db.backgroundPanelY = y
            db.backgroundPanelWidth = width
            db.backgroundPanelHeight = height
            
            if addon.RefreshSettings then addon:RefreshSettings("background") end
            
            -- Re-apply set point to ensure it sticks to the anchor
            addon:UpdateBackgroundPanel()
        end

        -- Main drag behavior (Center)
        f:SetScript("OnMouseDown", function(self, button)
            if not db.backgroundPanelLocked and button == "LeftButton" then
                self:StartMoving()
            end
        end)
        f:SetScript("OnMouseUp", SavePosition)
        
        addon.backgroundPanel = f
        
        -- Create corner handles
        addon.backgroundHandles = {}
        local corners = {"TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT"}
        for _, corner in ipairs(corners) do
            local h = CreateFrame("Frame", nil, f)
            h:SetSize(16, 16)
            h:SetFrameLevel(f:GetFrameLevel() + 5)
            h.texture = h:CreateTexture(nil, "OVERLAY")
            h.texture:SetAllPoints()
            h.texture:SetColorTexture(1, 1, 1, 0.5) -- Visible handle
            
            h:SetPoint(corner, f, corner, 0, 0)
            h:EnableMouse(true)
            h:SetScript("OnEnter", function() h.texture:SetColorTexture(1, 0.8, 0, 0.8) end)
            h:SetScript("OnLeave", function() h.texture:SetColorTexture(1, 1, 1, 0.5) end)
            
            h:SetScript("OnMouseDown", function(self)
                if not db.backgroundPanelLocked then
                    f:StartSizing(corner)
                end
            end)
            
            h:SetScript("OnMouseUp", SavePosition)
            
            table.insert(addon.backgroundHandles, h)
        end
    end
    
    local f = addon.backgroundPanel
    
    -- Visibility
    if not db.backgroundPanelEnabled then
        f:Hide()
        return
    end
    f:Show()
    
    -- Color
    local c = db.backgroundPanelColor
    f.texture:SetColorTexture(c.r, c.g, c.b, c.a)
    
    -- Size and Position
    local anchor = db.backgroundPanelAnchor or "CENTER"
    if db.backgroundPanelForceWidth then
        f:SetWidth(GetScreenWidth())
        f:ClearAllPoints()
        
        -- If forced width, typically we anchor to a vertical position (TOP, CENTER, BOTTOM)
        -- We will infer vertical anchor from the main anchor.
        local vertAnchor = "BOTTOM"
        if anchor:find("TOP") then vertAnchor = "TOP"
        elseif anchor:find("BOTTOM") then vertAnchor = "BOTTOM"
        else vertAnchor = "CENTER" end
        
        f:SetPoint(vertAnchor, UIParent, vertAnchor, 0, db.backgroundPanelY or 0)
    else
        f:SetWidth(db.backgroundPanelWidth or 200)
        f:ClearAllPoints()
        f:SetPoint(anchor, UIParent, anchor, db.backgroundPanelX or 0, db.backgroundPanelY or 0)
    end
    
    -- We set Height separate as it applies in both cases
    f:SetHeight(db.backgroundPanelHeight or 100)
    
    -- Locked State
    if db.backgroundPanelLocked then
        f:EnableMouse(false)
        for _, h in pairs(addon.backgroundHandles) do h:Hide() end
    else
        f:EnableMouse(not db.backgroundPanelForceWidth) -- If full width, dragging main frame might be weird, maybe only allow vertical?
        -- For simplicity, if forced width, we disable main dragging (assume user wants it centered/full) 
        -- or we allow dragging Y only? "StartMoving" is usually omni.
        -- Let's just disable main dragging if forced width for now to prevent mishaps
        if db.backgroundPanelForceWidth then
             f:EnableMouse(false) -- Can't drag body
        end
        
        for _, h in pairs(addon.backgroundHandles) do 
            if db.backgroundPanelForceWidth then
                h:Hide() -- Hide resize handles if force width is on
            else
                h:Show() 
            end
        end
    end
end

-- Hook into initialization
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function()
    C_Timer.After(0.5, function()
        if addon.db.backgroundPanelEnabled then
            addon:UpdateBackgroundPanel()
        end
    end)
end)
