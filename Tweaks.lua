---@diagnostic disable: undefined-global
-- Garage UI Tweaks - Shared Tweak Coordinator
local addonName, addon = ...
local FRIENDLY_CLASS_COLOR_CVAR = "nameplateUseClassColorForFriendlyPlayerUnitNames"

local function IsFriendlyPlayerUnit(unit)
    if not unit or not UnitExists(unit) then
        return false
    end

    if not UnitIsPlayer(unit) then
        return false
    end

    if UnitInParty(unit) or UnitInRaid(unit) then
        return true
    end

    local reaction = UnitReaction(unit, "player")
    return reaction and reaction > 4 or false
end

local function ResolveNameplateUnit(frame)
    if not frame then
        return nil
    end

    if frame.unit and UnitExists(frame.unit) then
        return frame.unit
    end

    if frame.namePlateUnitToken and UnitExists(frame.namePlateUnitToken) then
        return frame.namePlateUnitToken
    end

    if frame.UnitFrame and frame.UnitFrame.unit and UnitExists(frame.UnitFrame.unit) then
        return frame.UnitFrame.unit
    end

    if C_NamePlate and C_NamePlate.GetNamePlateForUnit then
        for i = 1, 40 do
            local token = "nameplate" .. i
            local plate = C_NamePlate.GetNamePlateForUnit(token)
            if plate == frame and UnitExists(token) then
                return token
            end
        end
    end

    return frame.namePlateUnitToken or frame.unit or (frame.UnitFrame and frame.UnitFrame.unit)
end

function addon:SetFriendlyClassColorCVar(enabled)
    local val = enabled and "1" or "0"
    if C_CVar and C_CVar.SetCVar then
        pcall(function() C_CVar.SetCVar(FRIENDLY_CLASS_COLOR_CVAR, val) end)
    elseif SetCVar then
        pcall(function() SetCVar(FRIENDLY_CLASS_COLOR_CVAR, val) end)
    end

    if ConsoleExec then
        ConsoleExec(FRIENDLY_CLASS_COLOR_CVAR .. " " .. val)
    end
end

function addon:GetFriendlyClassColorCVarEnabled()
    local val
    if C_CVar and C_CVar.GetCVar then
        val = C_CVar.GetCVar(FRIENDLY_CLASS_COLOR_CVAR)
    elseif GetCVar then
        val = GetCVar(FRIENDLY_CLASS_COLOR_CVAR)
    end

    if val == nil then
        return self.db and self.db.nameplateUseClassColorForFriendlyPlayerUnitNames
    end

    return tostring(val) == "1"
end

function addon:GetFriendlyNameColor(unit)
    if self:GetFriendlyClassColorCVarEnabled() then
        local _, classFile = UnitClass(unit)
        local classColor = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
        if classColor then
            return classColor.r, classColor.g, classColor.b, 1
        end
    end

    local c = self.db.nameplateFriendlyNameColor or { r = 1, g = 1, b = 1, a = 1 }
    return c.r or 1, c.g or 1, c.b or 1, c.a or 1
end

function addon:GetFriendlyNameAnchorFrame(frame)
    if not frame then
        return nil
    end

    if frame.UnitFrame and frame.UnitFrame.HealthBarsContainer and frame.UnitFrame.HealthBarsContainer.healthBar then
        return frame.UnitFrame.HealthBarsContainer.healthBar
    end

    if frame.UnitFrame and frame.UnitFrame.HealthBarsContainer then
        return frame.UnitFrame.HealthBarsContainer
    end

    if frame.UnitFrame then
        return frame.UnitFrame
    end

    return frame
end

