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
    
    -- Error text background container
    local errorBG = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    errorBG:SetPoint("TOPLEFT", enabledCheckbox, "BOTTOMLEFT", 0, -20)
    errorBG:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    errorBG:SetHeight(120)
    errorBG:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })

    local errorTitle = errorBG:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    errorTitle:SetPoint("TOPLEFT", errorBG, "TOPLEFT", 10, -10)
    errorTitle:SetText("Error Text Background")

    local errorCheckbox = CreateFrame("CheckButton", nil, errorBG, "InterfaceOptionsCheckButtonTemplate")
    errorCheckbox:SetPoint("TOPLEFT", errorTitle, "BOTTOMLEFT", 0, -8)
    errorCheckbox.Text:SetText("Enable Background")
    errorCheckbox:SetChecked(addon.db.errorTextBackgroundEnabled)

    local alphaSlider = CreateFrame("Slider", nil, errorBG, "OptionsSliderTemplate")
    alphaSlider:SetPoint("LEFT", errorCheckbox.Text, "RIGHT", 30, 0)
    alphaSlider:SetMinMaxValues(0, 1)
    alphaSlider:SetValue(addon.db.errorTextBackgroundAlpha or 0.7)
    alphaSlider:SetValueStep(0.05)
    alphaSlider:SetObeyStepOnDrag(true)
    alphaSlider:SetWidth(150)
    alphaSlider.Low:SetText("0%")
    alphaSlider.High:SetText("100%")
    alphaSlider.Text:SetText(string.format("Opacity: %.0f%%", (addon.db.errorTextBackgroundAlpha or 0.7) * 100))

    local durationSlider = CreateFrame("Slider", nil, errorBG, "OptionsSliderTemplate")
    durationSlider:SetPoint("TOPLEFT", errorCheckbox, "BOTTOMLEFT", 0, -28)
    durationSlider:SetWidth(200)
    durationSlider:SetMinMaxValues(1, 5)
    durationSlider:SetValue(addon.db.errorTextBackgroundDuration or 3.0)
    durationSlider:SetValueStep(0.1)
    durationSlider:SetObeyStepOnDrag(true)
    durationSlider.Low:SetText("1s")
    durationSlider.High:SetText("5s")
    durationSlider.Text:SetText(string.format("Duration: %.1fs", addon.db.errorTextBackgroundDuration or 3.0))

    local errorInfo = errorBG:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    errorInfo:SetPoint("TOPLEFT", durationSlider, "BOTTOMLEFT", -10, -8)
    errorInfo:SetPoint("RIGHT", errorBG, "RIGHT", -12, 0)
    errorInfo:SetJustifyH("LEFT")
    errorInfo:SetText("Draws a backdrop behind UI errors briefly to improve visibility, then hides it automatically.")

    local function UpdateErrorBackgroundControls()
        local enabled = addon.db.errorTextBackgroundEnabled
        errorCheckbox:SetChecked(enabled)
        alphaSlider:SetEnabled(enabled)
        durationSlider:SetEnabled(enabled)

        local textColor = enabled and 1 or 0.5
        alphaSlider.Text:SetTextColor(textColor, textColor, textColor)
        durationSlider.Text:SetTextColor(textColor, textColor, textColor)
    end

    errorCheckbox:SetScript("OnClick", function(self)
        addon.db.errorTextBackgroundEnabled = self:GetChecked()
        addon:SetErrorTextBackground(addon.db.errorTextBackgroundEnabled, addon.db.errorTextBackgroundAlpha, addon.db.errorTextBackgroundDuration)
        UpdateErrorBackgroundControls()
    end)

    alphaSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value * 20 + 0.5) / 20
        self.Text:SetText(string.format("Opacity: %.0f%%", value * 100))
        addon.db.errorTextBackgroundAlpha = value
        addon:SetErrorTextBackground(addon.db.errorTextBackgroundEnabled, addon.db.errorTextBackgroundAlpha, addon.db.errorTextBackgroundDuration)
    end)

    durationSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value * 10 + 0.5) / 10
        self.Text:SetText(string.format("Duration: %.1fs", value))
        addon.db.errorTextBackgroundDuration = value
        addon:SetErrorTextBackground(addon.db.errorTextBackgroundEnabled, addon.db.errorTextBackgroundAlpha, addon.db.errorTextBackgroundDuration)
    end)

    UpdateErrorBackgroundControls()

    -- Battleground Map Scale tweak container
    local bgMapScale = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    bgMapScale:SetPoint("TOPLEFT", errorBG, "BOTTOMLEFT", 0, -10)
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

    -- Speed panel tweak container
    local speedPanel = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    speedPanel:SetPoint("TOPLEFT", bgMapScale, "BOTTOMLEFT", 0, -10)
    speedPanel:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    speedPanel:SetHeight(120)
    speedPanel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })

    local speedTitle = speedPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    speedTitle:SetPoint("TOPLEFT", speedPanel, "TOPLEFT", 10, -10)
    speedTitle:SetText("Speed Panel")

    local speedCheckbox = CreateFrame("CheckButton", nil, speedPanel, "InterfaceOptionsCheckButtonTemplate")
    speedCheckbox:SetPoint("TOPLEFT", speedTitle, "BOTTOMLEFT", 0, -8)
    speedCheckbox.Text:SetText("Enable Speed Panel")
    speedCheckbox:SetChecked(addon.db.speedPanelEnabled)

    local lockCheckbox = CreateFrame("CheckButton", nil, speedPanel, "InterfaceOptionsCheckButtonTemplate")
    lockCheckbox:SetPoint("TOPLEFT", speedCheckbox, "BOTTOMLEFT", 0, -8)
    lockCheckbox.Text:SetText("Lock Panel Position")
    lockCheckbox:SetChecked(addon.db.speedPanelLocked)

    local resetButton = CreateFrame("Button", nil, speedPanel, "UIPanelButtonTemplate")
    resetButton:SetSize(110, 22)
    resetButton:SetPoint("LEFT", lockCheckbox.Text, "RIGHT", 20, 0)
    resetButton:SetText("Reset Position")

    local speedInfo = speedPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    speedInfo:SetPoint("TOPLEFT", lockCheckbox, "BOTTOMLEFT", 0, -12)
    speedInfo:SetPoint("RIGHT", speedPanel, "RIGHT", -12, 0)
    speedInfo:SetJustifyH("LEFT")
    speedInfo:SetText("Displays your current movement speed. Unlock the panel to drag it to a new location.")

    local function UpdateSpeedPanelControls()
        local enabled = addon.db.speedPanelEnabled
        lockCheckbox:SetChecked(addon.db.speedPanelLocked)
        lockCheckbox:SetEnabled(enabled)
        resetButton:SetEnabled(enabled)
        if enabled then
            lockCheckbox.Text:SetTextColor(1, 1, 1)
        else
            lockCheckbox.Text:SetTextColor(0.5, 0.5, 0.5)
        end
    end

    speedCheckbox:SetScript("OnClick", function(self)
        addon.db.speedPanelEnabled = self:GetChecked()
        addon:SetSpeedPanelEnabled(addon.db.speedPanelEnabled)
        UpdateSpeedPanelControls()
    end)

    lockCheckbox:SetScript("OnClick", function(self)
        addon.db.speedPanelLocked = self:GetChecked()
        addon:RefreshSpeedPanelLock()
        UpdateSpeedPanelControls()
    end)

    resetButton:SetScript("OnClick", function()
        addon:ResetSpeedPanelPosition()
    end)

    UpdateSpeedPanelControls()
    
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
