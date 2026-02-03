---@diagnostic disable: undefined-global
-- Garage UI Tweaks - Personal Resource Display
local addonName, addon = ...

-- Visibility Logic
addon.prdVisibilityFrame = CreateFrame("Frame")
local visibilityFrame = addon.prdVisibilityFrame 

local function GetCVarSafe(cvar)
    local val = C_CVar.GetCVar(cvar)
    if val == nil then return "0" end -- Default to 0 if missing
    return val
end

local function UpdatePRDVisibility()
    -- 1. Check if our custom logic is enabled
    -- If neither option is checked, we assume the user wants standard Blizzard behavior
    -- and we should not interfere / enforce anything.
    if not addon.db.prdShowWithTargetEnemy and not addon.db.prdShowWithTargetFriendly then
        return
    end

    -- 2. Determine Desired State
    local inCombat = UnitAffectingCombat("player")
    local validTarget = false
    
    if UnitExists("target") then
        local canAttack = UnitCanAttack("player", "target")
        local canAssist = UnitCanAssist("player", "target")
        
        if addon.db.prdShowWithTargetEnemy and canAttack then
            validTarget = true
        elseif addon.db.prdShowWithTargetFriendly and canAssist then
            validTarget = true
        end
    end

    local shouldShow = inCombat or validTarget

    if shouldShow then
        -- SHOW TIME
        -- 1. Ensure Master Switch is ON (Override any previous OFF state)
        if GetCVarSafe("nameplateShowSelf") ~= "1" then
            C_CVar.SetCVar("nameplateShowSelf", "1")
        end

        -- 2. Configuration to ensure visibility
        -- If we are showing because of a Target (OOC), we must disable "Combat Only"
        if validTarget then
            if GetCVarSafe("nameplatePersonalShowInCombat") == "1" then 
                C_CVar.SetCVar("nameplatePersonalShowInCombat", "0") 
            end
            if GetCVarSafe("nameplatePersonalShowWithTarget") ~= "1" then 
                C_CVar.SetCVar("nameplatePersonalShowWithTarget", "1") 
            end
            C_CVar.SetCVar("nameplatePersonalShowAlways", "0") -- Ensure we don't force 'Always' which is annoying
        else
            -- If we are just showing due to Combat, we can let standard settings rule, 
            -- but we ensure checks are sane given we messed with them.
            -- Actually, if we set 'InCombat' to 0 previously, it stays 0. 
            -- This means "Show Always or With Target".
            -- Standard behavior usually has 'WithTarget' = 1.
        end
        
    else
        -- HIDE TIME (Not In Combat AND No Valid Target)
        -- Turn off Master Switch to force hide (fixes sticky frame bug)
        if GetCVarSafe("nameplateShowSelf") == "1" then
            C_CVar.SetCVar("nameplateShowSelf", "0")
        end
        
        -- Reset parameters to keep things clean? 
        -- Not strictly necessary if we kill the Master Switch, but good practice.
        C_CVar.SetCVar("nameplatePersonalShowAlways", "0")
        C_CVar.SetCVar("nameplatePersonalShowWithTarget", "0")
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