function addon:GetOrCreateFriendlyNameText(frame)
    local anchor = self:GetFriendlyNameAnchorFrame(frame)
    if not anchor then
        return nil, nil
    end

    if not anchor.GUITFriendlyNameText then
        local text = anchor:CreateFontString(nil, "OVERLAY")
        text:SetDrawLayer("OVERLAY", 7)
        text:SetWordWrap(false)
        text:SetMaxLines(1)
        text:SetShadowOffset(1, -1)
        text:SetShadowColor(0, 0, 0, 1)
        anchor.GUITFriendlyNameText = text
    end

    if not anchor.GUITFriendlyTitleText then
        local titleText = anchor:CreateFontString(nil, "OVERLAY")
        titleText:SetDrawLayer("OVERLAY", 7)
        titleText:SetWordWrap(false)
        titleText:SetMaxLines(1)
        titleText:SetShadowOffset(1, -1)
        titleText:SetShadowColor(0, 0, 0, 1)
        anchor.GUITFriendlyTitleText = titleText
    end

    return anchor.GUITFriendlyNameText, anchor.GUITFriendlyTitleText, anchor
end

function addon:ApplyFriendlyNameToFrame(frame)
    local text, titleText, anchor = self:GetOrCreateFriendlyNameText(frame)
    if not text or not anchor or not frame then
        return
    end

    local enabled = self.db.nameplateFriendlyNamesEnabled
    local unit = ResolveNameplateUnit(frame)

    if not unit then
        text:Hide()
        if titleText then titleText:Hide() end
        return
    end

    if not enabled or not IsFriendlyPlayerUnit(unit) then
        text:Hide()
        if titleText then titleText:Hide() end
        return
    end

    if UnitExists("target") and UnitIsUnit(unit, "target") then
        text:Hide()
        if titleText then titleText:Hide() end
        return
    end

    local bottomText, topText
    if self.db.nameplateFriendlyNamesShowTitle then
        local pvpName = UnitPVPName(unit)
        local unitName, unitRealm = UnitName(unit)
        local baseName = unitName or ""
        local matchName = baseName
        if unitRealm and unitRealm ~= "" then
            matchName = baseName .. "-" .. unitRealm
        end
        
        if pvpName and pvpName ~= "" and matchName ~= "" then
            local s, e = string.find(pvpName, matchName, 1, true)
            if s then
                if s > 1 then
                    -- Title is a prefix
                    local title = string.sub(pvpName, 1, s - 1)
                    title = string.match(title, "^[%s,]*(.-)[%s,]*$")
                    if title and title ~= "" then
                        topText = title
                        bottomText = baseName
                    else
                        bottomText = baseName
                    end
                elseif e < #pvpName then
                    -- Title is a suffix
                    local title = string.sub(pvpName, e + 1)
                    title = string.match(title, "^[%s,]*(.-)[%s,]*$")
                    if title and title ~= "" then
                        topText = baseName
                        bottomText = title
                    else
                        bottomText = baseName
                    end
                else
                    bottomText = baseName
                end
            else
                -- Fallback if exact match fails
                bottomText = pvpName
            end
        else
            bottomText = baseName
        end
    else
        bottomText = GetUnitName(unit, false) or UnitName(unit)
    end

    if not bottomText or bottomText == "" then
        text:Hide()
        if titleText then titleText:Hide() end
        return
    end

    local fontPath = self.db.nameplateFriendlyNameFont or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    local fontSize = self.db.nameplateFriendlyNameSize or 13
    local outline = (self.db.nameplateFriendlyNameOutline or "OUTLINE"):upper()
    local fontFlags = nil
    if outline == "OUTLINE" then
        fontFlags = "OUTLINE"
    elseif outline == "THICKOUTLINE" then
        fontFlags = "THICKOUTLINE"
    end
    if not text:SetFont(fontPath, fontSize, fontFlags) then
        text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", fontSize, fontFlags)
    end

    local justify = (self.db.nameplateFriendlyNameJustify or "CENTER"):upper()
    local offsetX = self.db.nameplateFriendlyNameOffsetX or 0
    local offsetY = self.db.nameplateFriendlyNameOffsetY or 10

    text:SetWidth(0)
    text:SetJustifyH(justify)
    text:ClearAllPoints()
    if justify == "LEFT" then
        text:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", offsetX, offsetY)
    elseif justify == "RIGHT" then
        text:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", offsetX, offsetY)
    else
        text:SetPoint("BOTTOM", anchor, "TOP", offsetX, offsetY)
    end

    local r, g, b, a = self:GetFriendlyNameColor(unit)
    text:SetTextColor(r, g, b, a)
    text:SetText(bottomText)

    if (text:GetStringWidth() or 0) <= 0 then
        text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", fontSize, fontFlags)
        text:SetText(bottomText)
    end

    text:Show()
    
    if topText and titleText then
        if not titleText:SetFont(fontPath, fontSize, fontFlags) then
            titleText:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", fontSize, fontFlags)
        end
        titleText:SetWidth(0)
        titleText:SetJustifyH(justify)
        titleText:ClearAllPoints()
        
        local titleOffsetY = 2
        if justify == "LEFT" then
            titleText:SetPoint("BOTTOMLEFT", text, "TOPLEFT", 0, titleOffsetY)
        elseif justify == "RIGHT" then
            titleText:SetPoint("BOTTOMRIGHT", text, "TOPRIGHT", 0, titleOffsetY)
        else
            titleText:SetPoint("BOTTOM", text, "TOP", 0, titleOffsetY)
        end
        
        titleText:SetTextColor(r, g, b, a)
        titleText:SetText(topText)
        
        if (titleText:GetStringWidth() or 0) <= 0 then
            titleText:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", fontSize, fontFlags)
            titleText:SetText(topText)
        end
        
        titleText:Show()
    elseif titleText then
        titleText:Hide()
    end
