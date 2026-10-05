---@diagnostic disable: undefined-global
-- Garage UI Tweaks - Raid/Party Frame Centering
local addonName, addon = ...

local centeringEventFrame
local frameState = {}
local refreshQueued = false
local applyingSetPoint = false
local pendingCombatRefresh = false
local editModeHooksInstalled = false

local function DebugPrint(msg)
    if addon.db and addon.db.centerFramesDebug then
        addon:Print("CenterFrames: " .. tostring(msg))
    end
end

local function BoolToText(v)
    return v and "true" or "false"
end

local function FrameName(frame)
    return (frame and frame.GetName and frame:GetName()) or "<unnamed>"
end

local function RelativeName(relativeTo)
    if not relativeTo then
        return "nil"
    end

    if relativeTo == UIParent then
        return "UIParent"
    end

    if relativeTo.GetName then
        local name = relativeTo:GetName()
        if name and name ~= "" then
            return name
        end
    end

    return tostring(relativeTo)
end

local function IsPartyEnabled()
    return addon.db and addon.db.centerPartyFramesEnabled
end

local function IsRaidEnabled()
    return addon.db and addon.db.centerRaidFramesEnabled
end

local function IsAnyEnabled()
    return IsPartyEnabled() or IsRaidEnabled()
end

local function IsEditModeActive()
    if EditModeManagerFrame and EditModeManagerFrame.IsEditModeActive then
        local ok, isActive = pcall(EditModeManagerFrame.IsEditModeActive, EditModeManagerFrame)
        if ok then
            return isActive and true or false
        end
    end

    return EditModeManagerFrame and EditModeManagerFrame.editModeActive and true or false
end

local function GetManagedFrames()
    local frames = {}

    local partyFrame = _G["CompactPartyFrame"]
        or _G["CompactPartyFrameContainer"]
        or _G["PartyFrame"]
    local raidFrame = _G["CompactRaidFrameContainer"]

    if partyFrame then
        frames.party = partyFrame
    end

    if raidFrame then
        frames.raid = raidFrame
    end

    return frames
end

local function NormalizeOffsets(point, x, y, offsetX, offsetY, invert)
    local sign = invert and -1 or 1
    x = x or 0
    y = y or 0

    if point and string.find(point, "LEFT", 1, true) then
        x = x + (sign * offsetX)
    elseif point and string.find(point, "RIGHT", 1, true) then
        x = x - (sign * offsetX)
    end

    if point and string.find(point, "TOP", 1, true) then
        y = y - (sign * offsetY)
    elseif point and string.find(point, "BOTTOM", 1, true) then
        y = y + (sign * offsetY)
    end

    return x, y
end

local function CaptureBaselineSize(key, frame, replace)
    local state = frameState[key] or {}
    local width = frame:GetWidth() or 0
    local height = frame:GetHeight() or 0

    if width > 0 then
        if replace or not state.baselineWidth then
            state.baselineWidth = width
        else
            state.baselineWidth = math.max(state.baselineWidth, width)
        end
    end

    if height > 0 then
        if replace or not state.baselineHeight then
            state.baselineHeight = height
        else
            state.baselineHeight = math.max(state.baselineHeight, height)
        end
    end

    frameState[key] = state
end

local function RestoreSingleAnchor(key, frame)
    local state = frameState[key]
    if not state or not state.basePoint then
        return
    end

    local relativeTo = state.baseRelativeTo
    local relativePoint = state.baseRelativePoint or state.basePoint

    applyingSetPoint = true
    frame:ClearAllPoints()
    frame:SetPoint(state.basePoint, relativeTo, relativePoint, state.baseX or 0, state.baseY or 0)
    applyingSetPoint = false

    state.appliedX = 0
    state.appliedY = 0
end

