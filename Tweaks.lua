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
    self:UpdatePRDTextures()
    self:SetPRDVisibilityOptions()
    self:InitChatTweaks()
    self:UpdateOverrideActionBar()

    -- Nameplate Tweaks
    self:UpdateNameplateScale()

    if self.db.nameplateUseClassColorForFriendlyPlayerUnitNames ~= nil then
        local val = self.db.nameplateUseClassColorForFriendlyPlayerUnitNames and "1" or "0"
        if C_CVar and C_CVar.SetCVar then
             pcall(function() C_CVar.SetCVar("nameplateUseClassColorForFriendlyPlayerUnitNames", val) end)
        elseif SetCVar then
             pcall(function() SetCVar("nameplateUseClassColorForFriendlyPlayerUnitNames", val) end)
        end
        if ConsoleExec then ConsoleExec("nameplateUseClassColorForFriendlyPlayerUnitNames " .. val) end
    end
end

function addon:UpdateNameplateScale()
    if not self.db.nameplateSimplifiedScale then return end
    
    local scale = self.db.nameplateSimplifiedScale
    
    -- Local helper to apply scale
    -- We'll attach this helper to addon to reuse it
    if not self.ApplyScaleToFrame then
        self.ApplyScaleToFrame = function(frame)
             if not frame or not frame.unit then return end
             -- Only apply to friendly players (Simplified Nameplates usually)
             -- UnitIsPlayer checks if it is a player character
             -- UnitReaction > 4 is Friendly (5) or higher
             if UnitIsPlayer(frame.unit) and UnitReaction(frame.unit, "player") > 4 then
                  if not InCombatLockdown() then
                      frame:SetScale(scale)
                  end
             end
        end
    end

    if not self.nameplateHooked then
        self.nameplateHooked = true
        
        -- Hook just in case for other events
        local f = CreateFrame("Frame")
        f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
        f:SetScript("OnEvent", function(_, _, unit)
             local frame = C_NamePlate.GetNamePlateForUnit(unit)
             addon.ApplyScaleToFrame(frame)
        end)
    end
    
    -- Update existing
    for _, frame in pairs(C_NamePlate.GetNamePlates()) do
         addon.ApplyScaleToFrame(frame)
    end
end

function addon:UpdateOverrideActionBar()
    if InCombatLockdown() then return end
    if not OverrideActionBar then return end
    
    local offset = self.db.overrideActionBarYOffset or 0
    OverrideActionBar:ClearAllPoints()
    OverrideActionBar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, offset)
end
