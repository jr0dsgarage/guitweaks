---@diagnostic disable: undefined-global
-- Garage UI Tweaks - Self Combat Text Position
-- Moves the scrolling text for things that happen to you (damage taken, heals received,
-- aura gains). Blizzard_CombatText draws it on the CombatText frame, which is separate from
-- the engine-drawn damage numbers above enemies (see DamageNumbers.lua).
--
-- Nothing here writes to Blizzard's tables (see the travel distance notes below). The
-- offset shifts the whole frame with a Translation animation held at its end.
local addonName, addon = ...

-- Seconds the animation holds its offset before it finishes and is started again
local HOLD_SECONDS = 100000000

local shiftGroup, shiftAnim
local shownX, shownY

local function ApplyOffset()
    if not CombatText or not addon.db then
        return
    end

    local x = addon.db.selfCombatTextOffsetX
    local y = addon.db.selfCombatTextOffsetY
    local hasOffset = x ~= 0 or y ~= 0

    if not shiftGroup then
        if not hasOffset then
            return
        end
        shiftGroup = CombatText:CreateAnimationGroup()
        shiftAnim = shiftGroup:CreateAnimation("Translation")
        shiftAnim:SetDuration(0.001)
        shiftAnim:SetEndDelay(HOLD_SECONDS)
        shiftGroup:SetScript("OnFinished", ApplyOffset)
        -- Animations stop while the frame is hidden
        CombatText:HookScript("OnShow", ApplyOffset)
    end

    if not hasOffset then
        shiftGroup:Stop()
        shownX, shownY = nil, nil
        return
    end

    if x == shownX and y == shownY and shiftGroup:IsPlaying() then
        return
    end

    shiftGroup:Stop()
    shiftAnim:SetOffset(x, y)
    shiftGroup:Play()
    shownX, shownY = x, y
end

-- Travel distance. Blizzard compares its messages' on-screen positions, which are secret
-- values, and once its code has read any value an addon wrote, the game won't let it compare
-- them. So Blizzard's end point is only read, never changed: each new message instead gets a
-- Translation animation of its own that carries it the extra distance in the same time.

-- Animation per Blizzard font string, as { group = AnimationGroup, anim = Translation }
local travelAnims = setmetatable({}, { __mode = "k" })

local IsSecret = addon.IsSecret

-- Seconds a message takes to scroll
local function GetScrollDuration()
    local constants = CombatTextConstants
    return (constants and constants.MessageScrollSpeed) or COMBAT_TEXT_SCROLLSPEED or 1.9
end

-- Runs after Blizzard's AddMessage, which appends the new font string to activeFontStrings
local function OnMessageAdded()
    local active = CombatText.activeFontStrings
    local fontString = type(active) == "table" and active[#active]
    if not fontString or not addon.db then
        return
    end

    -- Only a message that has just started; AddMessage can return without adding one
    local scrollTime = fontString.scrollTime
    if IsSecret(scrollTime) or (scrollTime ~= nil and scrollTime ~= 0) then
        return
    end

    -- The font string may be reused from an earlier message
    local travel = travelAnims[fontString]
    if travel then
        travel.group:Stop()
    end

    local percent = addon.db.selfCombatTextTravel
    local locations = CombatText.textLocations
    if percent == 100 or type(locations) ~= "table" then
        return
    end

    local startY, endY, ownEndY = locations.startY, locations.endY, fontString.endY
    local duration = GetScrollDuration()
    if IsSecret(startY) or IsSecret(endY) or IsSecret(ownEndY) or IsSecret(duration) then
        return
    end
    if type(startY) ~= "number" or type(endY) ~= "number" or type(duration) ~= "number" then
        return
    end
    -- Crits and other sticky messages stay where they start
    if ownEndY ~= nil and ownEndY ~= endY then
        return
    end

    if not travel then
        local group = fontString:CreateAnimationGroup()
        travel = { group = group, anim = group:CreateAnimation("Translation") }
        travelAnims[fontString] = travel
    end
    travel.anim:SetOffset(0, (endY - startY) * (percent - 100) / 100)
    travel.anim:SetDuration(duration)
    -- Holds the full distance until Blizzard removes the message
    travel.anim:SetEndDelay(1)
    travel.group:Play()
end

local travelHooked = false

local function HookTravel()
    if travelHooked or not (CombatText and CombatText.AddMessage) then
        return
    end
    hooksecurefunc(CombatText, "AddMessage", OnMessageAdded)
    travelHooked = true
end

-- The travel distance applies to each new message, so only the offset needs applying
function addon:UpdateSelfCombatText()
    ApplyOffset()
end

-- False when this client is known not to have Blizzard's scrolling combat text
function addon:HasSelfCombatText()
    if CombatText then
        return true
    end
    if C_AddOns and C_AddOns.DoesAddOnExist then
        return C_AddOns.DoesAddOnExist("Blizzard_CombatText") and true or false
    end
    return true
end

-- Blizzard_CombatText loads on demand, so the frame may not exist until later
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, event, loadedAddon)
    if event == "PLAYER_LOGIN" or loadedAddon == "Blizzard_CombatText" then
        ApplyOffset()
        HookTravel()
    end
end)
