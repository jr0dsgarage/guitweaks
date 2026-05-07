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

-- Returns a string key identifying the current profession for DB storage.
-- Prefers info.profession (Enum.Profession – stable across expansions),
-- then falls back to parentProfessionID / professionID.
local function GetProfessionKey()
    if not ProfessionsFrame or not ProfessionsFrame.professionInfo then return nil end
    local info = ProfessionsFrame.professionInfo
    local key = info.profession
    if not key or key == 0 then key = info.parentProfessionID end
    if not key or key == 0 then key = info.professionID end
    if not key or key == 0 then return nil end
    return tostring(key)
end

local function RefreshActiveProfessionKey()
    activeProfessionKey = GetProfessionKey()
    return activeProfessionKey
end

local function SaveOrderFilters(professionKey)
    if not (addon.db and addon.db.rememberCraftingOrderFilters) then return end
    local profKey = professionKey or activeProfessionKey or RefreshActiveProfessionKey()
    if not profKey then return end

    if not addon.db.craftingOrderFilters then
        addon.db.craftingOrderFilters = {}
    end

    local saved = {}

    -- C_TradeSkillUI.GetRecipeFilters() returns the current recipe list
    -- filter table, including fields like hasMaterials, hasSkillUp,
    -- isOnCooldown, and isTrivial.
    if C_TradeSkillUI and C_TradeSkillUI.GetRecipeFilters then
        local ok, filters = pcall(C_TradeSkillUI.GetRecipeFilters)
        if ok and type(filters) == "table" then
            saved.recipeFilters = {}
            for k, v in pairs(filters) do
                saved.recipeFilters[k] = v
            end
        end
    end

    addon.db.craftingOrderFilters[profKey] = saved
end

local function RestoreOrderFilters()
    if not (addon.db and addon.db.rememberCraftingOrderFilters) then return end
    if not ProfessionsFrame then return end
    local profKey = RefreshActiveProfessionKey()
    if not profKey then return end
    if not addon.db.craftingOrderFilters then return end

    local saved = addon.db.craftingOrderFilters[profKey]
    if not saved or not saved.recipeFilters then return end

    -- Apply the saved recipe filters.
    -- C_TradeSkillUI.SetRecipeFilters internally fires TRADE_SKILL_LIST_UPDATE,
    -- which causes the orders-page recipe list to regenerate with the restored
    -- filter state.  The RunNextFrame(StartDefaultSearch) queued by OnShow then
    -- sends the order request using those same filters.
    if C_TradeSkillUI and C_TradeSkillUI.SetRecipeFilters then
        pcall(C_TradeSkillUI.SetRecipeFilters, saved.recipeFilters)
    end
end

local function SetupCraftingHooks()
    if craftingHooksApplied then return end
    if not ProfessionsFrame or not ProfessionsFrame.OrdersPage then return end

    -- Track active profession whenever the main window opens.
    ProfessionsFrame:HookScript("OnShow", function(self)
        RefreshActiveProfessionKey()
    end)

    -- Save filters when the professions panel closes.
    ProfessionsFrame:HookScript("OnHide", function(self)
        SaveOrderFilters(activeProfessionKey)
    end)

    -- Track profession changes and re-apply filters if Orders is currently open.
    EventRegistry:RegisterCallback("Professions.ProfessionSelected", function(_, profInfo)
        local previousKey = activeProfessionKey
        local nextKey = RefreshActiveProfessionKey()

        if previousKey and previousKey ~= nextKey then
            SaveOrderFilters(previousKey)
        end

        if ProfessionsFrame and ProfessionsFrame.OrdersPage and ProfessionsFrame.OrdersPage:IsShown() then
            RestoreOrderFilters()
        end
    end, addon)

    -- Save filters whenever the Orders page is hidden, which covers both
    -- switching away from the Orders tab and closing the profession window.
    ProfessionsFrame.OrdersPage:HookScript("OnHide", function(self)
        SaveOrderFilters()
    end)

    -- Always restore saved filters whenever the Orders page is shown.
    -- This fires before Blizzard's queued order search, so restored state is
    -- in place when the request runs.
    ProfessionsFrame.OrdersPage:HookScript("OnShow", function(self)
        RestoreOrderFilters()
    end)

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
local function OnBlizzardProfessionsLoaded()
    -- A zero-second timer lets all OnLoad scripts finish before we hook.
    C_Timer.After(0, SetupCraftingHooks)
end

local craftingEventFrame = CreateFrame("Frame")
craftingEventFrame:RegisterEvent("ADDON_LOADED")
craftingEventFrame:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        if name == "Blizzard_Professions" then
            OnBlizzardProfessionsLoaded()
        end
    end
end)

-- In case Blizzard_Professions loaded before us (unusual but possible).
if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_Professions") then
    OnBlizzardProfessionsLoaded()
end
