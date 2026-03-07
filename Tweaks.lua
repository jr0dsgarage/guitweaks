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
        local baseName = GetUnitName(unit, false) or UnitName(unit)
        if pvpName and baseName and pvpName ~= baseName then
            if string.sub(pvpName, -#baseName) == baseName then
                local title = string.sub(pvpName, 1, -(#baseName + 1))
                title = string.match(title, "^%s*(.-)%s*$")
                topText = title
                bottomText = baseName
            elseif string.sub(pvpName, 1, #baseName) == baseName then
                local title = string.sub(pvpName, #baseName + 1)
                title = string.match(title, "^[,%s]*(.-)%s*$")
                topText = baseName
                bottomText = title
            else
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
    local width = math.max((anchor:GetWidth() or 80) + 90, 120)

    text:SetWidth(width)
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
        titleText:SetWidth(width)
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
        frame = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(unitOrFrame)
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
