---@diagnostic disable: undefined-global
-- Garage UI Tweaks - Raid and Party Frame Centering
-- Keeps the party and raid frames centered on the area they take up at full size, so they
-- shrink toward the middle as members leave instead of toward their anchored corner. The
-- full size is taken from the frames as Edit Mode shows them, or the largest seen.
local addonName, addon = ...

local state = {} -- per "party" / "raid": base anchor, full size, offset applied, hooks installed
local applyingSetPoint = false
local pendingCombatRefresh = false
local eventFrame
local editModeHooked = false

local function DebugPrint(msg)
    if addon.db.centerFramesDebug then
        addon:Print("Center frames: " .. msg)
    end
end

local function IsEnabled(key)
    return (key == "party" and addon.db.centerPartyFramesEnabled) or (key == "raid" and addon.db.centerRaidFramesEnabled)
end

local function IsAnyEnabled()
    return addon.db.centerPartyFramesEnabled or addon.db.centerRaidFramesEnabled
end

local function GetManagedFrames()
    return {
        party = CompactPartyFrame or CompactPartyFrameContainer or PartyFrame,
        raid = CompactRaidFrameContainer,
    }
end

local function GetState(key)
    state[key] = state[key] or {}
    return state[key]
end

local function FrameName(frame)
    return (frame and frame.GetName and frame:GetName()) or "<unnamed>"
end

-- Moves an anchor offset toward (or, inverted, away from) the frame's middle
local function ShiftOffsets(point, x, y, shiftX, shiftY, invert)
    local sign = invert and -1 or 1
    x, y = x or 0, y or 0

    if point:find("LEFT") then
        x = x + sign * shiftX
    elseif point:find("RIGHT") then
        x = x - sign * shiftX
    end
    if point:find("TOP") then
        y = y - sign * shiftY
    elseif point:find("BOTTOM") then
        y = y + sign * shiftY
    end
    return x, y
end

local function SetAnchor(frame, point, relativeTo, relativePoint, x, y)
    applyingSetPoint = true
    frame:ClearAllPoints()
    frame:SetPoint(point, relativeTo, relativePoint, x, y)
    applyingSetPoint = false
end

-- Remembers the frame's size as its full size: as it is (replace), or the largest seen
local function CaptureFullSize(key, frame, replace)
    local frameState = GetState(key)
    local width, height = frame:GetWidth() or 0, frame:GetHeight() or 0

    if width > 0 then
        frameState.fullWidth = (replace or not frameState.fullWidth) and width or math.max(frameState.fullWidth, width)
    end
    if height > 0 then
        frameState.fullHeight = (replace or not frameState.fullHeight) and height or math.max(frameState.fullHeight, height)
    end
end

local function RestoreAnchor(key, frame)
    local frameState = state[key]
    if not frameState or not frameState.basePoint then
        return
    end

    SetAnchor(frame, frameState.basePoint, frameState.baseRelativeTo, frameState.baseRelativePoint or frameState.basePoint,
        frameState.baseX or 0, frameState.baseY or 0)
    frameState.appliedX, frameState.appliedY = 0, 0
end

local function CenterFrame(key, frame)
    local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
    if not point then
        return
    end

    local frameState = GetState(key)

    -- Take back the offset applied last time to recover Blizzard's anchor
    local appliedX, appliedY = frameState.appliedX or 0, frameState.appliedY or 0
    if appliedX ~= 0 or appliedY ~= 0 then
        x, y = ShiftOffsets(point, x, y, appliedX, appliedY, true)
    end

    frameState.basePoint = point
    frameState.baseRelativeTo = relativeTo
    frameState.baseRelativePoint = relativePoint
    frameState.baseX = x or 0
    frameState.baseY = y or 0

    local width, height = frame:GetWidth() or 0, frame:GetHeight() or 0
    if width <= 0 or height <= 0 then
        return
    end

    frameState.fullWidth = frameState.fullWidth or width
    frameState.fullHeight = frameState.fullHeight or height

    local offsetX = math.max(0, (frameState.fullWidth - width) / 2)
    local offsetY = math.max(0, (frameState.fullHeight - height) / 2)
    local centeredX, centeredY = ShiftOffsets(point, frameState.baseX, frameState.baseY, offsetX, offsetY, false)

    SetAnchor(frame, point, relativeTo, relativePoint or point, centeredX, centeredY)
    frameState.appliedX, frameState.appliedY = offsetX, offsetY
end

local QueueRefresh -- defined below; the hooks call it

-- Blizzard moves and resizes these frames as the group changes; re-center afterwards.
-- Frames such as CompactPartyFrame are created later, so this runs on every refresh.
local function HookFrames()
    for key, frame in pairs(GetManagedFrames()) do
        local frameState = GetState(key)
        if not frameState.hooked then
            frame:HookScript("OnShow", QueueRefresh)
            frame:HookScript("OnSizeChanged", QueueRefresh)
            hooksecurefunc(frame, "SetPoint", function()
                if not applyingSetPoint then
                    QueueRefresh()
                end
            end)
            frameState.hooked = true
        end
    end
