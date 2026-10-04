local addonName, addon = ...

local MIN_SIZE = 16

-- Current panel size, honoring the force-width/height options
function addon:GetBackgroundPanelSize()
    local db = addon.db
    local w = db.backgroundPanelForceWidth and GetScreenWidth() or (db.backgroundPanelWidth or 400)
    local h = db.backgroundPanelForceHeight and GetScreenHeight() or (db.backgroundPanelHeight or 100)
    return w, h
end

local function GetCursorUI()
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    return x / scale, y / scale
end

local function Clamp(v, lo, hi)
    if hi < lo then return lo end
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- Convert an absolute rect (UIParent coords) into anchor-relative offsets and save it
local function SaveRect(left, bottom, width, height)
    local db = addon.db
    local anchor = db.backgroundPanelAnchor or "CENTER"
    local screenWidth, screenHeight = GetScreenWidth(), GetScreenHeight()
    local right, top = left + width, bottom + height
    local centerX, centerY = left + width / 2, bottom + height / 2

    local x, y
    if anchor:find("LEFT") then
        x = left
    elseif anchor:find("RIGHT") then
        x = right - screenWidth
    else
        x = centerX - screenWidth / 2
    end
    if anchor:find("TOP") then
        y = top - screenHeight
    elseif anchor:find("BOTTOM") then
        y = bottom
    else
        y = centerY - screenHeight / 2
    end

    -- Forced dimensions keep the user's manual values for when the option is turned off
    if not db.backgroundPanelForceWidth then
        db.backgroundPanelX = math.floor(x + 0.5)
        db.backgroundPanelWidth = math.floor(width + 0.5)
    end
    if not db.backgroundPanelForceHeight then
        db.backgroundPanelY = math.floor(y + 0.5)
        db.backgroundPanelHeight = math.floor(height + 0.5)
    end
end

-- Drag handling: mode is "MOVE" or a corner name
local function StartDrag(f, mode)
    local db = addon.db
    if db.backgroundPanelLocked then return end
    local left, bottom = f:GetLeft(), f:GetBottom()
    if not left or not bottom then return end

    local cx, cy = GetCursorUI()
    local start = {
        cx = cx, cy = cy,
        left = left, bottom = bottom,
        width = f:GetWidth(), height = f:GetHeight(),
    }
    local lockX, lockY = db.backgroundPanelForceWidth, db.backgroundPanelForceHeight

    f.dragRect = { left, bottom, start.width, start.height }
    f:SetScript("OnUpdate", function(self)
        local x, y = GetCursorUI()
        local dx = lockX and 0 or (x - start.cx)
        local dy = lockY and 0 or (y - start.cy)
        local sw, sh = GetScreenWidth(), GetScreenHeight()
        local l, b, w, h = start.left, start.bottom, start.width, start.height

        if mode == "MOVE" then
            l = Clamp(l + dx, 0, sw - w)
            b = Clamp(b + dy, 0, sh - h)
        else
            if mode:find("LEFT") then
                local r = l + w
                l = Clamp(l + dx, 0, r - MIN_SIZE)
                w = r - l
            elseif mode:find("RIGHT") then
                w = Clamp(w + dx, MIN_SIZE, sw - l)
            end
            if mode:find("BOTTOM") then
                local t = b + h
                b = Clamp(b + dy, 0, t - MIN_SIZE)
                h = t - b
            elseif mode:find("TOP") then
                h = Clamp(h + dy, MIN_SIZE, sh - b)
            end
        end

        self:ClearAllPoints()
        self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l, b)
        self:SetSize(w, h)
        self.dragRect = { l, b, w, h }

        if addon.RefreshSettings then addon:RefreshSettings("background") end
    end)
end

local function StopDrag(f)
    if not f.dragRect then return end
    f:SetScript("OnUpdate", nil)
    SaveRect(unpack(f.dragRect))
    f.dragRect = nil
    addon:UpdateBackgroundPanel()
    if addon.RefreshSettings then addon:RefreshSettings("background") end
end

function addon:UpdateBackgroundPanel()
    local db = addon.db

    if not addon.backgroundPanel then
        local f = CreateFrame("Frame", "GarageUITweaksBackgroundPanel", UIParent)
        f:SetFrameStrata("BACKGROUND")
        f:SetFrameLevel(0)
        f:SetClampedToScreen(true)

        f.texture = f:CreateTexture(nil, "BACKGROUND")
        f.texture:SetAllPoints(f)

        f:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" then StartDrag(self, "MOVE") end
        end)
        f:SetScript("OnMouseUp", StopDrag)
        f:SetScript("OnHide", StopDrag)

        addon.backgroundPanel = f

        addon.backgroundHandles = {}
        for _, corner in ipairs({"TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT"}) do
            local h = CreateFrame("Frame", nil, f)
            h:SetSize(16, 16)
            h:SetFrameLevel(f:GetFrameLevel() + 5)
            h.texture = h:CreateTexture(nil, "OVERLAY")
            h.texture:SetAllPoints()
            h.texture:SetColorTexture(1, 1, 1, 0.5)

            h:SetPoint(corner, f, corner, 0, 0)
            h:EnableMouse(true)
            h:SetScript("OnEnter", function() h.texture:SetColorTexture(1, 0.8, 0, 0.8) end)
            h:SetScript("OnLeave", function() h.texture:SetColorTexture(1, 1, 1, 0.5) end)
            h:SetScript("OnMouseDown", function(_, button)
                if button == "LeftButton" then StartDrag(f, corner) end
            end)
            -- Stop the panel's drag, not the handle's
            h:SetScript("OnMouseUp", function() StopDrag(f) end)

            table.insert(addon.backgroundHandles, h)
        end
    end

    local f = addon.backgroundPanel

    if not db.backgroundPanelEnabled then
        f:Hide()
        return
    end
    f:Show()

    -- Don't fight an in-progress drag
    if f.dragRect then return end

    local c = db.backgroundPanelColor
    f.texture:SetColorTexture(c.r, c.g, c.b, c.a)

    local forceW, forceH = db.backgroundPanelForceWidth, db.backgroundPanelForceHeight
    local anchor = db.backgroundPanelAnchor or "CENTER"
    f:SetSize(addon:GetBackgroundPanelSize())
    f:ClearAllPoints()
    f:SetPoint(anchor, UIParent, anchor,
        forceW and 0 or (db.backgroundPanelX or 0),
        forceH and 0 or (db.backgroundPanelY or 0))

    local fullyForced = forceW and forceH
    if db.backgroundPanelLocked then
        f:EnableMouse(false)
        for _, h in pairs(addon.backgroundHandles) do h:Hide() end
    else
        -- With one dimension forced, dragging/resizing only affects the other axis
        f:EnableMouse(not fullyForced)
        for _, h in pairs(addon.backgroundHandles) do h:SetShown(not fullyForced) end
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("UI_SCALE_CHANGED")
eventFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        C_Timer.After(0.5, function()
            if addon.db.backgroundPanelEnabled then
                addon:UpdateBackgroundPanel()
            end
        end)
    elseif addon.backgroundPanel then
        -- Screen size changed; re-apply forced dimensions
        addon:UpdateBackgroundPanel()
        if addon.RefreshSettings then addon:RefreshSettings("background") end
    end
end)
