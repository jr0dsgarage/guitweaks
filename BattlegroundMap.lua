---@diagnostic disable: undefined-global
-- Garage UI Tweaks - Battleground Map
local addonName, addon = ...

local function ApplyBattlegroundMapOptions()
    if not BattlefieldMapFrame or not addon.db then
        return
    end

    BattlefieldMapFrame:SetScale(addon.db.battlegroundMapScale or 1.0)

    if addon.originalBattlegroundMapStrata == nil then
        addon.originalBattlegroundMapStrata = BattlefieldMapFrame:GetFrameStrata() or "MEDIUM"
    end

    if addon.db.battlegroundMapForceLowestStrata then
        BattlefieldMapFrame:SetFrameStrata("BACKGROUND")
    else
        BattlefieldMapFrame:SetFrameStrata(addon.originalBattlegroundMapStrata)
    end
end

function addon:SetBattlegroundMapScale(scale)
    scale = scale or 1.0

    if addon.db then
        addon.db.battlegroundMapScale = scale
    end

    ApplyBattlegroundMapOptions()

    if addon.battlegroundMapHooked then
        return
    end

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_ENTERING_BATTLEGROUND")
    frame:SetScript("OnEvent", function()
        C_Timer.After(0.1, function()
            ApplyBattlegroundMapOptions()
        end)
    end)

    addon.battlegroundMapHooked = true
end
