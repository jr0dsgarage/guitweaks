---@diagnostic disable: undefined-global
-- Garage UI Tweaks - Personal Resource Display
local addonName, addon = ...

local prdFrame = CreateFrame("Frame")
local isEnabled = false

local function updatePRD(forceState)
    local shouldShow
    if forceState ~= nil then
        shouldShow = forceState
    else
        shouldShow = InCombatLockdown()
    end

    if shouldShow then
        C_CVar.SetCVar("nameplateShowSelf", "1")
    else
        C_CVar.SetCVar("nameplateShowSelf", "0")
    end
end

prdFrame:SetScript("OnEvent", function(self, event)
    if isEnabled then
        if event == "PLAYER_REGEN_DISABLED" then
            updatePRD(true)
        elseif event == "PLAYER_REGEN_ENABLED" then
            updatePRD(false)
        else
            updatePRD()
        end
    end
end)

function addon:SetPersonalResourceDisplayCombatOnly(enabled)
    isEnabled = enabled
    if enabled then
        prdFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
        prdFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        prdFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        updatePRD()
    else
        prdFrame:UnregisterEvent("PLAYER_REGEN_DISABLED")
        prdFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
        prdFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
        -- Restore visibility when disabling the tweak, consistent with default UI behavior
        -- Note: User might manually want it off, but enabling "combat only" implies they want it somewhat managed.
        -- When disabling this specific tweak, we default to "Show" (1) so it doesn't get stuck hidden.
        C_CVar.SetCVar("nameplateShowSelf", "1")
    end
end
