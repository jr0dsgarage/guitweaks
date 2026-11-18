---@diagnostic disable: undefined-global
-- Garage UI Tweaks - Friendly Nameplates
-- Draws friendly players' names (with their title and guild, if chosen) above their
-- simplified nameplates, resizes friendly players' plates, and keeps Blizzard's
-- class-color option for friendly names in step with the setting here.
--
-- Friendly plates are off limits to addons inside dungeons, raids and scenarios, so the
-- names can't appear there. An option switches the simplified style off for friendly
-- players inside those instead, so Blizzard's full plates show.
local addonName, addon = ...

local CLASS_COLOR_CVAR = "nameplateUseClassColorForFriendlyPlayerUnitNames"
local SIMPLIFIED_TYPES_CVAR = "nameplateSimplifiedTypes"
local RESTRICTED_INSTANCE_TYPES = { party = true, raid = true, scenario = true }
local OUTLINE_FLAGS = { OUTLINE = "OUTLINE", THICKOUTLINE = "THICKOUTLINE" } -- NONE: no flags
local LINE_SPACING = 2
local GUILD_FONT_SCALE = 0.85

-- The name, title and guild lines of each plate, by the frame they hang off
local nameLines = setmetatable({}, { __mode = "k" })
local scaleUsed = false -- set once any plate has been resized
local eventFrame

local function IsFriendlyPlayerUnit(unit)
    if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then
        return false
    end

    if UnitInParty(unit) or UnitInRaid(unit) then
        return true
    end

    local reaction = UnitReaction(unit, "player")
    return reaction and reaction > 4 or false
end

local function IsTarget(unit)
    return UnitExists("target") and UnitIsUnit(unit, "target")
end

local function GetPlateUnit(plate)
    if plate.unit and UnitExists(plate.unit) then
        return plate.unit
    end
    if plate.namePlateUnitToken and UnitExists(plate.namePlateUnitToken) then
        return plate.namePlateUnitToken
    end
    if plate.UnitFrame and plate.UnitFrame.unit and UnitExists(plate.UnitFrame.unit) then
        return plate.UnitFrame.unit
    end

    for i = 1, 40 do
        local token = "nameplate" .. i
        if C_NamePlate.GetNamePlateForUnit(token) == plate and UnitExists(token) then
            return token
        end
    end

    return plate.namePlateUnitToken or plate.unit or (plate.UnitFrame and plate.UnitFrame.unit)
end

local function IsClassColorEnabled()
    local value = C_CVar.GetCVar(CLASS_COLOR_CVAR)
    if value == nil then
        return addon.db.nameplateUseClassColorForFriendlyPlayerUnitNames
    end
    return value == "1"
end

local function GetNameColor(unit)
    if IsClassColorEnabled() then
        local _, classFile = UnitClass(unit)
        local classColor = classFile and RAID_CLASS_COLORS[classFile]
        if classColor then
            return classColor.r, classColor.g, classColor.b, 1
        end
    end

    local color = addon.db.nameplateFriendlyNameColor
    return color.r, color.g, color.b, color.a or 1
end

-- The frame the lines hang off: the health bar where there is one
local function GetNameAnchor(plate)
    local unitFrame = plate.UnitFrame
    if not unitFrame then
        return plate
    end
    local container = unitFrame.HealthBarsContainer
    return (container and (container.healthBar or container)) or unitFrame
end

local function CreateNameLine(anchor)
    local line = anchor:CreateFontString(nil, "OVERLAY")
    line:SetDrawLayer("OVERLAY", 7)
    line:SetWordWrap(false)
    line:SetMaxLines(1)
    line:SetShadowOffset(1, -1)
    line:SetShadowColor(0, 0, 0, 1)
    return line
end

local function GetNameLines(plate)
    local anchor = GetNameAnchor(plate)
    local lines = nameLines[anchor]
    if not lines then
        lines = { name = CreateNameLine(anchor), title = CreateNameLine(anchor), guild = CreateNameLine(anchor) }
        nameLines[anchor] = lines
    end
    return lines, anchor
end

local function HideLines(lines)
    lines.name:Hide()
    lines.title:Hide()
    lines.guild:Hide()
end

-- Stacks a line on top of `below`, or on the plate itself when `below` is the anchor frame
local function PlaceLine(line, below, isAnchor, justify, offsetX, offsetY, spacing)
    line:SetWidth(0)
    line:SetJustifyH(justify)
    line:ClearAllPoints()
    if not isAnchor then
        offsetX, offsetY = 0, spacing
    end
    if justify == "LEFT" then
        line:SetPoint("BOTTOMLEFT", below, "TOPLEFT", offsetX, offsetY)
    elseif justify == "RIGHT" then
        line:SetPoint("BOTTOMRIGHT", below, "TOPRIGHT", offsetX, offsetY)
    else
        line:SetPoint("BOTTOM", below, "TOP", offsetX, offsetY)
    end
end

