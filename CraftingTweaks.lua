---@diagnostic disable: undefined-global
-- Garage UI Tweaks - Crafting Tweaks
local addonName, addon = ...

-- ============================================================
-- Crafting Order Filter Memory
-- Remembers the recipe filter state (Have Materials, Has Skill Up,
-- etc.) on the Crafting Orders tab per profession across sessions.
-- Each profession is keyed by its Enum.Profession value so that
-- filters persist across expansion skill-line changes.
-- ============================================================

local craftingHooksApplied = false
local activeProfessionKey = nil
local isRestoringFilters = false
local saveDebounceTimer = nil

-- Forward declarations used by the early event-frame callback.
local OnBlizzardProfessionsLoaded
local ScheduleSave
local SaveOrderFilters

-- Create the event frame early so SetupCraftingHooks() can register events on it.
local craftingEventFrame = CreateFrame("Frame")
craftingEventFrame:RegisterEvent("ADDON_LOADED")
craftingEventFrame:RegisterEvent("PLAYER_LOGOUT")
craftingEventFrame:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        if name == "Blizzard_Professions" then
            OnBlizzardProfessionsLoaded()
        end
    elseif event == "TRADE_SKILL_LIST_UPDATE" then
        ScheduleSave()
    elseif event == "PLAYER_LOGOUT" then
        SaveOrderFilters(activeProfessionKey, false)
    end
end)

local function AddKey(keys, seen, value)
    if value and value ~= 0 then
        local key = tostring(value)
        if not seen[key] then
            seen[key] = true
            table.insert(keys, key)
        end
    end
end

local function GetProfessionKeysFromInfo(info)
    local keys, seen = {}, {}
    if type(info) ~= "table" then
        return keys
    end

    -- Prefer Enum.Profession, but store aliases so restore still works if
    -- Blizzard only exposes parentProfessionID/professionID at a later time.
    AddKey(keys, seen, info.profession)
    AddKey(keys, seen, info.parentProfessionID)
    AddKey(keys, seen, info.professionID)
    return keys
end

local function GetActiveProfessionKeys()
    if not ProfessionsFrame or not ProfessionsFrame.professionInfo then
        return {}
    end
    return GetProfessionKeysFromInfo(ProfessionsFrame.professionInfo)
end

-- Returns a string key identifying the current profession for DB storage.
-- Prefers info.profession (Enum.Profession – stable across expansions),
-- then falls back to parentProfessionID / professionID.
local function GetProfessionKey()
    local keys = GetActiveProfessionKeys()
    return keys[1]
end

local function RefreshActiveProfessionKey()
    activeProfessionKey = GetProfessionKey()
    return activeProfessionKey
end

local function PrintFiltersSavedNotice()
    if addon and addon.Print then
        addon:Print("|cff00ff00[guit]|r |cfffffffffilters saved|r")
    elseif DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[guit]|r |cfffffffffilters saved|r")
    else
        print("|cff00ff00[guit]|r |cfffffffffilters saved|r")
    end
end

-- Collect the current filter state from every available source.
-- Returns a table or nil if nothing could be read.
local function GetOrdersFilterButtons()
    local out = {}
    local seen = {}
    local ordersPage = ProfessionsFrame and ProfessionsFrame.OrdersPage
    local recipeList = ordersPage and ordersPage.RecipeList
    local root = recipeList and recipeList.FilterBar
    if not root then
        return out
    end

    local function walk(frame)
        if not frame or seen[frame] then
            return
        end
        seen[frame] = true

        local isCheckButton = frame.IsObjectType and frame:IsObjectType("CheckButton")
        if isCheckButton and frame.GetChecked then
            table.insert(out, frame)
        end

        if frame.GetChildren then
            for _, child in ipairs({ frame:GetChildren() }) do
                walk(child)
            end
        end
    end

    walk(root)
    return out
end

local function GetButtonStateKey(button)
    if not button then
        return nil
    end
    if button.filterType ~= nil then
        return "filterType:" .. tostring(button.filterType)
    end
    if button.GetName and button:GetName() then
        return "name:" .. tostring(button:GetName())
    end
    return nil
end

