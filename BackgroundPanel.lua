---@diagnostic disable: undefined-global
-- Garage UI Tweaks - Background Panel
-- A plain colored panel to put behind parts of the UI. While unlocked, drag it to move it
-- and drag its corners to resize it. Its position is measured from the screen point chosen
-- as its anchor, and either dimension can be forced to the screen's.
local addonName, addon = ...

local MIN_SIZE = 16
local CORNERS = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }

local panel -- created on first use
local handles = {} -- the corner resize handles

-- Current panel size, honoring the force-width/height options
function addon:GetBackgroundPanelSize()
    local db = self.db
    local width = db.backgroundPanelForceWidth and GetScreenWidth() or db.backgroundPanelWidth
    local height = db.backgroundPanelForceHeight and GetScreenHeight() or db.backgroundPanelHeight
    return width, height
end

-- The panel's size while it is being dragged, or nil
function addon:GetBackgroundPanelDragSize()
    if panel and panel.dragRect then
        return panel.dragRect[3], panel.dragRect[4]
    end
end

local function RefreshSettings()
    if addon.RefreshBackgroundPanelSettings then
        addon:RefreshBackgroundPanelSettings()
    end
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
    local anchor = db.backgroundPanelAnchor
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

        RefreshSettings()
    end)
end

local function StopDrag(f)
    if not f.dragRect then return end
    f:SetScript("OnUpdate", nil)
    SaveRect(unpack(f.dragRect))
    f.dragRect = nil
    addon:UpdateBackgroundPanel()
    RefreshSettings()
end

local function CreateHandle(corner)
    local handle = CreateFrame("Frame", nil, panel)
    handle:SetSize(16, 16)
    handle:SetFrameLevel(panel:GetFrameLevel() + 5)
    handle:SetPoint(corner, panel, corner, 0, 0)
    handle:EnableMouse(true)

    local texture = handle:CreateTexture(nil, "OVERLAY")
    texture:SetAllPoints()
    texture:SetColorTexture(1, 1, 1, 0.5)

    handle:SetScript("OnEnter", function() texture:SetColorTexture(1, 0.8, 0, 0.8) end)
    handle:SetScript("OnLeave", function() texture:SetColorTexture(1, 1, 1, 0.5) end)
    handle:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then StartDrag(panel, corner) end
    end)
    -- Stop the panel's drag, not the handle's
    handle:SetScript("OnMouseUp", function() StopDrag(panel) end)
    return handle
end

local function CreatePanel()
    panel = CreateFrame("Frame", "GarageUITweaksBackgroundPanel", UIParent)
    panel:SetFrameStrata("BACKGROUND")
    panel:SetFrameLevel(0)
    panel:SetClampedToScreen(true)

    panel.texture = panel:CreateTexture(nil, "BACKGROUND")
    panel.texture:SetAllPoints(panel)

    panel:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then StartDrag(self, "MOVE") end
    end)
    panel:SetScript("OnMouseUp", StopDrag)
    panel:SetScript("OnHide", StopDrag)

    for _, corner in ipairs(CORNERS) do
        table.insert(handles, CreateHandle(corner))
    end
end

function addon:UpdateBackgroundPanel()
    local db = self.db

    if not db.backgroundPanelEnabled then
        if panel then
            panel:Hide()
        end
        return
    end

    if not panel then
        CreatePanel()
    end
    panel:Show()

    -- Don't fight an in-progress drag
    if panel.dragRect then return end

    local color = db.backgroundPanelColor
    panel.texture:SetColorTexture(color.r, color.g, color.b, color.a)

    local forceWidth, forceHeight = db.backgroundPanelForceWidth, db.backgroundPanelForceHeight
    local anchor = db.backgroundPanelAnchor
    panel:SetSize(self:GetBackgroundPanelSize())
    panel:ClearAllPoints()
    panel:SetPoint(anchor, UIParent, anchor, forceWidth and 0 or db.backgroundPanelX, forceHeight and 0 or db.backgroundPanelY)

    -- With one dimension forced, dragging and resizing only affect the other
    local movable = not db.backgroundPanelLocked and not (forceWidth and forceHeight)
    panel:EnableMouse(movable)
    for _, handle in ipairs(handles) do
        handle:SetShown(movable)
    end
end

-- The screen size settles after login; forced dimensions follow it when it changes
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("UI_SCALE_CHANGED")
eventFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        C_Timer.After(0.5, function() addon:UpdateBackgroundPanel() end)
    elseif panel then
        addon:UpdateBackgroundPanel()
        RefreshSettings()
    end
end)
