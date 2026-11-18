---@diagnostic disable: undefined-global
-- Garage UI Tweaks - Armor Set Action Highlights
-- Outlines the action buttons that put on the equipment set you're wearing (the set
-- itself, or a macro that /equipset's it), using the assisted combat highlight's art.
local addonName, addon = ...

local EVENTS = {
    "PLAYER_ENTERING_WORLD", "PLAYER_EQUIPMENT_CHANGED", "EQUIPMENT_SETS_CHANGED", "ACTIONBAR_SLOT_CHANGED",
    "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR", "UPDATE_VEHICLE_ACTIONBAR", "UPDATE_OVERRIDE_ACTIONBAR",
    "UPDATE_MACROS",
}

-- Action bar buttons by name, for clients without ActionBarButtonEventsFrame
local BUTTON_PREFIXES = {
    "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton",
    "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button", "MultiBar8Button",
}

local highlights = setmetatable({}, { __mode = "k" }) -- [action button] = its highlight frame
local eventFrame = CreateFrame("Frame")
local callbackOwner = {}
local listening = false

local function NormalizeSetName(name)
    if type(name) ~= "string" then
        return nil
    end
    name = strtrim(name)
    return name ~= "" and strlower(name) or nil
end

-- The lower-cased names of the sets you're wearing, as keys
local function GetEquippedSetNames()
    local names = {}
    for _, setID in ipairs(C_EquipmentSet.GetEquipmentSetIDs()) do
        local name, _, _, isEquipped = C_EquipmentSet.GetEquipmentSetInfo(setID)
        local normalized = isEquipped and NormalizeSetName(name)
        if normalized then
            names[normalized] = true
        end
    end
    return names
end

-- The set an "equipmentset" action puts on: by name, or by set ID
local function GetActionSetName(actionType, actionID)
    if actionType ~= "equipmentset" then
        return nil
    end
    if type(actionID) == "number" then
        local ok, name = pcall(C_EquipmentSet.GetEquipmentSetInfo, actionID)
        return ok and name or nil
    end
    return actionID
end

local function MacroEquipsSet(macroBody, equippedNames)
    if type(macroBody) ~= "string" then
        return false
    end

    for rawLine in macroBody:gmatch("[^\r\n]+") do
        local line = strlower(rawLine)
        if line:find("^%s*/equipset%s+") or line:find("^%s*/equipmentset%s+") then
            for setName in pairs(equippedNames) do
                if line:find(setName, 1, true) then
                    return true
                end
            end
        end
    end
    return false
end

local function ButtonEquipsSet(button, equippedNames)
    if not button.action or not next(equippedNames) then
        return false
    end

    local actionType, actionID = GetActionInfo(button.action)
    local setName = NormalizeSetName(GetActionSetName(actionType, actionID))
    if setName and equippedNames[setName] then
        return true
    end

    if actionType == "macro" and type(actionID) == "number" then
        local _, _, macroBody = GetMacroInfo(actionID)
        return MacroEquipsSet(macroBody, equippedNames)
    end
    return false
end

local function ForEachActionButton(callback)
    if ActionBarButtonEventsFrame and ActionBarButtonEventsFrame.ForEachFrame then
        ActionBarButtonEventsFrame:ForEachFrame(callback)
        return
    end

    for _, prefix in ipairs(BUTTON_PREFIXES) do
        for index = 1, 12 do
            local button = _G[prefix .. index]
            if button then
                callback(button)
            end
        end
    end
end

local function GetHighlight(button)
    local highlight = highlights[button]
    if highlight then
        return highlight
    end

    local ok, created = pcall(CreateFrame, "Frame", nil, button, "ActionBarButtonAssistedCombatHighlightTemplate")
    if not ok or not created then
        return nil
    end

    highlight = created
    highlight:SetPoint("CENTER")
    if MainActionBar and MainActionBar.GetEndCapsFrameLevel then
        highlight:SetFrameLevel(math.max(1, MainActionBar:GetEndCapsFrameLevel() - 1))
    else
        highlight:SetFrameLevel(math.max(1, button:GetFrameLevel() - 1))
    end

    if highlight.Flipbook and highlight.Flipbook.Anim then
        highlight.Flipbook.Anim:Play()
        highlight.Flipbook.Anim:Stop()
    end

    highlights[button] = highlight
    return highlight
end

local function UpdateHighlights()
    local enabled = addon.db.armorSetActionHighlightEnabled
    if not enabled and not next(highlights) then
        return
    end

    local equippedNames = enabled and GetEquippedSetNames()
    ForEachActionButton(function(button)
        if enabled and ButtonEquipsSet(button, equippedNames) then
            local highlight = GetHighlight(button)
            if highlight then
                highlight:Show()
            end
        elseif highlights[button] then
            highlights[button]:Hide()
        end
    end)
end

local QueueUpdate = addon.NextFrameOnce(UpdateHighlights)
eventFrame:SetScript("OnEvent", QueueUpdate)

function addon:UpdateArmorSetHighlights()
    if not self:IsFeatureSupported("armorSetHighlight") then
        return
    end

    local enabled = self.db.armorSetActionHighlightEnabled
    if enabled and not listening then
        for _, event in ipairs(EVENTS) do
            eventFrame:RegisterEvent(event)
        end
        EventRegistry:RegisterCallback("ActionButton.OnActionChanged", QueueUpdate, callbackOwner)
        listening = true
    elseif not enabled and listening then
        eventFrame:UnregisterAllEvents()
        EventRegistry:UnregisterCallback("ActionButton.OnActionChanged", callbackOwner)
        listening = false
    end

    UpdateHighlights()
end
