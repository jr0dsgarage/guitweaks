---@diagnostic disable: undefined-global
-- Garage UI Tweaks - Battleground Map
local addonName, addon = ...

function addon:SetBattlegroundMapScale(scale)
    scale = scale or 1.0

    if BattlefieldMapFrame then
        BattlefieldMapFrame:SetScale(scale)
    end

    if addon.battlegroundMapHooked then
        return
    end

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_ENTERING_BATTLEGROUND")
    frame:SetScript("OnEvent", function()
        C_Timer.After(0.1, function()
            if BattlefieldMapFrame and addon.db and addon.db.battlegroundMapScale then
                BattlefieldMapFrame:SetScale(addon.db.battlegroundMapScale)
            end
        end)
    end)

    addon.battlegroundMapHooked = true
end
