---@diagnostic disable: undefined-global
-- Garage UI Tweaks - Shared helpers
local addonName, addon = ...

function addon:Print(...)
    print("|cff00ff00Garage UI Tweaks:|r", ...)
end

-- 12.x hides some values from addons (cooldown times, some names): they can be shown,
-- but not compared or used in math.
function addon.IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value)
end

function addon.DeepCopy(value)
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for key, inner in pairs(value) do
        copy[key] = addon.DeepCopy(inner)
    end
    return copy
end

-- Puts the listed settings back to their defaults (unset, for those without one)
function addon:ResetSettings(keys)
    for _, key in ipairs(keys) do
        self.db[key] = self.DeepCopy(self.defaults[key])
    end
end

function addon:IsEditModeActive()
    return EditModeManagerFrame ~= nil and EditModeManagerFrame.IsEditModeActive ~= nil
        and EditModeManagerFrame:IsEditModeActive() or false
end

-- Returns a function that runs `func` on the next frame, once, however many times it is
-- called before then. For refreshes that several events or hooks can ask for together.
function addon.NextFrameOnce(func)
    local queued = false
    local function Run()
        queued = false
        func()
    end
    return function()
        if not queued then
            queued = true
            C_Timer.After(0, Run)
        end
    end
end

-- SetFont, falling back to `fallback` (default: the game's standard font) when the file
-- won't load. A missing file raises an error on some clients and returns false on others;
-- SetFont returns nothing on success.
function addon.SetFontOrFallback(object, path, size, flags, fallback)
    local ok, result = pcall(object.SetFont, object, path, size, flags)
    if not ok or result == false then
        object:SetFont(fallback or STANDARD_TEXT_FONT, size, flags)
    end
end

-- ============================================================================
-- Saved frame positions
-- ============================================================================
-- Positions are measured from the middle of the screen, so a frame keeps its place
-- relative to the center when the resolution or UI scale changes.

-- Re-anchors `frame` where it is now, holding its `point` (default "CENTER") at an offset
-- from the screen's center. False if the frame has no position yet.
function addon:AnchorToScreenCenter(frame, point)
    point = point or "CENTER"
    local left, bottom, width, height = frame:GetRect()
    if not left then
        return false
    end

    local x, y = left + width / 2, bottom + height / 2
    if point:find("LEFT") then
        x = left
    elseif point:find("RIGHT") then
        x = left + width
    end
    if point:find("TOP") then
        y = bottom + height
    elseif point:find("BOTTOM") then
        y = bottom
    end

    -- The screen's center in the frame's own coordinates; its scale may differ from UIParent's
    local ratio = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
    local centerX, centerY = UIParent:GetCenter()

    frame:ClearAllPoints()
    frame:SetPoint(point, UIParent, "CENTER", x - centerX * ratio, y - centerY * ratio)
    return true
end

function addon:SaveFramePosition(frame, dbKey)
    local point, _, relativePoint, x, y = frame:GetPoint()
    if point then
        self.db[dbKey] = { point = point, relativePoint = relativePoint, xOfs = x, yOfs = y }
    end
end

-- Puts a frame where SaveFramePosition stored it, or at `default` ({ point, x, y } from the
-- screen's center) when nothing is saved. A position saved by an older version, measured
-- from a corner of the screen, is converted and saved again.
function addon:RestoreFramePosition(frame, dbKey, default)
    local pos = self.db[dbKey]
    if pos then
        frame:ClearAllPoints()
        frame:SetPoint(pos.point, UIParent, pos.relativePoint or pos.point, pos.xOfs or pos.x or 0, pos.yOfs or pos.y or 0)
        if pos.relativePoint ~= "CENTER" and self:AnchorToScreenCenter(frame, pos.point) then
            self:SaveFramePosition(frame, dbKey)
        end
    elseif default then
        frame:ClearAllPoints()
        frame:SetPoint(default[1], UIParent, "CENTER", default[2], default[3])
    end
end
