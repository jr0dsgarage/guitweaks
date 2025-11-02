---@diagnostic disable: undefined-global
-- Garage UI Tweaks Settings
local addonName, addon = ...

-- Create the settings panel for Interface Options
function addon:CreateSettingsPanel()
    local panel = CreateFrame("Frame", "GarageUITweaksOptionsPanel", UIParent)
    panel.name = "Garage UI Tweaks"
    
    -- Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Garage UI Tweaks")
    
    -- Description
    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetText("Configure your UI tweaks below.")
    
    -- Enable checkbox at the top
    local enabledCheckbox = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    enabledCheckbox:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -20)
    enabledCheckbox.Text:SetText("Enable Garage UI Tweaks")
    enabledCheckbox:SetChecked(addon.db.enabled)
    enabledCheckbox:SetScript("OnClick", function(self)
        addon.db.enabled = self:GetChecked()
        print("|cff00ff00Garage UI Tweaks:|r " .. (addon.db.enabled and "Enabled" or "Disabled"))
    end)
    
    -- Quest Tracker Background tweak container
    local trackerBG = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    trackerBG:SetPoint("TOPLEFT", enabledCheckbox, "BOTTOMLEFT", 0, -20)
    trackerBG:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    trackerBG:SetHeight(80)
    trackerBG:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    
    -- Title for quest tracker background tweak
    local trackerTitle = trackerBG:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    trackerTitle:SetPoint("TOPLEFT", trackerBG, "TOPLEFT", 10, -10)
    trackerTitle:SetText("Quest Tracker Background")
    
    -- Checkbox for quest tracker background
    local objectiveBGCheckbox = CreateFrame("CheckButton", nil, trackerBG, "InterfaceOptionsCheckButtonTemplate")
    objectiveBGCheckbox:SetPoint("TOPLEFT", trackerTitle, "BOTTOMLEFT", 0, -8)
    objectiveBGCheckbox.Text:SetText("Enable Background")
    objectiveBGCheckbox:SetChecked(addon.db.objectiveTrackerBG)
    objectiveBGCheckbox:SetScript("OnClick", function(self)
        addon.db.objectiveTrackerBG = self:GetChecked()
        addon:ApplyTweaks()
    end)
    
    -- Alpha slider for background
    local alphaSlider = CreateFrame("Slider", nil, trackerBG, "OptionsSliderTemplate")
    alphaSlider:SetPoint("LEFT", objectiveBGCheckbox.Text, "RIGHT", 30, 0)
    alphaSlider:SetMinMaxValues(0, 1)
    alphaSlider:SetValue(addon.db.objectiveTrackerAlpha or 0.7)
    alphaSlider:SetValueStep(0.05)
    alphaSlider:SetObeyStepOnDrag(true)
    alphaSlider:SetWidth(150)
    alphaSlider.Low:SetText("0%")
    alphaSlider.High:SetText("100%")
    alphaSlider.Text:SetText(string.format("Opacity: %.0f%%", (addon.db.objectiveTrackerAlpha or 0.7) * 100))
    alphaSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value * 20 + 0.5) / 20  -- Round to nearest 0.05
        self.Text:SetText(string.format("Opacity: %.0f%%", value * 100))
        addon.db.objectiveTrackerAlpha = value
        if addon.db.objectiveTrackerBG then
            addon:ApplyTweaks()
        end
    end)
    
    -- Battleground Map Scale tweak container
    local bgMapScale = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    bgMapScale:SetPoint("TOPLEFT", trackerBG, "BOTTOMLEFT", 0, -10)
    bgMapScale:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    bgMapScale:SetHeight(80)
    bgMapScale:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    
    -- Title for battleground map scale tweak
    local bgMapTitle = bgMapScale:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    bgMapTitle:SetPoint("TOPLEFT", bgMapScale, "TOPLEFT", 10, -10)
    bgMapTitle:SetText("Battleground Map Scale")
    
    -- Scale slider for battleground map
    local scaleSlider = CreateFrame("Slider", nil, bgMapScale, "OptionsSliderTemplate")
    scaleSlider:SetPoint("TOPLEFT", bgMapTitle, "BOTTOMLEFT", 10, -12)
    scaleSlider:SetMinMaxValues(0.5, 2.0)
    scaleSlider:SetValue(addon.db.battlegroundMapScale or 1.0)
    scaleSlider:SetValueStep(0.1)
    scaleSlider:SetObeyStepOnDrag(true)
    scaleSlider:SetWidth(200)
    scaleSlider.Low:SetText("50%")
    scaleSlider.High:SetText("200%")
    scaleSlider.Text:SetText(string.format("Scale: %.0f%%", (addon.db.battlegroundMapScale or 1.0) * 100))
    scaleSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value * 10 + 0.5) / 10  -- Round to nearest 0.1
        self.Text:SetText(string.format("Scale: %.0f%%", value * 100))
        addon.db.battlegroundMapScale = value
        addon:ApplyTweaks()
    end)
    
    -- Add to Interface Options
    if Settings and Settings.RegisterCanvasLayoutCategory then
        -- Modern settings system (Dragonflight+)
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        addon.settingsCategory = category
    else
        -- Legacy settings system
        InterfaceOptions_AddCategory(panel)
    end
    
    addon.settingsPanel = panel
end

-- Open settings panel
function addon:OpenSettings()
    if not self.settingsPanel then
        self:CreateSettingsPanel()
    end

    if Settings and Settings.OpenToCategory then
        -- Modern settings system (Dragonflight+)
        local categoryID
        if self.settingsCategory and self.settingsCategory.GetID then
            categoryID = self.settingsCategory:GetID()
        end

        if not categoryID then
            local category = Settings.GetCategory("Garage UI Tweaks")
            if category and category.GetID then
                categoryID = category:GetID()
            end
        end

        Settings.OpenToCategory(categoryID or "Garage UI Tweaks")
    elseif InterfaceOptionsFrame_OpenToCategory then
        -- Legacy settings system - call twice to ensure it opens to correct panel
        InterfaceOptionsFrame_OpenToCategory(self.settingsPanel)
        InterfaceOptionsFrame_OpenToCategory(self.settingsPanel)
    else
        print("|cffff0000GUIT:|r Could not open settings panel")
    end
end

-- Initialize settings on PLAYER_LOGIN
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        addon:CreateSettingsPanel()
    end
end)