local function CenterSingleFrame(key, frame)
    if not frame or not frame.GetPoint then
        return
    end

    local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
    if not point then
        return
    end

    local state = frameState[key] or {}

    -- Recover the unadjusted base anchor before calculating a new centering offset.
    local previousAppliedX = state.appliedX or 0
    local previousAppliedY = state.appliedY or 0
    if previousAppliedX ~= 0 or previousAppliedY ~= 0 then
        x, y = NormalizeOffsets(point, x, y, previousAppliedX, previousAppliedY, true)
    end

    state.basePoint = point
    state.baseRelativeTo = relativeTo
    state.baseRelativePoint = relativePoint
    state.baseX = x or 0
    state.baseY = y or 0

    local width = frame:GetWidth() or 0
    local height = frame:GetHeight() or 0
    if width <= 0 or height <= 0 then
        frameState[key] = state
        return
    end

    if not state.baselineWidth then
        state.baselineWidth = width
    end
    if not state.baselineHeight then
        state.baselineHeight = height
    end

    local offsetX = 0
    local offsetY = 0

    if state.baselineWidth and state.baselineWidth > width then
        offsetX = (state.baselineWidth - width) / 2
    end
    if state.baselineHeight and state.baselineHeight > height then
        offsetY = (state.baselineHeight - height) / 2
    end

    local centeredX, centeredY = NormalizeOffsets(point, state.baseX, state.baseY, offsetX, offsetY, false)

    applyingSetPoint = true
    frame:ClearAllPoints()
    frame:SetPoint(point, relativeTo, relativePoint or point, centeredX, centeredY)
    applyingSetPoint = false

    state.appliedX = offsetX
    state.appliedY = offsetY
    frameState[key] = state
end

function addon:QueueRaidPartyFrameCentering()
    if refreshQueued then
        return
    end

    refreshQueued = true
    C_Timer.After(0, function()
        refreshQueued = false
        addon:RefreshRaidPartyFrameCentering()
    end)
end

function addon:RestoreRaidPartyFrameAnchors()
    if InCombatLockdown() then
        pendingCombatRefresh = true
        DebugPrint("Restore delayed due to combat lockdown")
        return
    end

    local frames = GetManagedFrames()
    for key, frame in pairs(frames) do
        if (key == "party" and not IsPartyEnabled()) or (key == "raid" and not IsRaidEnabled()) then
            RestoreSingleAnchor(key, frame)
        end
    end
end

function addon:RefreshRaidPartyFrameCentering()
    if not self.db or not IsAnyEnabled() then
        DebugPrint("Refresh skipped: all center toggles disabled")
        return
    end

    if InCombatLockdown() then
        pendingCombatRefresh = true
        DebugPrint("Refresh delayed due to combat lockdown")
        return
    end

    local inEditMode = IsEditModeActive()
    local frames = GetManagedFrames()

    if inEditMode then
        -- In edit mode, treat current dimensions as the reserved layout area.
        for key, frame in pairs(frames) do
            if (key == "party" and IsPartyEnabled()) or (key == "raid" and IsRaidEnabled()) then
                CaptureBaselineSize(key, frame, true)
                local state = frameState[key]
                DebugPrint(string.format("Captured %s baseline in Edit Mode from %s (%.1fx%.1f)", key, FrameName(frame), state and state.baselineWidth or 0, state and state.baselineHeight or 0))
            end
        end
        return
    end

    for key, frame in pairs(frames) do
        if (key == "party" and IsPartyEnabled()) or (key == "raid" and IsRaidEnabled()) then
            CaptureBaselineSize(key, frame, false)
            CenterSingleFrame(key, frame)
            local state = frameState[key]
            DebugPrint(string.format("Applied %s centering on %s (offsetX=%.1f, offsetY=%.1f)", key, FrameName(frame), state and state.appliedX or 0, state and state.appliedY or 0))
        end
    end
end

local function EnsureHooksOnFrame(key, frame)
    local state = frameState[key] or {}
    if state.hooksInstalled then
        return
    end

    frame:HookScript("OnShow", function()
        addon:QueueRaidPartyFrameCentering()
    end)

    frame:HookScript("OnSizeChanged", function()
        addon:QueueRaidPartyFrameCentering()
    end)

    hooksecurefunc(frame, "SetPoint", function()
        if applyingSetPoint then
            return
        end
        addon:QueueRaidPartyFrameCentering()
    end)

    state.hooksInstalled = true
    frameState[key] = state
end