end

function addon:ApplyScaleToFrame(frame)
    if not frame then
        return
    end

    local unit = ResolveNameplateUnit(frame)
    if not unit then
        return
    end

    local scale = self.db.nameplateSimplifiedScale or 1.0
    if InCombatLockdown() then
        return
    end

    if IsFriendlyPlayerUnit(unit) then
        frame:SetScale(scale)
    else
        frame:SetScale(1)
    end
end

function addon:RefreshSingleNameplate(unitOrFrame)
    local frame = unitOrFrame
    if type(unitOrFrame) == "string" then
        if string.match(unitOrFrame, "^boss%d*$")
            or string.match(unitOrFrame, "^party%d+$")
            or string.match(unitOrFrame, "^raid%d+$")
        then
            return -- Restricted unit tokens are not allowed for GetNamePlateForUnit
        end

        if C_NamePlate and C_NamePlate.GetNamePlateForUnit then
            local ok, result = pcall(C_NamePlate.GetNamePlateForUnit, unitOrFrame)
            if ok then
                frame = result
            else
                return
            end
        else
            frame = nil
        end
    end

    if not frame then
        return
    end

    self:ApplyScaleToFrame(frame)
    self:ApplyFriendlyNameToFrame(frame)
end

function addon:EnsureNameplateHooks()
    if self.nameplateEventFrame then
        return
    end

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    eventFrame:RegisterEvent("UNIT_NAME_UPDATE")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    eventFrame:RegisterEvent("CVAR_UPDATE")
    eventFrame:SetScript("OnEvent", function(_, event, arg1)
        if event == "NAME_PLATE_UNIT_ADDED" or event == "UNIT_NAME_UPDATE" then
            addon:RefreshSingleNameplate(arg1)
            return
        end

        if event == "PLAYER_TARGET_CHANGED" then
            addon:UpdateFriendlyNameplates()
            return
        end

        if event == "PLAYER_ENTERING_WORLD" then
            addon:UpdateNameplateScale()
            addon:UpdateFriendlyNameplates()
            return
        end

        if event == "CVAR_UPDATE" and tostring(arg1) == FRIENDLY_CLASS_COLOR_CVAR then
            addon:UpdateFriendlyNameplates()
        end
    end)

    self.nameplateEventFrame = eventFrame
end