-- Recursively helper for a specific frame to apply texture
local function ApplyTexSimple(frame, texture, isAtlas, backgroundTexture, isBgAtlas, backgroundColor, sparkTexture, isSparkAtlas)
    if not frame then return end
    
    -- 1. Foreground Texture
    if texture then
        if frame.IsObjectType and frame:IsObjectType("StatusBar") then
            -- For StatusBars, we need to handle Atlas specially (dummy texture trick)
            if isAtlas then
                frame:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8") 
                local t = frame:GetStatusBarTexture()
                if t then 
                    t:SetAtlas(texture) 
                    t:SetAlpha(1) -- Ensure opacity
                end
            else
                frame:SetStatusBarTexture(texture)
                local t = frame:GetStatusBarTexture()
                if t then t:SetAlpha(1) end
            end
        elseif frame.SetTexture then
             -- Fallback for simple texture regions
             if isAtlas and frame.SetAtlas then
                 frame:SetAtlas(texture)
             else
                 frame:SetTexture(texture)
             end
        end
    end

    -- 2. Background
    if backgroundTexture or backgroundColor then
        local bg = frame.Background or frame.background or frame.bg or frame.bed
        
        if bg and bg.SetTexture then
            if backgroundTexture then 
                if isBgAtlas and bg.SetAtlas then
                     bg:SetAtlas(backgroundTexture)
                else
                     bg:SetTexture(backgroundTexture) 
                end
            end
            if backgroundColor then
                local c = backgroundColor
                bg:SetVertexColor(c.r, c.g, c.b, c.a or 1)
            end
        end
    end

    -- 3. Spark Logic (Clipped Container Method)
    if sparkTexture then
        local spark = frame.Spark or frame.spark

        -- Create Clipping Container
        -- This ensures the spark is visually cropped to the bar's dimensions, 
        -- similar to PlayerFrame masks but more reliable for add-on scaling.
        if not frame.garageSparkContainer then
             local c = CreateFrame("Frame", nil, frame)
             c:SetAllPoints(frame)
             if c.SetClipsChildren then c:SetClipsChildren(true) end
             c.garageIgnored = true -- Flag to prevent infinite recursion scanners
             frame.garageSparkContainer = c
        end
        
        -- Create or Adopt Spark
        if not spark and frame.IsObjectType and frame:IsObjectType("StatusBar") then
            spark = frame.garageSparkContainer:CreateTexture(nil, "OVERLAY")
            spark:SetBlendMode("ADD")
            frame.spark = spark 
        elseif spark and spark:GetParent() ~= frame.garageSparkContainer then
            -- Move existing spark into the clipping container
            spark:SetParent(frame.garageSparkContainer)
            spark:SetDrawLayer("OVERLAY", 7)
        end
        
        -- Animation Hook
        -- Moves the spark to follow the bar's value
        if not frame.garageSparkHooked and frame.IsObjectType and frame:IsObjectType("StatusBar") then
            frame:HookScript("OnValueChanged", function(self)
                 local t = self:GetStatusBarTexture()
                 local s = self.spark or self.Spark
                 if t and s then
                     s:ClearAllPoints()
                     -- Anchor RIGHT of spark to RIGHT of bar. 
                     -- This places the full spark texture inside the filled area (ending at the tip).
                     -- Solves "too far to the right" issues with wide sparks.
                     s:SetPoint("RIGHT", t, "RIGHT", 0, 0)
                 end
            end)
            frame.garageSparkHooked = true
        end

        -- Apply Spark Texture & Size
        if spark and (spark.SetTexture or spark.SetAtlas) then
             spark:Show()
             spark:SetAlpha(1)
             spark:SetBlendMode("ADD")
             
             local h = frame:GetHeight() or 20

             if isSparkAtlas and spark.SetAtlas then
                 spark:SetAtlas(sparkTexture, true) -- Start with native settings
                 
                 -- SAFELY Handle Aspect Ratio Scaling
                 -- We avoid reading spark:GetWidth or GetHeight here because accessing properties 
                 -- of elements on protected frames triggers "Secrect Value" crashes in combat.
                 -- Instead, we ask C_Texture for the raw asset data which is safe.
                 local info = C_Texture.GetAtlasInfo(sparkTexture)
                 if info and h then 
                     -- Calculate safe ratio from asset data
                     local ratio = info.width / info.height
                     
                     -- Apply calculation blindly without comparing 'h' (which might be secret)
                     -- Passing secret values to SetSize is usually permitted by the secure sandbox.
                     spark:SetSize(h * ratio, h)
                 end
             else
                 spark:SetTexture(sparkTexture)
                 -- Standard generic spark: Taller than wide, creates a vertical glow line
                 if h then
                    spark:SetSize(h * 0.8, h * 2) 
                 end
             end
        end
    end
end

