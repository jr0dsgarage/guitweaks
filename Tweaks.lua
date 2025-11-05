---@diagnostic disable: undefined-global
-- Garage UI Tweaks - Shared Tweak Coordinator
local addonName, addon = ...

function addon:ApplyTweaks()
    if not self.db then
        return
    end

    self:SetErrorTextBackground(self.db.errorTextBackgroundEnabled, self.db.errorTextBackgroundAlpha, self.db.errorTextBackgroundDuration)
    self:SetBattlegroundMapScale(self.db.battlegroundMapScale)
    self:SetSpeedPanelEnabled(self.db.speedPanelEnabled)
end