function addon:UpdateFriendlyNameplates()
    self:EnsureNameplateHooks()

    if not C_NamePlate or not C_NamePlate.GetNamePlates then
        return
    end

    for _, frame in pairs(C_NamePlate.GetNamePlates()) do
        self:ApplyFriendlyNameToFrame(frame)
    end
end

function addon:ApplyTweaks()
    if not self.db then
        return
    end

    self:InitProfessionRecipeQualityColors()

    self:SetErrorTextBackground(self.db.errorTextBackgroundEnabled, self.db.errorTextBackgroundAlpha, self.db.errorTextBackgroundDuration)
    self:SetBattlegroundMapScale(self.db.battlegroundMapScale)
    self:SetSpeedPanelEnabled(self.db.speedPanelEnabled)
    self:UpdatePRDTextures()
    self:SetPRDVisibilityOptions()
    self:InitChatTweaks()
    self:UpdateOverrideActionBar()

    -- Nameplate Tweaks
    self:UpdateNameplateScale()
    self:UpdateFriendlyNameplates()

    if self.db.nameplateUseClassColorForFriendlyPlayerUnitNames ~= nil then
        self:SetFriendlyClassColorCVar(self.db.nameplateUseClassColorForFriendlyPlayerUnitNames)
    end

    self:SetProfessionRecipeQualityColorEnabled(self.db.professionRecipeQualityColorEnabled)

    self:InitEncounterBarPreyPercent()
end

function addon:UpdateNameplateScale()
    self:EnsureNameplateHooks()

    if not self.db.nameplateSimplifiedScale then
        return
    end

    if not C_NamePlate or not C_NamePlate.GetNamePlates then
        return
    end

    for _, frame in pairs(C_NamePlate.GetNamePlates()) do
        self:ApplyScaleToFrame(frame)
    end
end

function addon:UpdateOverrideActionBar()
    if InCombatLockdown() then return end
    if not OverrideActionBar then return end
    
    local offset = self.db.overrideActionBarYOffset or 0
    OverrideActionBar:ClearAllPoints()
    OverrideActionBar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, offset)
end

-- ============================================================
-- Encounter Bar Prey Percentage
-- Detects the prey encounter via UIWidgetPowerBarContainerFrame
-- (StateTexture atlas "UI-prey-targeticon-*") and reads the bar
-- value directly from the widget's StatusBar child.
-- ============================================================

local _preyEventFrame  = nil
local _preyLabel       = nil
local _preyLabelParent = nil  -- widget frame the label is currently childed to
local _preyLastPct     = nil
local _preyLastVisible = false
local _preyLastWidget  = nil
local _preyLastWidgetID = nil
local _preyLastWidgetShown = nil
local _PREY_HUNT_BUFF_NAME = "On the Hunt"
local _preyWidgetInfoCache = nil
local _preyHuntMixinHooked = false
local _preyHuntInstanceHooked = false
local _preyWidgetVizGetters = nil

-- Forward declaration: referenced by helper functions defined earlier in this file.
local _ExtractProgressPercent

local function _PlayerHasPreyHuntBuff()
    if AuraUtil and AuraUtil.FindAuraByName then
        local aura = AuraUtil.FindAuraByName(_PREY_HUNT_BUFF_NAME, "player", "HELPFUL")
        return aura ~= nil
    end

    for i = 1, 40 do
        local name = UnitBuff("player", i)
        if not name then break end
        if name == _PREY_HUNT_BUFF_NAME then
            return true
        end
    end

    return false
end

local function _GetWidgetID(widget)
    if not widget then return nil end
    if type(widget.widgetID) == "number" then return widget.widgetID end
    if type(widget.WidgetID) == "number" then return widget.WidgetID end
    if type(widget.widgetId) == "number" then return widget.widgetId end
    if type(widget.id) == "number" then return widget.id end

    if widget.GetWidgetID then
        local ok, id = pcall(widget.GetWidgetID, widget)
        if ok and type(id) == "number" then
            return id
        end
    end

    local parent = widget.GetParent and widget:GetParent()
    if parent then
        if type(parent.widgetID) == "number" then return parent.widgetID end
        if type(parent.WidgetID) == "number" then return parent.WidgetID end
        if type(parent.widgetId) == "number" then return parent.widgetId end
    end

    return nil
