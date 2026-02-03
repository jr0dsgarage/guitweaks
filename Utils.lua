---@diagnostic disable: undefined-global
-- Garage UI Tweaks - Utilities
local addonName, addon = ...

-- ============================================================================
-- Debugging & Printing
-- ============================================================================

function addon:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[GarageT]|r " .. tostring(msg))
end

function addon:Debug(msg)
    -- We can expand this to a global debug setting later if needed
    -- For now, individual modules might guard calls to this, or we rely on specific flags
    if self.db.debug then
        self:Print("|cffff0000DEBUG:|r " .. tostring(msg))
    end
end

-- ============================================================================
-- CVar Management
-- ============================================================================

-- Sets a CVar only if the value is different, to avoid potential event spam or processing overhead
function addon:SetCVar(cvar, value)
    local current = C_CVar.GetCVar(cvar)
    -- Convert numbers to strings for comparison if needed, though GetCVar usually returns string
    if tostring(current) ~= tostring(value) then
        C_CVar.SetCVar(cvar, value)
        return true -- Value changed
    end
    return false -- No change needed
end

-- ============================================================================
-- Frame Positioning
-- ============================================================================

function addon:SaveFramePosition(frame, dbKey)
    if not frame or not self.db then return end
    
    local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()
    if not point then return end

    self.db[dbKey] = {
        point = point,
        relativePoint = relativePoint,
        xOfs = xOfs,
        yOfs = yOfs,
        relative = (relativeTo and relativeTo:GetName()) or "UIParent"
    }
end

function addon:RestoreFramePosition(frame, dbKey, defaultAnchor)
    if not frame then return end
    
    frame:ClearAllPoints()
    
    local pos = self.db and self.db[dbKey]
    if pos and pos.point then
        local relative = UIParent
        if pos.relative and _G[pos.relative] then
            relative = _G[pos.relative]
        end
        -- Fallback to UIParent if named relative frame makes no sense or doesn't exist
        if not relative then relative = UIParent end
        
        frame:SetPoint(pos.point, relative, pos.relativePoint or pos.point, pos.x or 0, pos.y or 0)
    else
        if defaultAnchor then
            frame:SetPoint(unpack(defaultAnchor))
        else
            frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
    end
end

-- ============================================================================
-- Texture/Backdrop Helpers
-- ============================================================================

-- Helper to ensure a frame has a valid backdrop structure 
-- (mostly for reusing common styles)
function addon:ApplyBackdrop(frame, style)
    if not frame.SetBackdrop then
        Mixin(frame, BackdropTemplateMixin)
    end
    
    if style == "chat" then
        frame:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        frame:SetBackdropColor(0.1, 0.1, 0.1, 0.4)
        frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
    elseif style == "dialog" then
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
    elseif style == "tooltip" then
        frame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        frame:SetBackdropColor(0, 0, 0, 1)
    end
end