local function CollectCurrentFilters()
    local recipeFilters = nil

    -- Primary: C_TradeSkillUI.GetRecipeFilters (works when a trade skill is open)
    if C_TradeSkillUI and C_TradeSkillUI.GetRecipeFilters then
        local ok, filters = pcall(C_TradeSkillUI.GetRecipeFilters)
        if ok and type(filters) == "table" and next(filters) ~= nil then
            recipeFilters = {}
            for k, v in pairs(filters) do
                recipeFilters[k] = v
            end
        end
    end

    -- Fallback snapshot: capture Orders-page filter checkbox states by stable key.
    local uiFilterState = {}
    local anyUiState = false
    for _, button in ipairs(GetOrdersFilterButtons()) do
        local key = GetButtonStateKey(button)
        if key then
            uiFilterState[key] = button:GetChecked() and true or false
            anyUiState = true
        end
    end
    if not anyUiState then
        uiFilterState = nil
    end

    return recipeFilters, uiFilterState
end

local function ApplyUIFilterState(uiFilterState)
    if type(uiFilterState) ~= "table" then
        return false
    end

    local changed = false
    for _, button in ipairs(GetOrdersFilterButtons()) do
        local key = GetButtonStateKey(button)
        if key and uiFilterState[key] ~= nil then
            local desired = uiFilterState[key] and true or false
            local current = button:GetChecked() and true or false
            if desired ~= current then
                if button.SetChecked then
                    button:SetChecked(desired)
                end
                if button.Click then
                    button:Click()
                elseif button:GetScript("OnClick") then
                    button:GetScript("OnClick")(button)
                end
                changed = true
            end
        end
    end

    return changed
end

SaveOrderFilters = function(professionKey, notify)
    if not (addon.db and addon.db.rememberCraftingOrderFilters) then return end

    local aliases = GetActiveProfessionKeys()
    local profKey = professionKey or activeProfessionKey or RefreshActiveProfessionKey()
    if not profKey and type(aliases) == "table" then
        profKey = aliases[1]
    end
    if not profKey then return end

    local recipeFilters, uiFilterState = CollectCurrentFilters()
    -- If we still have nothing, keep the last known state rather than saving empty.
    if not recipeFilters and not uiFilterState then
        if not isRestoringFilters and notify then
            addon:Print("|cffff8000[guit]|r crafting filter state unavailable — nothing saved")
        end
        return
    end

    if not addon.db.craftingOrderFilters then
        addon.db.craftingOrderFilters = {}
    end

    local saved = {
        recipeFilters = recipeFilters,
        uiFilterState = uiFilterState,
    }

    local allKeys = {}
    local seen = {}
    AddKey(allKeys, seen, profKey)
    for _, key in ipairs(aliases) do
        AddKey(allKeys, seen, key)
    end
    for _, key in ipairs(allKeys) do
        addon.db.craftingOrderFilters[key] = saved
    end

    -- Global fallback for when profession keys differ after relog.
    if recipeFilters then
        addon.db.lastCraftingOrderRecipeFilters = recipeFilters
    end

    if not isRestoringFilters and notify then
        PrintFiltersSavedNotice()
    end
end

-- Debounced save triggered by TRADE_SKILL_LIST_UPDATE so we capture
-- filter changes the moment Blizzard refreshes the recipe list.
ScheduleSave = function()
    if isRestoringFilters then return end
    if not (ProfessionsFrame and ProfessionsFrame.OrdersPage and ProfessionsFrame.OrdersPage:IsShown()) then return end
    if saveDebounceTimer then
        saveDebounceTimer:Cancel()
    end
    saveDebounceTimer = C_Timer.NewTimer(0.3, function()
        saveDebounceTimer = nil
        SaveOrderFilters(activeProfessionKey, true)   -- true = show chat notice
    end)
end