end

local function _FindStatusBarRecursive(frame, depth)
    if not frame or depth > 4 then return nil end

    if frame.IsObjectType and frame:IsObjectType("StatusBar") then
        return frame
    end

    local known = {
        frame.Bar,
        frame.statusBar,
        frame.StatusBar,
        frame.progressBar,
        frame.ProgressBar,
    }
    for _, candidate in ipairs(known) do
        if candidate and candidate.IsObjectType and candidate:IsObjectType("StatusBar") then
            return candidate
        end
    end

    if frame.GetNumChildren and frame.GetChildren then
        for i = 1, frame:GetNumChildren() do
            local child = select(i, frame:GetChildren())
            local found = _FindStatusBarRecursive(child, depth + 1)
            if found then
                return found
            end
        end
    end

    return nil
end

local function _ExtractProgressPercentFromText(text)
    if type(text) ~= "string" then
        return nil
    end

    local pctText = text:match("(%d+)%s*%%")
    local pctValue = tonumber(pctText)
    if pctValue then
        return math.max(0, math.min(100, pctValue))
    end

    local currentText, maxText = text:match("(%d+)%s*/%s*(%d+)")
    local current = tonumber(currentText)
    local maxValue = tonumber(maxText)
    if current and maxValue and maxValue > 0 and current <= maxValue then
        return math.max(0, math.min(100, (current / maxValue) * 100))
    end

    return nil
end

local function _ExtractProgressPercentFromWidgetText(frame, depth)
    if not frame or depth > 5 then
        return nil
    end

    if frame.GetNumRegions and frame.GetRegions then
        for i = 1, frame:GetNumRegions() do
            local region = select(i, frame:GetRegions())
            if region and region.IsObjectType and region:IsObjectType("FontString") and region.GetText then
                local pct = _ExtractProgressPercentFromText(region:GetText())
                if pct ~= nil then
                    return pct
                end
            end
        end
    end

    if frame.GetNumChildren and frame.GetChildren then
        for i = 1, frame:GetNumChildren() do
            local child = select(i, frame:GetChildren())
            local found = _ExtractProgressPercentFromWidgetText(child, depth + 1)
            if found ~= nil then
                return found
            end
        end
    end

    return nil
end

local function _ExtractPercentFromProgressState(progressState)
    local state = tonumber(progressState)
    if state == nil then
        return nil
    end

    if state <= 0 then
        return 0
    elseif state == 1 then
        return 33
    elseif state == 2 then
        return 66
    elseif state >= 3 then
        return 100
    end

    return nil
end

local function _ExtractProgressPercentFromWidgetFields(widget)
    if not widget then
        return nil
    end

    local candidates = {
        widget.widgetInfo,
        widget.WidgetInfo,
        widget.data,
        widget.Data,
        widget.info,
        widget.Info,
        widget.progressInfo,
        widget.ProgressInfo,
        widget.barInfo,
        widget.BarInfo,
    }

    for _, info in ipairs(candidates) do
        local pct = _ExtractProgressPercent(info, type(info) == "table" and info.tooltip or nil)
        if pct ~= nil then
            return pct
        end
    end

    return nil
end