-- Sets a line's text; a font that draws nothing for it falls back to the standard one
local function SetLineText(line, text, fontSize, fontFlags)
    line:SetText(text)
    if (line:GetStringWidth() or 0) <= 0 then
        line:SetFont(STANDARD_TEXT_FONT, fontSize, fontFlags)
        line:SetText(text)
    end
end

-- The name split into the line under the plate's title and the line above it, when the
-- title is shown: a title before the name goes above it, one after goes below
local function GetNameAndTitle(unit)
    if not addon.db.nameplateFriendlyNamesShowTitle then
        return GetUnitName(unit, false) or UnitName(unit), nil
    end

    local baseName = GetUnitName(unit, false) or ""
    local bottomText, topText = baseName, nil
    if baseName == "" then
        return bottomText, topText
    end

    -- The names may be secret values on 12.x, which can't be searched
    local ok = pcall(function()
        local pvpName = UnitPVPName(unit, baseName)
        if not pvpName or pvpName == "" then
            return
        end

        local first, last = string.find(pvpName, baseName, 1, true)
        if not first then
            bottomText = pvpName
            return
        end

        local title
        if first > 1 then
            title = string.match(string.sub(pvpName, 1, first - 1), "^[%s,]*(.-)[%s,]*$")
            if title and title ~= "" then
                topText, bottomText = title, baseName
            end
        elseif last < #pvpName then
            title = string.match(string.sub(pvpName, last + 1), "^[%s,]*(.-)[%s,]*$")
            if title and title ~= "" then
                topText, bottomText = baseName, title
            end
        end
    end)

    if not ok then
        return baseName, nil
    end
    return bottomText, topText
end

-- Resizes friendly players' plates by scaling the unit frame inside the plate. The plate
-- itself is sized by the game engine, which is why Blizzard's own scale setting can't be
-- tuned from here. Returns the scale in effect.
local function ApplyPlateScale(plate, unit)
    local unitFrame = plate.UnitFrame
    if not unitFrame or (unitFrame.IsForbidden and unitFrame:IsForbidden()) then
        return 1
    end

    local scale = 1
    -- Your target keeps Blizzard's normal size, whichever way the others are scaled
    if unit and IsFriendlyPlayerUnit(unit) and not IsTarget(unit) then
        scale = addon.db.nameplateFriendlyScale
    end

    -- Plates are recycled between units, so once any plate has been resized every plate
    -- must be set, including back to 1. Until then, leave Blizzard's frames untouched.
    if scale ~= 1 then
        scaleUsed = true
    end
    if not scaleUsed then
        return 1
    end

    unitFrame:SetScale(scale)

    -- Blizzard pins the unit frame to all four edges of the plate, so scaling alone only
    -- makes its contents taller. Give it the plate's own size instead, so the scale applies
    -- to the width too, growing sideways and upward from the plate's bottom edge.
    local width, height
    if scale ~= 1 and C_NamePlate.GetNamePlateSize then
        width, height = C_NamePlate.GetNamePlateSize()
    end

    unitFrame:ClearAllPoints()
    if width and height and width > 0 and height > 0 then
        unitFrame:SetPoint("BOTTOM", plate, "BOTTOM", 0, 0)
        unitFrame:SetSize(width, height)
    else
        unitFrame:SetAllPoints(plate)
    end

    return scale
end

local function ApplyToPlate(plate)
    local db = addon.db
    local lines, anchor = GetNameLines(plate)

    local unit = GetPlateUnit(plate)
    local plateScale = ApplyPlateScale(plate, unit)
    if not unit or not db.nameplateFriendlyNamesEnabled or not IsFriendlyPlayerUnit(unit) or IsTarget(unit) then
        HideLines(lines)
        return
    end

    local bottomText, topText = GetNameAndTitle(unit)
    if not bottomText or bottomText == "" then
        HideLines(lines)
        return
    end

    -- The guild name may be a secret value on 12.x, which can be shown but not compared
    local guildName
    if db.nameplateFriendlyNamesShowGuild then
        guildName = GetGuildInfo(unit)
        if guildName and not addon.IsSecret(guildName) and guildName == "" then
            guildName = nil
        end
    end

    -- The lines are children of the scaled unit frame; divide so they keep their real size
    local fontPath = db.nameplateFriendlyNameFont
    local fontSize = db.nameplateFriendlyNameSize / plateScale
    local fontFlags = OUTLINE_FLAGS[db.nameplateFriendlyNameOutline]
    local justify = db.nameplateFriendlyNameJustify
    local offsetX = db.nameplateFriendlyNameOffsetX / plateScale
    local offsetY = db.nameplateFriendlyNameOffsetY / plateScale
    local spacing = LINE_SPACING / plateScale
    local r, g, b, a = GetNameColor(unit)

    -- Lines stack upward from the plate: guild, then name, then title. The guild sits
    -- lowest so it reads as underneath the name while everything stays above the plate.
    local below, belowIsAnchor = anchor, true

    if guildName then
        local guild = lines.guild
        addon.SetFontOrFallback(guild, fontPath, math.max(8, fontSize * GUILD_FONT_SCALE), fontFlags)
        PlaceLine(guild, below, belowIsAnchor, justify, offsetX, offsetY, spacing)
        guild:SetTextColor(r, g, b, a)
        guild:SetFormattedText("<%s>", guildName)
        guild:Show()
        below, belowIsAnchor = guild, false
    else
        lines.guild:Hide()
    end

    local name = lines.name
    addon.SetFontOrFallback(name, fontPath, fontSize, fontFlags)
    PlaceLine(name, below, belowIsAnchor, justify, offsetX, offsetY, spacing)
    name:SetTextColor(r, g, b, a)
    SetLineText(name, bottomText, fontSize, fontFlags)
    name:Show()

    local title = lines.title
    if topText then
        addon.SetFontOrFallback(title, fontPath, fontSize, fontFlags)
        PlaceLine(title, name, false, justify, offsetX, offsetY, spacing)
        title:SetTextColor(r, g, b, a)
        SetLineText(title, topText, fontSize, fontFlags)
        title:Show()
    else
        title:Hide()
    end