local function RestoreOrderFilters()
    if not (addon.db and addon.db.rememberCraftingOrderFilters) then return end
    if not ProfessionsFrame then return end
    local profKey = RefreshActiveProfessionKey()
    if not profKey then return end
    if not addon.db.craftingOrderFilters then return end

    local saved = addon.db.craftingOrderFilters[profKey]
    if (not saved or not saved.recipeFilters) and ProfessionsFrame and ProfessionsFrame.professionInfo then
        local aliases = GetProfessionKeysFromInfo(ProfessionsFrame.professionInfo)
        for _, alias in ipairs(aliases) do
            local candidate = addon.db.craftingOrderFilters[alias]
            if candidate and candidate.recipeFilters then
                saved = candidate
                break
            end
        end
    end

    if (not saved or not saved.recipeFilters) and type(addon.db.lastCraftingOrderRecipeFilters) == "table" then
        saved = { recipeFilters = addon.db.lastCraftingOrderRecipeFilters }
    end

    if not saved then return end

    -- Apply the saved recipe filters.
    -- C_TradeSkillUI.SetRecipeFilters internally fires TRADE_SKILL_LIST_UPDATE,
    -- which causes the orders-page recipe list to regenerate with the restored
    -- filter state.  The RunNextFrame(StartDefaultSearch) queued by OnShow then
    -- sends the order request using those same filters.
    if C_TradeSkillUI and C_TradeSkillUI.SetRecipeFilters and saved.recipeFilters then
        isRestoringFilters = true
        pcall(C_TradeSkillUI.SetRecipeFilters, saved.recipeFilters)
        isRestoringFilters = false
    end

    -- Orders-only fallback: restore by directly setting filter checkbuttons.
    if saved.uiFilterState then
        isRestoringFilters = true
        ApplyUIFilterState(saved.uiFilterState)
        isRestoringFilters = false
    end
end

local function SetupCraftingHooks()
    if craftingHooksApplied then return end
    if not ProfessionsFrame or not ProfessionsFrame.OrdersPage then return end

    -- Track active profession whenever the main window opens.
    ProfessionsFrame:HookScript("OnShow", function(self)
        RefreshActiveProfessionKey()
    end)

    -- Silent save when the main professions panel closes.
    ProfessionsFrame:HookScript("OnHide", function(self)
        SaveOrderFilters(activeProfessionKey, false)
    end)

    -- Track profession changes and re-apply filters if Orders is currently open.
    EventRegistry:RegisterCallback("Professions.ProfessionSelected", function(_, profInfo)
        local previousKey = activeProfessionKey
        local nextKey = RefreshActiveProfessionKey()

        if previousKey and previousKey ~= nextKey then
            SaveOrderFilters(previousKey, false)
        end

        if ProfessionsFrame and ProfessionsFrame.OrdersPage and ProfessionsFrame.OrdersPage:IsShown() then
            RestoreOrderFilters()
        end
    end, addon)

    -- Silent save when leaving the Orders tab.
    ProfessionsFrame.OrdersPage:HookScript("OnHide", function(self)
        if saveDebounceTimer then
            saveDebounceTimer:Cancel()
            saveDebounceTimer = nil
        end
        SaveOrderFilters(activeProfessionKey, false)
    end)

    -- Restore saved filters whenever the Orders page is shown.
    ProfessionsFrame.OrdersPage:HookScript("OnShow", function(self)
        RestoreOrderFilters()
    end)

    -- TRADE_SKILL_LIST_UPDATE fires when Blizzard refreshes the recipe list
    -- after a filter checkbox changes.  We debounce briefly so rapid toggling
    -- produces one save, not dozens.
    craftingEventFrame:RegisterEvent("TRADE_SKILL_LIST_UPDATE")

    craftingHooksApplied = true
end

-- Re-setup function exposed so Settings can call it if the option is toggled on.
function addon:SetCraftingOrderFilterMemoryEnabled(enabled)
    addon.db.rememberCraftingOrderFilters = enabled
    if enabled then
        SetupCraftingHooks()
    end
end

-- Apply hooks once Blizzard_Professions has loaded.
-- Blizzard_Professions is loaded on demand (first profession open), so we
-- listen for ADDON_LOADED.  We also handle the case where it is already loaded.
OnBlizzardProfessionsLoaded = function()
    -- A zero-second timer lets all OnLoad scripts finish before we hook.
    C_Timer.After(0, SetupCraftingHooks)
end

-- In case Blizzard_Professions loaded before us (unusual but possible).
if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_Professions") then
    OnBlizzardProfessionsLoaded()
end