local function RecursiveApplyToChildren(container, texture, isAtlas, backgroundTexture, isBgAtlas, backgroundColor, sparkTexture, isSparkAtlas)
    if not container then return end
    -- Only recurse children frames, do NOT scan regions blindly as that hits backgrounds/borders with foreground texture
    if container.GetChildren then
        local children = { container:GetChildren() }
        for _, child in ipairs(children) do
            -- infinite recursion check: do not recurse into our own specific containers
            if not child.garageIgnored then
                ApplyTexSimple(child, texture, isAtlas, backgroundTexture, isBgAtlas, backgroundColor, sparkTexture, isSparkAtlas)
                RecursiveApplyToChildren(child, texture, isAtlas, backgroundTexture, isBgAtlas, backgroundColor, sparkTexture, isSparkAtlas)
            end
        end
    end
end



-- Helper to resolve dynamic textures
local function ResolveTexture(tex, type)
    local usePlayerFrame = (tex == "::BlizzPlayer::")
    
    if not usePlayerFrame then return tex, false, nil, false end

    -- Try to find Player Frame texture
    local targetFrame
    local pf = _G.PlayerFrame
    
    if not pf then return "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill", false, nil, false end

    if type == "Alternate" then
         -- Check for Class Specific Special Bars first (Robust checking for any class)
         local _, class = UnitClass("player")
         
         -- Known mappings of global frame names for class resources
         local classFrames = {
             ["DEMONHUNTER"] = "DemonHunterSoulFragmentsBar",
             ["MONK"]        = "MonkStaggerBar", -- Also MonkHarmonyBar for Windwalker?
             ["EVOKER"]      = "EvokerEbonMightBar", -- Or EvokerEssenceBar?
             ["PALADIN"]     = "PaladinPowerBar",
             ["WARLOCK"]     = "WarlockPowerFrame",
             ["ROGUE"]       = "RogueComboPointBar",
             ["DRUID"]       = "DruidComboPointBar",
             ["MAGE"]        = "MageArcaneChargesFrame",
             ["DEATHKNIGHT"] = "RuneFrame",
         }
         
         if classFrames[class] and _G[classFrames[class]] then
             targetFrame = _G[classFrames[class]]
         end

         -- If usage of specific bar failed or didn't apply, fallback to generic search
         if not targetFrame then
             -- The main PlayerFrame Alternate Power Bar (Modern vs Classic checks)
             if pf.AlternatePowerBar then
                 targetFrame = pf.AlternatePowerBar
             elseif pf.PlayerFrameContent and pf.PlayerFrameContent.PlayerFrameContentMain then
                 -- Modern Retail Structure
                 local main = pf.PlayerFrameContent.PlayerFrameContentMain
                 if main.AlternatePowerBar then
                     targetFrame = main.AlternatePowerBar
                 elseif main.AlternatePowerBarArea and main.AlternatePowerBarArea.AlternatePowerBar then
                     targetFrame = main.AlternatePowerBarArea.AlternatePowerBar
                 end
             end
         end

    elseif type == "Health" then
         -- Health Bar
         if pf.healthBar then
             targetFrame = pf.healthBar
         elseif pf.PlayerFrameContent and pf.PlayerFrameContent.PlayerFrameContentMain and pf.PlayerFrameContent.PlayerFrameContentMain.HealthBarsContainer and pf.PlayerFrameContent.PlayerFrameContentMain.HealthBarsContainer.HealthBar then
             targetFrame = pf.PlayerFrameContent.PlayerFrameContentMain.HealthBarsContainer.HealthBar
         end

    elseif type == "Power" then 
         -- Power Bar / Mana Bar
         if pf.manabar then
             targetFrame = pf.manabar
         elseif pf.PlayerFrameContent and pf.PlayerFrameContent.PlayerFrameContentMain and pf.PlayerFrameContent.PlayerFrameContentMain.ManaBarArea and pf.PlayerFrameContent.PlayerFrameContentMain.ManaBarArea.ManaBar then
             targetFrame = pf.PlayerFrameContent.PlayerFrameContentMain.ManaBarArea.ManaBar
         end
    end

    local foundTex, foundIsAtlas = "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill", false
    local foundSpark, foundSparkIsAtlas = nil, false
    local foundBg, foundBgIsAtlas = nil, false

    if targetFrame then
        -- 1. Resolve Main Texture
        if targetFrame.GetStatusBarTexture then
            local t = targetFrame:GetStatusBarTexture()
            if t then
                if t.GetAtlas and t:GetAtlas() then 
                    foundTex, foundIsAtlas = t:GetAtlas(), true 
                elseif t.GetTexture then 
                    foundTex, foundIsAtlas = t:GetTexture(), false 
                end
            end
        elseif targetFrame.GetAtlas and targetFrame:GetAtlas() then
            foundTex, foundIsAtlas = targetFrame:GetAtlas(), true
        elseif targetFrame.GetTexture then
            foundTex, foundIsAtlas = targetFrame:GetTexture(), false
        end

        -- 2. Resolve Spark
        local sparkObj = targetFrame.Spark or targetFrame.spark
        if sparkObj then
            if sparkObj.GetAtlas and sparkObj:GetAtlas() then
                foundSpark, foundSparkIsAtlas = sparkObj:GetAtlas(), true
            elseif sparkObj.GetTexture then
                foundSpark, foundSparkIsAtlas = sparkObj:GetTexture(), false
            end
        end

        -- 3. Resolve Background (New)
        local bgObj = targetFrame.Background or targetFrame.background or targetFrame.bg
        if bgObj then
            if bgObj.GetAtlas and bgObj:GetAtlas() then
                foundBg, foundBgIsAtlas = bgObj:GetAtlas(), true
            elseif bgObj.GetTexture then
                foundBg, foundBgIsAtlas = bgObj:GetTexture(), false
            end
        end
    end

    return foundTex, foundIsAtlas, foundSpark, foundSparkIsAtlas, foundBg, foundBgIsAtlas