end

local function RefreshUnit(unit)
    -- GetNamePlateForUnit refuses these tokens
    if unit:match("^boss%d*$") or unit:match("^party%d+$") or unit:match("^raid%d+$") then
        return
    end

    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if ok and plate then
        ApplyToPlate(plate)
    end
end

local function OnEvent(_, event, arg1)
    if event == "NAME_PLATE_UNIT_ADDED" or event == "UNIT_NAME_UPDATE" then
        RefreshUnit(arg1)
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Picks up a switch that was refused in combat
        addon:UpdateInstanceSimplifiedNameplates()
    elseif event == "PLAYER_ENTERING_WORLD" then
        addon:UpdateInstanceSimplifiedNameplates()
        addon:UpdateFriendlyNameplates()
    elseif event == "CVAR_UPDATE" then
        if arg1 == CLASS_COLOR_CVAR then
            addon:UpdateFriendlyNameplates()
        end
    else -- PLAYER_TARGET_CHANGED, PLAYER_GUILD_UPDATE
        addon:UpdateFriendlyNameplates()
    end
end

function addon:UpdateFriendlyNameplates()
    if not eventFrame then
        eventFrame = CreateFrame("Frame")
        for _, event in ipairs({ "NAME_PLATE_UNIT_ADDED", "UNIT_NAME_UPDATE", "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED",
                                 "PLAYER_GUILD_UPDATE", "CVAR_UPDATE", "PLAYER_REGEN_ENABLED" }) do
            eventFrame:RegisterEvent(event)
        end
        eventFrame:SetScript("OnEvent", OnEvent)
    end

    for _, plate in pairs(C_NamePlate.GetNamePlates()) do
        ApplyToPlate(plate)
    end
end

-- Sets Blizzard's class-color option for friendly names to the setting here, then redraws
function addon:UpdateFriendlyClassColor()
    local value = self.db.nameplateUseClassColorForFriendlyPlayerUnitNames and "1" or "0"
    if C_CVar.GetCVar(CLASS_COLOR_CVAR) ~= value then
        pcall(C_CVar.SetCVar, CLASS_COLOR_CVAR, value)
        -- The console command, if the Lua call didn't take
        if C_CVar.GetCVar(CLASS_COLOR_CVAR) ~= value and ConsoleExec then
            ConsoleExec(CLASS_COLOR_CVAR .. " " .. value)
        end
    end
    self:UpdateFriendlyNameplates()
end

-- Turns Blizzard's simplified style off for friendly players while inside a restricted
-- instance, so the full plates show instead, and back on after leaving. The CVar outlives
-- the session, so the fact that we switched it is saved for the restore.
function addon:UpdateInstanceSimplifiedNameplates()
    if not self:IsFeatureSupported("simplifiedNameplateTypes") then
        return
    end

    local index = Enum.NamePlateSimplifiedType.FriendlyPlayer
    local _, instanceType = IsInInstance()
    local suppress = self.db.nameplateFullFriendlyInInstances and RESTRICTED_INSTANCE_TYPES[instanceType] or false

    local wanted
    if suppress and not self.db.nameplateSimplifiedFriendlySuppressed then
        -- Nothing to do when simplified friendly plates are already off
        if not C_CVar.GetCVarBitfield(SIMPLIFIED_TYPES_CVAR, index) then
            return
        end
        wanted = false
    elseif not suppress and self.db.nameplateSimplifiedFriendlySuppressed then
        wanted = true
    else
        return
    end

    pcall(C_CVar.SetCVarBitfield, SIMPLIFIED_TYPES_CVAR, index, wanted)

    -- Only record the switch once it has taken; PLAYER_REGEN_ENABLED retries otherwise
    if (C_CVar.GetCVarBitfield(SIMPLIFIED_TYPES_CVAR, index) or false) == wanted then
        self.db.nameplateSimplifiedFriendlySuppressed = not wanted or nil
    end
end