end

local function Refresh()
    if not IsAnyEnabled() then
        return
    end

    if InCombatLockdown() then
        pendingCombatRefresh = true
        DebugPrint("refresh waits for the end of combat")
        return
    end

    HookFrames()

    -- In Edit Mode the frames show at full size: take that as the area to center in
    local inEditMode = addon:IsEditModeActive()
    for key, frame in pairs(GetManagedFrames()) do
        if IsEnabled(key) then
            CaptureFullSize(key, frame, inEditMode)
            local frameState = state[key]
            if inEditMode then
                DebugPrint(string.format("captured %s full size in Edit Mode from %s (%.1fx%.1f)", key, FrameName(frame),
                    frameState.fullWidth or 0, frameState.fullHeight or 0))
            else
                CenterFrame(key, frame)
                DebugPrint(string.format("centered %s on %s (offset %.1f, %.1f)", key, FrameName(frame),
                    frameState.appliedX or 0, frameState.appliedY or 0))
            end
        end
    end
end

QueueRefresh = addon.NextFrameOnce(Refresh)

-- Puts back Blizzard's anchor on any frame whose centering is off
local function RestoreDisabled()
    if InCombatLockdown() then
        pendingCombatRefresh = true
        return
    end

    for key, frame in pairs(GetManagedFrames()) do
        if not IsEnabled(key) then
            RestoreAnchor(key, frame)
        end
    end
end

local function OnEvent(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if pendingCombatRefresh then
            pendingCombatRefresh = false
            RestoreDisabled()
            QueueRefresh()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Give the frames time to finish positioning after a loading screen
        C_Timer.After(2, QueueRefresh)
    else
        QueueRefresh()
    end
end

function addon:UpdateRaidPartyFrameCentering()
    RestoreDisabled()
    if not IsAnyEnabled() then
        return
    end

    if not eventFrame then
        eventFrame = CreateFrame("Frame")
        for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED", "UI_SCALE_CHANGED",
                                 "DISPLAY_SIZE_CHANGED", "CVAR_UPDATE" }) do
            eventFrame:RegisterEvent(event)
        end
        eventFrame:SetScript("OnEvent", OnEvent)
    end

    -- Entering Edit Mode shows the frames at full size; leaving it shrinks them again
    if not editModeHooked and EditModeManagerFrame and EditModeManagerFrame.EnterEditMode then
        hooksecurefunc(EditModeManagerFrame, "EnterEditMode", QueueRefresh)
        hooksecurefunc(EditModeManagerFrame, "ExitEditMode", QueueRefresh)
        editModeHooked = true
    end

    HookFrames()
    QueueRefresh()
end

-- /guit debug
function addon:DumpRaidPartyFrameDebug()
    local function Bool(value)
        return value and "true" or "false"
    end
    local function RelativeName(relativeTo)
        if not relativeTo then
            return "nil"
        end
        local name = relativeTo.GetName and relativeTo:GetName()
        return (name and name ~= "") and name or tostring(relativeTo)
    end

    local frames = GetManagedFrames()
    self:Print(string.format("Center frames: party=%s, raid=%s, debug=%s, editMode=%s, combat=%s",
        Bool(self.db.centerPartyFramesEnabled), Bool(self.db.centerRaidFramesEnabled), Bool(self.db.centerFramesDebug),
        Bool(self:IsEditModeActive()), Bool(InCombatLockdown())))

    if not frames.party then
        self:Print("party frame: not found (checked CompactPartyFrame, CompactPartyFrameContainer, PartyFrame)")
    end
    if not frames.raid then
        self:Print("raid frame: not found (checked CompactRaidFrameContainer)")
    end

    for key, frame in pairs(frames) do
        local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
        self:Print(string.format("%s: %s shown=%s size=%.1fx%.1f anchor=%s to %s/%s (%.1f, %.1f)",
            key, FrameName(frame), Bool(frame:IsShown()), frame:GetWidth() or 0, frame:GetHeight() or 0,
            tostring(point), RelativeName(relativeTo), tostring(relativePoint), x or 0, y or 0))

        local frameState = state[key]
        if frameState then
            self:Print(string.format("%s state: full size=%.1fx%.1f offset=(%.1f, %.1f) base anchor=%s to %s/%s (%.1f, %.1f)",
                key, frameState.fullWidth or 0, frameState.fullHeight or 0, frameState.appliedX or 0, frameState.appliedY or 0,
                tostring(frameState.basePoint), RelativeName(frameState.baseRelativeTo), tostring(frameState.baseRelativePoint),
                frameState.baseX or 0, frameState.baseY or 0))
        else
            self:Print(key .. " state: none")
        end
    end
end