end


local function ApplyCustomTextures()
    -- Resolve Health
    local inputHealth = addon.db.prdMatchHealth and "::BlizzPlayer::" or addon.db.prdTextureHealth
    local texHealth, isHealthAtlas, sparkHealth, isSparkHealthAtlas, resBgHealth, isResBgHealthAtlas = ResolveTexture(inputHealth, "Health")
    local bgHealth = resBgHealth or addon.db.prdBackgroundHealth
    local isBgHealthAtlas = resBgHealth and isResBgHealthAtlas or false
    local colHealth = addon.db.prdBackgroundHealthColor
    
    -- Resolve Power
    local inputPower = addon.db.prdMatchPower and "::BlizzPlayer::" or addon.db.prdTexturePower
    local texPower, isPowerAtlas, sparkPower, isSparkPowerAtlas, resBgPower, isResBgPowerAtlas = ResolveTexture(inputPower, "Power")
    local bgPower = resBgPower or addon.db.prdBackgroundPower
    local isBgPowerAtlas = resBgPower and isResBgPowerAtlas or false
    local colPower = addon.db.prdBackgroundPowerColor
    
    -- Resolve Alternate
    local inputAlt = addon.db.prdMatchAlternate and "::BlizzPlayer::" or addon.db.prdTextureAlternate
    local texAlt, isAltAtlas, sparkAlt, isAltAtlasSpark, resBgAlt, isResBgAltAtlas = ResolveTexture(inputAlt, "Alternate")
    local bgAlt = resBgAlt or addon.db.prdBackgroundAlternate
    local isBgAltAtlas = resBgAlt and isResBgAltAtlas or false
    local colAlt = addon.db.prdBackgroundAlternateColor
    
    local plate = C_NamePlate.GetNamePlateForUnit("player")
    
    -- 1. Standard NamePlate UnitFrame (Target/Self)
    if plate and plate.UnitFrame then
        local healthBar = plate.UnitFrame.healthBar or plate.UnitFrame.HealthBar
        if healthBar then 
            ApplyTexSimple(healthBar, texHealth, isHealthAtlas, bgHealth, isBgHealthAtlas, colHealth, sparkHealth, isSparkHealthAtlas)
            
            -- Apply Texture & Color Hooks if this is safely identifiable as a Status Bar
            if healthBar.IsObjectType and healthBar:IsObjectType("StatusBar") and not healthBar.GarageHooked then
                 hooksecurefunc(healthBar, "SetStatusBarTexture", function(self, tex)
                     if self.applyingGarageTex then return end
                     -- We rely on ApplyCustomTextures to govern policy, but inside the hook 
                     -- we must re-resolve basics to avoid race conditions.
                     local input = addon.db.prdMatchHealth and "::BlizzPlayer::" or addon.db.prdTextureHealth
                     local rTex, rIsAtlas = ResolveTexture(input, "Health")
                     
                     self.applyingGarageTex = true
                     if rIsAtlas then
                          self:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
                          local t = self:GetStatusBarTexture()
                          if t then 
                              t:SetAtlas(rTex)
                              t:SetAlpha(1)
                          end
                     else
                          self:SetStatusBarTexture(rTex)
                          local t = self:GetStatusBarTexture()
                          if t then t:SetAlpha(1) end
                     end
                     self.applyingGarageTex = false
                 end)

                 hooksecurefunc(healthBar, "SetStatusBarColor", function(self, r, g, b)
                      if self.applyingGarageColor then return end
                      
                      local input = addon.db.prdMatchHealth and "::BlizzPlayer::" or addon.db.prdTextureHealth
                      local _, rIsAtlas = ResolveTexture(input, "Health")
                      
                      -- Prevent Double Tinting on Health Bar (common if using Class Color textures)
                      if rIsAtlas and (r < 0.99 or g < 0.99 or b < 0.99) then
                          self.applyingGarageColor = true
                          self:SetStatusBarColor(1, 1, 1)
                          self.applyingGarageColor = false
                      end
                 end)
                 
                 healthBar.GarageHooked = true
            end
        end
    end

    -- 2. Direct PRD Frame Access
    if PersonalResourceDisplayFrame then
        -- Health Bar Container
        if PersonalResourceDisplayFrame.HealthBarsContainer then
            RecursiveApplyToChildren(PersonalResourceDisplayFrame.HealthBarsContainer, texHealth, isHealthAtlas, bgHealth, isBgHealthAtlas, colHealth, sparkHealth, isSparkHealthAtlas)
        end
        
        -- Power Bar
        if PersonalResourceDisplayFrame.PowerBar then
            local pb = PersonalResourceDisplayFrame.PowerBar
            
            -- Recursively update children
            RecursiveApplyToChildren(pb, texPower, isPowerAtlas, bgPower, isBgPowerAtlas, colPower, sparkPower, isSparkPowerAtlas)
            
            -- Apply to self if suitable
            if pb.IsObjectType and pb:IsObjectType("StatusBar") then
                ApplyTexSimple(pb, texPower, isPowerAtlas, bgPower, isBgPowerAtlas, colPower, sparkPower, isSparkPowerAtlas)
            end

            -- Persist Texture Hook
            if pb.IsObjectType and pb:IsObjectType("StatusBar") and not pb.GarageHooked then
                 hooksecurefunc(pb, "SetStatusBarTexture", function(self, tex)
                     if self.applyingGarageTex then return end
                     
                     local input = addon.db.prdMatchPower and "::BlizzPlayer::" or addon.db.prdTexturePower
                     local rTex, rIsAtlas = ResolveTexture(input, "Power")
                     
                     self.applyingGarageTex = true
                     if rIsAtlas then
                         self:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
                         local t = self:GetStatusBarTexture()
                         if t then 
                             t:SetAtlas(rTex) 
                             t:SetAlpha(1)
                         end
                     else
                         self:SetStatusBarTexture(rTex)
                         local t = self:GetStatusBarTexture()
                         if t then t:SetAlpha(1) end
                     end
                     self.applyingGarageTex = false
                 end)

                 hooksecurefunc(pb, "SetStatusBarColor", function(self, r, g, b)
                      if self.applyingGarageColor then return end
                      
                      local input = addon.db.prdMatchPower and "::BlizzPlayer::" or addon.db.prdTexturePower
                      local _, rIsAtlas = ResolveTexture(input, "Power")
                      
                      if rIsAtlas and (r < 0.99 or g < 0.99 or b < 0.99) then
                          self.applyingGarageColor = true
                          self:SetStatusBarColor(1, 1, 1)
                          self.applyingGarageColor = false
                      end
                 end)

                 pb.GarageHooked = true
            end
        end

        -- Alternate Power Bar (The "Third Bar" for some classes)
        if PersonalResourceDisplayFrame.AlternatePowerBar then
             local apb = PersonalResourceDisplayFrame.AlternatePowerBar
             
             -- Apply logic to usage of specific bar or container
             RecursiveApplyToChildren(apb, texAlt, isAltAtlas, bgAlt, isBgAltAtlas, colAlt, sparkAlt, isAltAtlasSpark)
             
             -- Apply to the top-level frame itself (if it is a status bar)
             if apb.IsObjectType and apb:IsObjectType("StatusBar") then
                  ApplyTexSimple(apb, texAlt, isAltAtlas, bgAlt, isBgAltAtlas, colAlt, sparkAlt, isAltAtlasSpark)
             end

             -- Persist Texture Hook (Prevents Blizzard from reverting changes)
             if apb.IsObjectType and apb:IsObjectType("StatusBar") and not apb.GarageHooked then
                  hooksecurefunc(apb, "SetStatusBarTexture", function(self, tex)
                      if self.applyingGarageTex then return end
                      
                      -- Retrieve current intended settings dynamically
                      local input = addon.db.prdMatchAlternate and "::BlizzPlayer::" or addon.db.prdTextureAlternate
                      local rTex, rIsAtlas = ResolveTexture(input, "Alternate")
                      
                      self.applyingGarageTex = true
                      if rIsAtlas then
                          self:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
                          local t = self:GetStatusBarTexture()
                          if t then 
                              t:SetAtlas(rTex) 
                              t:SetAlpha(1)
                          end
                      else
                          self:SetStatusBarTexture(rTex)
                          local t = self:GetStatusBarTexture()
                          if t then t:SetAlpha(1) end
                      end
                      self.applyingGarageTex = false
                  end)

                  -- Prevent Double Tinting on Atlas Textures
                  -- Standard UI logic tints the bar (e.g., Purple for Soul Shards), but modern Atlas assets 
                  -- are often pre-colored. Tinting them makes them dark/muddy compared to PlayerFrame.
                  hooksecurefunc(apb, "SetStatusBarColor", function(self, r, g, b)
                       if self.applyingGarageColor then return end
                       
                       local input = addon.db.prdMatchAlternate and "::BlizzPlayer::" or addon.db.prdTextureAlternate
                       local _, rIsAtlas = ResolveTexture(input, "Alternate")
                       
                       -- Only force native color (White) if we are using an Atlas and the game is trying to tint it
                       if rIsAtlas and (r < 0.99 or g < 0.99 or b < 0.99) then
                           self.applyingGarageColor = true
                           self:SetStatusBarColor(1, 1, 1)
                           self.applyingGarageColor = false
                       end
                  end)

                  apb.GarageHooked = true
             end
        end
    end

    -- 3. Class Resource / Mana Bar (Secondary Power)
    -- Often used for Combo Points, Holy Power, OR Mana on non-mana classes
    if ClassNameplateManaBarFrame then
         RecursiveApplyToChildren(ClassNameplateManaBarFrame, texAlt, isAltAtlas, bgAlt, false, colAlt, sparkAlt, isAltAtlasSpark)
    end
end


local function OnNamePlateAdded(unit)
    if UnitIsUnit(unit, "player") then
        ApplyCustomTextures()
        C_Timer.After(0.1, ApplyCustomTextures)
    end
end


textureFrame:SetScript("OnEvent", function(self, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then
        OnNamePlateAdded(unit)
    elseif event == "PLAYER_ENTERING_WORLD" then
        ApplyCustomTextures()
    end
end)

function addon:UpdatePRDTextures()
    -- Always run if we have any settings
    if (addon.db.prdTextureHealth or addon.db.prdBackgroundHealth or addon.db.prdTexturePower or addon.db.prdBackgroundPower or addon.db.prdTextureAlternate or addon.db.prdBackgroundAlternate) then
       textureFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
       textureFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
       ApplyCustomTextures()
    else
       textureFrame:UnregisterAllEvents()
    end
end
