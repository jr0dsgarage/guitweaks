---@diagnostic disable: undefined-global
-- Garage UI Tweaks - Personal Resource Display
local addonName, addon = ...

-- Visibility Logic
local visibilityFrame = CreateFrame("Frame")
local isOverriding = false
local originalShowInCombat = "1"

local function UpdatePRDVisibility()
    -- Only intervene if one of our override settings is enabled
    if not addon.db.prdShowWithTargetEnemy and not addon.db.prdShowWithTargetFriendly then
        -- If we were overriding but settings got turned off, try to cleanup
        if isOverriding then
            C_CVar.SetCVar("nameplatePersonalShowInCombat", originalShowInCombat)
            C_CVar.SetCVar("nameplatePersonalShowAlways", "0")
            isOverriding = false
        end
        return
    end

    local shouldShow = false
    if UnitExists("target") then
        if addon.db.prdShowWithTargetEnemy and UnitIsEnemy("player", "target") then
            shouldShow = true
        elseif addon.db.prdShowWithTargetFriendly and not UnitIsEnemy("player", "target") then
            shouldShow = true
        end
    end

    if shouldShow then
        if not isOverriding then
            originalShowInCombat = C_CVar.GetCVar("nameplatePersonalShowInCombat")
            isOverriding = true
        end
        -- We must disable "Only In Combat" restriction to show it out of combat
        C_CVar.SetCVar("nameplatePersonalShowInCombat", "0")
        C_CVar.SetCVar("nameplatePersonalShowAlways", "1")
        C_CVar.SetCVar("nameplateShowSelf", "1")
    else
        if isOverriding then
            C_CVar.SetCVar("nameplatePersonalShowInCombat", originalShowInCombat)
            isOverriding = false
        end
        C_CVar.SetCVar("nameplatePersonalShowAlways", "0")
    end
end

visibilityFrame:SetScript("OnEvent", function(self, event)
    UpdatePRDVisibility() 
end)

function addon:SetPRDVisibilityOptions()
    if addon.db.prdShowWithTargetEnemy or addon.db.prdShowWithTargetFriendly then
        visibilityFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
        visibilityFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
        visibilityFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        visibilityFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        UpdatePRDVisibility()
    else
        visibilityFrame:UnregisterAllEvents()
        UpdatePRDVisibility() -- Triggers the cleanup logic inside
    end
end

-- Texture Handling
local textureFrame = CreateFrame("Frame")
local currentTexture

local function ApplyTextureToFrame(frame, texture)
    if not texture then return end
    
    -- Try to find the health bar on the NamePlate frame
    local healthBar = frame.UnitFrame and frame.UnitFrame.healthBar
        or frame.healthBar
        or (frame.UnitFrame and frame.UnitFrame.HealthBar)
    
    if healthBar then
        healthBar:SetStatusBarTexture(texture)
        -- Sometimes the background needs updating too to match style, but sticking to bar for now.
    end

    -- Castbar
    local castBar = frame.UnitFrame and frame.UnitFrame.castBar
        or frame.castBar
        or (frame.UnitFrame and frame.UnitFrame.CastBar)
        
    if castBar then
        castBar:SetStatusBarTexture(texture)
    end
end

local function OnNamePlateAdded(unit)
    if UnitIsUnit(unit, "player") then
        local plate = C_NamePlate.GetNamePlateForUnit("player")
        if plate then
            ApplyTextureToFrame(plate, currentTexture)
        end
        -- Handle Class Resource / Mana Bar (which is often separate)
        if ClassNameplateManaBarFrame then
             ClassNameplateManaBarFrame:SetStatusBarTexture(currentTexture)
        end
    end
end

textureFrame:SetScript("OnEvent", function(self, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then
        OnNamePlateAdded(unit)
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Reapply if needed
        local plate = C_NamePlate.GetNamePlateForUnit("player")
        if plate then ApplyTextureToFrame(plate, currentTexture) end
        if ClassNameplateManaBarFrame then
             ClassNameplateManaBarFrame:SetStatusBarTexture(currentTexture)
        end
    end
end)

function addon:SetPRDTexture(texture)
    currentTexture = texture
    if texture and texture ~= "" then
       textureFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
       textureFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
       -- Try to apply immediately
       local plate = C_NamePlate.GetNamePlateForUnit("player")
       if plate then ApplyTextureToFrame(plate, currentTexture) end
       if ClassNameplateManaBarFrame then
            ClassNameplateManaBarFrame:SetStatusBarTexture(currentTexture)
       end
    else
       textureFrame:UnregisterAllEvents()
    end
end