function addon:EnsureRaidPartyFrameCentering()
    if not centeringEventFrame then
        centeringEventFrame = CreateFrame("Frame")
        centeringEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        centeringEventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
        centeringEventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        centeringEventFrame:RegisterEvent("UI_SCALE_CHANGED")
        centeringEventFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")
        centeringEventFrame:RegisterEvent("CVAR_UPDATE")
        centeringEventFrame:SetScript("OnEvent", function(_, event)
            if event == "PLAYER_REGEN_ENABLED" and pendingCombatRefresh then
                pendingCombatRefresh = false
                addon:QueueRaidPartyFrameCentering()
                return
            end

            if addon.db and IsAnyEnabled() then
                if event == "PLAYER_ENTERING_WORLD" then
                    -- Delay centering after world load so frames finish positioning first
                    C_Timer.After(2, function()
                        if addon.db and IsAnyEnabled() then
                            addon:EnsureRaidPartyFrameCentering()
                            addon:QueueRaidPartyFrameCentering()
                        end
                    end)
                else
                    addon:QueueRaidPartyFrameCentering()
                end
            end
        end)
    end

    local frames = GetManagedFrames()
    for key, frame in pairs(frames) do
        EnsureHooksOnFrame(key, frame)
    end

    if not editModeHooksInstalled and EditModeManagerFrame then
        if EditModeManagerFrame.EnterEditMode then
            hooksecurefunc(EditModeManagerFrame, "EnterEditMode", function()
                addon:QueueRaidPartyFrameCentering()
            end)
        end

        if EditModeManagerFrame.ExitEditMode then
            hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function()
                addon:QueueRaidPartyFrameCentering()
            end)
        end

        editModeHooksInstalled = true
    end
end

function addon:SetRaidPartyFrameCenteringEnabled(enabled)
    self:SetPartyFrameCenteringEnabled(enabled)
    self:SetRaidFrameCenteringEnabled(enabled)
end

function addon:SetPartyFrameCenteringEnabled(enabled)
    if not self.db then
        return
    end

    self.db.centerPartyFramesEnabled = enabled and true or false
    self:EnsureRaidPartyFrameCentering()

    if self.db.centerPartyFramesEnabled then
        DebugPrint("Party centering enabled")
        self:QueueRaidPartyFrameCentering()
    else
        DebugPrint("Party centering disabled")
        self:RestoreRaidPartyFrameAnchors()
    end
end

function addon:SetRaidFrameCenteringEnabled(enabled)
    if not self.db then
        return
    end

    self.db.centerRaidFramesEnabled = enabled and true or false
    self:EnsureRaidPartyFrameCentering()

    if self.db.centerRaidFramesEnabled then
        DebugPrint("Raid centering enabled")
        self:QueueRaidPartyFrameCentering()
    else
        DebugPrint("Raid centering disabled")
        self:RestoreRaidPartyFrameAnchors()
    end
end

function addon:DumpRaidPartyFrameDebug()
    local frames = GetManagedFrames()
    self:Print("CenterFrames debug dump start")
    self:Print(string.format("Toggles: party=%s, raid=%s, any=%s, debug=%s", BoolToText(IsPartyEnabled()), BoolToText(IsRaidEnabled()), BoolToText(IsAnyEnabled()), BoolToText(self.db and self.db.centerFramesDebug)))
    self:Print(string.format("State: editMode=%s, combat=%s", BoolToText(IsEditModeActive()), BoolToText(InCombatLockdown())))

    if not frames.party then
        self:Print("Party frame: not found (checked CompactPartyFrame, CompactPartyFrameContainer, PartyFrame)")
    end
    if not frames.raid then
        self:Print("Raid frame: not found (checked CompactRaidFrameContainer)")
    end

    for key, frame in pairs(frames) do
        local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
        local state = frameState[key]
        self:Print(string.format(
            "%s frame=%s shown=%s size=%.1fx%.1f anchor=%s to %s/%s (%.1f, %.1f)",
            key,
            FrameName(frame),
            BoolToText(frame:IsShown()),
            frame:GetWidth() or 0,
            frame:GetHeight() or 0,
            tostring(point),
            RelativeName(relativeTo),
            tostring(relativePoint),
            x or 0,
            y or 0
        ))

        if state then
            self:Print(string.format(
                "%s state: baseline=%.1fx%.1f appliedOffset=(%.1f, %.1f) baseAnchor=%s to %s/%s (%.1f, %.1f)",
                key,
                state.baselineWidth or 0,
                state.baselineHeight or 0,
                state.appliedX or 0,
                state.appliedY or 0,
                tostring(state.basePoint),
                RelativeName(state.baseRelativeTo),
                tostring(state.baseRelativePoint),
                state.baseX or 0,
                state.baseY or 0
            ))
        else
            self:Print(string.format("%s state: <none>", key))
        end
    end

    self:Print("CenterFrames debug dump end")
end
