---@diagnostic disable: undefined-global
-- Garage UI Tweaks - Cooldown Timer at Mouse
local addonName, addon = ...

local DEFAULT_DURATION = 3.0
local DEFAULT_OFFSET = 40
local DEFAULT_ANGLE = 90
local DEFAULT_FONT_SIZE = 22
local REFRESH_INTERVAL = 0.1
local GCD_MAX_DURATION = 1.5

local display
local eventFrame
local activeSpellID
local activeCooldown   -- duration object (12.x) or cooldown info table (older clients)
local hideAt
local refreshElapsed = 0

local function IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value)
end

-- Returns the spell's cooldown if it is on a real (non-GCD) cooldown.
-- Cooldown numbers are secret in combat on 12.x, so only the never-secret
-- isActive/isOnGCD flags are tested and the time itself comes from a duration object.
local function GetActiveCooldown(spellID)
    local info = C_Spell.GetSpellCooldown(spellID)
    if not info then
        return nil
    end

    if info.isActive == nil then
        -- Older clients: plain numbers, no isActive/isOnGCD flags
        if not info.duration or info.duration <= GCD_MAX_DURATION then
            return nil
        end
        return info
    end

    if not info.isActive or info.isOnGCD then
        return nil
    end

    if C_Spell.GetSpellCooldownDuration then
        return C_Spell.GetSpellCooldownDuration(spellID, true)
    end
    return info
end

local function GetRemaining(cooldown)
    if type(cooldown) == "table" then
        return cooldown.startTime + cooldown.duration - GetTime()
    end
    return cooldown:GetRemainingDuration()
end

-- Secret values can't be split into minutes and seconds in Lua, so on 12.x the
-- client does it: seconds below a minute, m:ss above. False if unavailable.
local remainingFormatter
local function GetRemainingFormatter()
    if remainingFormatter ~= nil then
        return remainingFormatter
    end

    remainingFormatter = false
    if not C_StringUtil or not C_StringUtil.CreateNumericRuleFormatter then
        return false
    end

    local roundUp = Enum.NumericRuleFormatRounding and Enum.NumericRuleFormatRounding.Up
    local roundDown = Enum.NumericRuleFormatRounding and Enum.NumericRuleFormatRounding.Down
    local ok, result, short, long = pcall(function()
        local formatter = C_StringUtil.CreateNumericRuleFormatter()
        formatter:SetBreakpoints({
            { threshold = 0, step = 1, rounding = roundUp, format = "%d" },
            { threshold = 60, step = 1, rounding = roundUp, format = "%d:%02d", components = {
                { div = 60, step = 1, rounding = roundDown },
                { mod = 60 },
            } },
        })
        return formatter, formatter:FormatNumber(4.2), formatter:FormatNumber(116.4)
    end)

    -- Only trust it if it formats known values the way we expect
    if ok and short == "5" and long == "1:57" then
        remainingFormatter = result
    else
        addon:Print("Cooldown timer: m:ss formatter unavailable (" .. tostring(ok and (tostring(short) .. " / " .. tostring(long)) or result) .. ")")
    end
    return remainingFormatter
end

local function UpdateText()
    if type(activeCooldown) ~= "table" and GetRemainingFormatter() then
        display.text:SetText(activeCooldown:FormatRemainingDuration(remainingFormatter))
        return
    end

    local remaining = GetRemaining(activeCooldown)
    if IsSecret(remaining) then
        -- Can't do math on a secret; let the font string format it
        display.text:SetFormattedText("%.0f", remaining)
    elseif remaining >= 60 then
        display.text:SetFormattedText("%d:%02d", remaining / 60, remaining % 60)
    else
        display.text:SetFormattedText("%d", math.ceil(remaining))
    end
end

local function UpdatePosition()
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    local offset = addon.db.cooldownAtMouseOffset or DEFAULT_OFFSET
    -- 0 degrees is straight above the cursor, increasing clockwise
    local angle = math.rad(addon.db.cooldownAtMouseAngle or DEFAULT_ANGLE)
    display:ClearAllPoints()
    display:SetPoint("CENTER", UIParent, "BOTTOMLEFT", (x / scale) + offset * math.sin(angle), (y / scale) + offset * math.cos(angle))
end

local function HideDisplay()
    activeSpellID = nil
    activeCooldown = nil
    hideAt = nil
    if display then
        display:Hide()
    end
end

local function OnUpdate(_, elapsed)
    if GetTime() >= hideAt then
        HideDisplay()
        return
    end

    refreshElapsed = refreshElapsed + elapsed
    if refreshElapsed >= REFRESH_INTERVAL then
        refreshElapsed = 0
        activeCooldown = GetActiveCooldown(activeSpellID)
        if not activeCooldown then
            HideDisplay()
            return
        end
    end

    UpdatePosition()
    UpdateText()
end

function addon:UpdateCooldownAtMouseFont()
    if not display then
        return
    end

    local size = self.db.cooldownAtMouseFontSize or DEFAULT_FONT_SIZE
    -- Only an explicit false is a failure; SetFont returns nothing on success here
    if display.text:SetFont(self.db.cooldownAtMouseFont or STANDARD_TEXT_FONT, size, "OUTLINE") == false then
        display.text:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE")
    end
end

local function EnsureDisplay()
    if display then
        return
    end

    display = CreateFrame("Frame", "GarageUITweaksCooldownAtMouse", UIParent)
    display:SetSize(1, 1)
    display:SetFrameStrata("TOOLTIP")
    display:Hide()

    display.text = display:CreateFontString(nil, "OVERLAY")
    addon:UpdateCooldownAtMouseFont()
    display.text:SetTextColor(1, 0.82, 0)
    display.text:SetPoint("CENTER", display, "CENTER", 0, 0)

    display:SetScript("OnUpdate", OnUpdate)
end

local function ShowCooldown(spellID)
    local cooldown = GetActiveCooldown(spellID)
    if not cooldown then
        return
    end

    EnsureDisplay()
    activeSpellID = spellID
    activeCooldown = cooldown
    hideAt = GetTime() + (addon.db.cooldownAtMouseDuration or DEFAULT_DURATION)
    refreshElapsed = 0

    UpdatePosition()
    UpdateText()
    display:Show()
end

function addon:SetCooldownAtMouseEnabled(enabled)
    if not self:IsFeatureSupported("cooldownAtMouse") then
        return
    end

    if not enabled then
        if eventFrame then
            eventFrame:UnregisterAllEvents()
        end
        HideDisplay()
        return
    end

    if not eventFrame then
        eventFrame = CreateFrame("Frame")
        -- Fires when a cast attempt is rejected, including "not ready yet"
        eventFrame:SetScript("OnEvent", function(_, _, _, _, spellID)
            ShowCooldown(spellID)
        end)
    end
    eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
end