local function _GetWidgetVisualizationGetters()
    if _preyWidgetVizGetters then
        return _preyWidgetVizGetters
    end

    _preyWidgetVizGetters = {}

    local mgr = C_UIWidgetManager
    if type(mgr) ~= "table" then
        return _preyWidgetVizGetters
    end

    for key, fn in pairs(mgr) do
        if type(key) == "string" and type(fn) == "function"
            and key:find("^Get")
            and key:find("WidgetVisualizationInfo")
        then
            _preyWidgetVizGetters[#_preyWidgetVizGetters + 1] = { name = key, fn = fn }
        end
    end

    table.sort(_preyWidgetVizGetters, function(a, b)
        return a.name < b.name
    end)

    return _preyWidgetVizGetters
end

local function _ExtractProgressPercentFromAnyWidgetAPI(widgetID)
    if type(widgetID) ~= "number" then
        return nil
    end

    local getters = _GetWidgetVisualizationGetters()
    for _, getter in ipairs(getters) do
        local ok, info = pcall(getter.fn, widgetID)
        if ok and info ~= nil then
            local pct = _ExtractProgressPercent(info, type(info) == "table" and info.tooltip or nil)
            if pct ~= nil then
                return pct
            end
        end
    end

    return nil
end

local function _ExtractProgressPercentFromInfoScan(info)
    if type(info) ~= "table" then
        return nil
    end

    local visited = {}
    local function _ScanTable(tbl, depth)
        if type(tbl) ~= "table" or depth > 4 or visited[tbl] then
            return nil
        end
        visited[tbl] = true

        local currentValues = {}
        local maxValues = {}

        for key, value in pairs(tbl) do
            if type(value) == "number" then
                local keyText = string.lower(tostring(key))
                if string.find(keyText, "percent", 1, true) then
                    if value >= 0 and value <= 1 then
                        return math.max(0, math.min(100, value * 100))
                    end
                    return math.max(0, math.min(100, value))
                end

                if value >= 0 then
                    if string.find(keyText, "current", 1, true)
                        or string.find(keyText, "value", 1, true)
                        or string.find(keyText, "progress", 1, true)
                        or string.find(keyText, "fulfilled", 1, true)
                        or string.find(keyText, "completed", 1, true)
                    then
                        currentValues[#currentValues + 1] = value
                    end

                    if string.find(keyText, "max", 1, true)
                        or string.find(keyText, "total", 1, true)
                        or string.find(keyText, "required", 1, true)
                    then
                        maxValues[#maxValues + 1] = value
                    end
                end
            elseif type(value) == "string" then
                local pct = _ExtractProgressPercentFromText(value)
                if pct ~= nil then
                    return pct
                end
            elseif type(value) == "table" then
                local nested = _ScanTable(value, depth + 1)
                if nested ~= nil then
                    return nested
                end
            end
        end

        for _, current in ipairs(currentValues) do
            for _, maxValue in ipairs(maxValues) do
                if maxValue > 0 and current <= maxValue then
                    return math.max(0, math.min(100, (current / maxValue) * 100))
                end
            end
        end

        return nil
    end

    return _ScanTable(info, 0)
end

_ExtractProgressPercent = function(info, tooltipText)
    if type(info) == "table" then
        local directFields = {
            "progressPercentage",
            "progressPercent",
            "fillPercentage",
            "percentage",
            "percent",
            "progress",
            "progressValue",
        }

        for _, fieldName in ipairs(directFields) do
            local rawValue = info[fieldName]
            if type(rawValue) == "number" then
                if rawValue >= 0 and rawValue <= 1 then
                    return math.max(0, math.min(100, rawValue * 100))
                end
                return math.max(0, math.min(100, rawValue))
            end
        end

        local valueFields = { "barValue", "value", "currentValue" }
        local maxFields = { "barMax", "maxValue", "totalValue", "total", "max" }
        for _, valueField in ipairs(valueFields) do
            local current = info[valueField]
            if type(current) == "number" then
                for _, maxField in ipairs(maxFields) do
                    local maxValue = info[maxField]
                    if type(maxValue) == "number" and maxValue > 0 then
                        return math.max(0, math.min(100, (current / maxValue) * 100))
                    end
                end
            end
        end
    end

    local scanned = _ExtractProgressPercentFromInfoScan(info)
    if scanned ~= nil then
        return scanned
    end

    local tooltipPct = _ExtractProgressPercentFromText(tooltipText)
    if tooltipPct ~= nil then
        return tooltipPct
    end

    if type(info) == "table" then
        local statePct = _ExtractPercentFromProgressState(info.progressState or info.state)
        if statePct ~= nil then
            return statePct
        end
    end

    return nil
end

local function _CapturePreyWidgetInfo(self, widgetInfo)
    _preyLastWidget = self

    if type(widgetInfo) == "table" then
        -- Keep a full shallow copy so nested payload tables remain available.
        local cache = {}
        for key, value in pairs(widgetInfo) do
            cache[key] = value
        end
        _preyWidgetInfoCache = cache
    else
        _preyWidgetInfoCache = nil
    end
end

local function _EnsurePreyHuntSetupHook(fallbackWidget)
    if (_preyHuntMixinHooked or _preyHuntInstanceHooked) or type(hooksecurefunc) ~= "function" then
        return
    end

    local mixin = _G["UIWidgetTemplatePreyHuntProgressMixin"]
    if mixin and type(mixin.Setup) == "function" then
        local ok = pcall(hooksecurefunc, mixin, "Setup", _CapturePreyWidgetInfo)
        if ok then
            _preyHuntMixinHooked = true
            return
        end
    end

    if fallbackWidget and type(fallbackWidget.Setup) == "function" then
        local ok = pcall(hooksecurefunc, fallbackWidget, "Setup", _CapturePreyWidgetInfo)
        if ok then
            _preyHuntInstanceHooked = true
            return
        end
    end
end

-- Scan UIWidgetPowerBarContainerFrame children for the prey power bar widget.
-- Returns the widget frame, or nil.
local function _FindPreyWidget()
    local container = _G["UIWidgetPowerBarContainerFrame"]
    if not container then
        return nil
    end
    if not container:IsShown() then
        return nil
    end

    for i = 1, container:GetNumChildren() do
        local child = select(i, container:GetChildren())
        if child and child.StateTexture then
            local atlas = child.StateTexture:GetAtlas()
            if atlas and atlas:lower():find("prey") then
                if _preyLastWidget ~= child then
                    _preyLastWidget = child
                    _preyLastWidgetID = _GetWidgetID(child)
                end
                return child
            end
        end
    end

    _preyLastWidget = false
    return nil
end

-- Returns (or creates) the FontString, always parented to the current widget.
-- If the widget frame has changed (pool recycling), the old label is discarded.
local function _GetOrCreatePreyLabel(widget)
    if _preyLabelParent ~= widget then
        if _preyLabel then
            _preyLabel:Hide()
            _preyLabel = nil
        end
        _preyLabelParent = widget

        local lbl = widget:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        local statusBar = _FindStatusBarRecursive(widget, 0)
        local anchor = statusBar or widget
        lbl:SetPoint("CENTER", anchor, "CENTER", 0, 0)
        lbl:SetTextColor(1, 1, 1, 1)
        lbl:SetShadowOffset(1, -1)
        lbl:SetShadowColor(0, 0, 0, 1)
        lbl:Hide()
        _preyLabel = lbl
    end
    return _preyLabel
end

local function _RefreshPreyPercent()
    if not addon.db.encounterBarPreyPercentEnabled then
        if _preyLabel and _preyLastVisible then
            _preyLabel:Hide()
            _preyLastVisible = false
        end
        return
    end

    if not _PlayerHasPreyHuntBuff() then
        if _preyLabel and _preyLastVisible then
            _preyLabel:Hide()
            _preyLastVisible = false
        end
        _preyLastPct = nil
        _preyWidgetInfoCache = nil
        return
    end

    local widget = _FindPreyWidget()
    if not widget then
        if _preyLabel and _preyLastVisible then
            _preyLabel:Hide()
            _preyLastVisible = false
        end
        return
    end

    if not (_preyHuntMixinHooked or _preyHuntInstanceHooked) then
        _EnsurePreyHuntSetupHook(widget)
    end

    if not widget:IsShown() then
        if _preyLabel and _preyLastVisible then
            _preyLabel:Hide()
            _preyLastVisible = false
        end
        return
    end

    local lbl = _GetOrCreatePreyLabel(widget)
    if not lbl then
        return
    end

    local pct
    if _preyWidgetInfoCache then
        pct = _ExtractProgressPercent(_preyWidgetInfoCache, _preyWidgetInfoCache.tooltip)
    end

    local statusBar = _FindStatusBarRecursive(widget, 0)
    if pct == nil and statusBar then
        local val = statusBar:GetValue()
        local minV, maxV = statusBar:GetMinMaxValues()
        if maxV and maxV > minV then
            pct = math.floor((val - minV) / (maxV - minV) * 100 + 0.5)
        end
    end

    if pct == nil then
        pct = _ExtractProgressPercentFromWidgetFields(widget)
    end

    if pct == nil then
        pct = _ExtractProgressPercentFromWidgetText(widget, 0)
    end

    if pct == nil then
        local widgetID = _GetWidgetID(widget) or _preyLastWidgetID
        if widgetID and C_UIWidgetManager and C_UIWidgetManager.GetStatusBarWidgetVisualizationInfo then
            local info = C_UIWidgetManager.GetStatusBarWidgetVisualizationInfo(widgetID)
            if info then
                pct = _ExtractProgressPercent(info, info.tooltip)
            end

            if pct == nil then
                pct = _ExtractProgressPercentFromAnyWidgetAPI(widgetID)
            end
        end
    end

    if pct ~= nil then
        pct = math.floor(math.max(0, math.min(100, pct)) + 0.5)
    end

    if pct ~= nil then
        _preyLastPct = pct
        lbl:SetText(pct .. "%")
        local textHeight = lbl:GetStringHeight()
        local yOffset = -(textHeight / 2)
        lbl:SetPoint("CENTER", lbl:GetParent(), "CENTER", 0, yOffset)
        lbl:Show()
        _preyLastVisible = true
    else
        lbl:Hide()
        _preyLastVisible = false
    end
end

local function _TryRegisterEvent(frame, eventName)
    pcall(function()
        frame:RegisterEvent(eventName)
    end)
end

function addon:InitEncounterBarPreyPercent()
    _EnsurePreyHuntSetupHook()

    if not _preyEventFrame then
        _preyEventFrame = CreateFrame("Frame")
        _TryRegisterEvent(_preyEventFrame, "ENCOUNTER_START")
        _TryRegisterEvent(_preyEventFrame, "ENCOUNTER_END")
        _TryRegisterEvent(_preyEventFrame, "UPDATE_UI_WIDGET")
        _TryRegisterEvent(_preyEventFrame, "UPDATE_ALL_UI_WIDGETS")
        _TryRegisterEvent(_preyEventFrame, "PLAYER_ENTERING_WORLD")
        _TryRegisterEvent(_preyEventFrame, "ZONE_CHANGED_NEW_AREA")
        _TryRegisterEvent(_preyEventFrame, "UNIT_AURA")

        _preyEventFrame:SetScript("OnEvent", function(self, event, ...)
            if event == "ENCOUNTER_START"
                or event == "UPDATE_ALL_UI_WIDGETS"
                or event == "PLAYER_ENTERING_WORLD"
                or event == "ZONE_CHANGED_NEW_AREA" then
                -- Brief delay so Blizzard finishes building/showing the widget
                C_Timer.After(0.1, _RefreshPreyPercent)
            elseif event == "UPDATE_UI_WIDGET" then
                _RefreshPreyPercent()
            elseif event == "UNIT_AURA" then
                local unit = ...
                if unit == "player" then
                    _RefreshPreyPercent()
                end
            elseif event == "ENCOUNTER_END" then
                if _preyLabel then
                    _preyLabel:Hide()
                end
                _preyLastVisible = false
                _preyLastPct = nil
                _preyWidgetInfoCache = nil
            end
        end)
    end

    _RefreshPreyPercent()
end
