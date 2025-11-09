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
    
    -- Scroll container for tweak sections
    local scrollFrame = CreateFrame("ScrollFrame", "GarageUITweaksOptionsScroll", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", enabledCheckbox, "BOTTOMLEFT", 0, -16)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 16)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(1)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)

    local function UpdateScrollChildWidth()
        local width = scrollFrame:GetWidth()
        if width and width > 0 then
            scrollChild:SetWidth(width - 12)
        end
    end
    scrollFrame:SetScript("OnSizeChanged", UpdateScrollChildWidth)
    UpdateScrollChildWidth()

    local lastSection
    local totalHeight = 0

    local function CreateSection(titleText, descriptionText, height)
        local section = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
        section:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })

        if lastSection then
            section:SetPoint("TOPLEFT", lastSection, "BOTTOMLEFT", 0, -16)
            totalHeight = totalHeight + 16
        else
            section:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, 0)
        end
        section:SetPoint("RIGHT", scrollChild, "RIGHT", -8, 0)
        section:SetHeight(height)

        local title = section:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        title:SetPoint("TOPLEFT", 10, -10)
        title:SetText(titleText)

        local desc = section:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        desc:SetPoint("TOPLEFT", title, "TOPRIGHT", 12, 0)
        desc:SetPoint("RIGHT", section, "RIGHT", -12, 0)
        desc:SetJustifyH("LEFT")
        desc:SetText(descriptionText)

        lastSection = section
        totalHeight = totalHeight + height

        return section, title, desc
    end

    local function ResizeSection(section, bottomWidget, minHeight)
        if not section or not bottomWidget then
            return
        end
        local oldHeight = section:GetHeight() or 0
        local top = section:GetTop()
        local bottom = bottomWidget:GetBottom()
        if not top or not bottom then
            return
        end
        local height = (top - bottom) + 24
        if minHeight then
            height = math.max(minHeight, height)
        end
        section:SetHeight(height)
        totalHeight = totalHeight - oldHeight + height
    end

    -- Error text background container
    local errorBG, errorTitle = CreateSection("Error Text Background", "Draws a backdrop behind UI errors briefly to improve visibility, then hides it automatically.", 170)

    local errorCheckbox = CreateFrame("CheckButton", nil, errorBG, "InterfaceOptionsCheckButtonTemplate")
    errorCheckbox:SetPoint("TOPLEFT", errorTitle, "BOTTOMLEFT", 0, -12)
    errorCheckbox.Text:SetText("Enable Background")
    errorCheckbox:SetChecked(addon.db.errorTextBackgroundEnabled)

    local alphaSlider = CreateFrame("Slider", nil, errorBG, "OptionsSliderTemplate")
    alphaSlider:SetPoint("TOPLEFT", errorCheckbox, "BOTTOMLEFT", 0, -28)
    alphaSlider:SetMinMaxValues(0, 1)
    alphaSlider:SetValue(addon.db.errorTextBackgroundAlpha or 0.7)
    alphaSlider:SetValueStep(0.05)
    alphaSlider:SetObeyStepOnDrag(true)
    alphaSlider:SetWidth(220)
    alphaSlider.Low:SetText("0%")
    alphaSlider.High:SetText("100%")
    alphaSlider.Text:SetText(string.format("Opacity: %.0f%%", (addon.db.errorTextBackgroundAlpha or 0.7) * 100))

    local durationSlider = CreateFrame("Slider", nil, errorBG, "OptionsSliderTemplate")
    durationSlider:SetPoint("TOPLEFT", alphaSlider, "BOTTOMLEFT", 0, -28)
    durationSlider:SetWidth(200)
    durationSlider:SetMinMaxValues(1, 5)
    durationSlider:SetValue(addon.db.errorTextBackgroundDuration or 3.0)
    durationSlider:SetValueStep(0.1)
    durationSlider:SetObeyStepOnDrag(true)
    durationSlider.Low:SetText("1s")
    durationSlider.High:SetText("5s")
    durationSlider.Text:SetText(string.format("Duration: %.1fs", addon.db.errorTextBackgroundDuration or 3.0))

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
    ResizeSection(errorBG, durationSlider, 170)

    -- Battleground Map Scale tweak container
    local bgMapScale, bgMapTitle = CreateSection("Battleground Map Scale", "Adjust the battlefield map size to your preference when entering battlegrounds.", 140)

    -- Scale slider for battleground map
    local scaleSlider = CreateFrame("Slider", nil, bgMapScale, "OptionsSliderTemplate")
    scaleSlider:SetPoint("TOPLEFT", bgMapTitle, "BOTTOMLEFT", 0, -28)
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
    ResizeSection(bgMapScale, scaleSlider, 120)

    -- Speed panel tweak container
    local speedPanel, speedTitle = CreateSection("Speed Panel", "Displays your current movement speed. Unlock to move it and tweak font, background, and border to fit your UI.", 320)

    local speedCheckbox = CreateFrame("CheckButton", nil, speedPanel, "InterfaceOptionsCheckButtonTemplate")
    speedCheckbox:SetPoint("TOPLEFT", speedTitle, "BOTTOMLEFT", 0, -12)
    speedCheckbox.Text:SetText("Enable Speed Panel")
    speedCheckbox:SetChecked(addon.db.speedPanelEnabled)

    local lockCheckbox = CreateFrame("CheckButton", nil, speedPanel, "InterfaceOptionsCheckButtonTemplate")
    lockCheckbox:SetPoint("TOPLEFT", speedCheckbox, "BOTTOMLEFT", 0, -12)
    lockCheckbox.Text:SetText("Lock Panel Position")
    lockCheckbox:SetChecked(addon.db.speedPanelLocked)

    local resetButton = CreateFrame("Button", nil, speedPanel, "UIPanelButtonTemplate")
    resetButton:SetSize(110, 22)
    resetButton:SetPoint("TOPLEFT", lockCheckbox, "BOTTOMLEFT", 0, -12)
    resetButton:SetText("Reset Position")

    local fontLabel = speedPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    fontLabel:SetPoint("TOPLEFT", resetButton, "BOTTOMLEFT", 0, -18)
    fontLabel:SetText("Font")

    local fontDropdown = CreateFrame("Frame", "GarageUITweaksSpeedFontDropdown", speedPanel, "UIDropDownMenuTemplate")
    fontDropdown:SetPoint("TOPLEFT", fontLabel, "BOTTOMLEFT", -16, -4)
    UIDropDownMenu_SetWidth(fontDropdown, 180)

    local backgroundLabel = speedPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    backgroundLabel:SetPoint("TOPLEFT", fontDropdown, "BOTTOMLEFT", 16, -18)
    backgroundLabel:SetText("Background")

    local backgroundDropdown = CreateFrame("Frame", "GarageUITweaksSpeedBackgroundDropdown", speedPanel, "UIDropDownMenuTemplate")
    backgroundDropdown:SetPoint("TOPLEFT", backgroundLabel, "BOTTOMLEFT", -16, -4)
    UIDropDownMenu_SetWidth(backgroundDropdown, 180)

    local borderLabel = speedPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    borderLabel:SetPoint("TOPLEFT", backgroundDropdown, "BOTTOMLEFT", 16, -18)
    borderLabel:SetText("Border")

    local borderDropdown = CreateFrame("Frame", "GarageUITweaksSpeedBorderDropdown", speedPanel, "UIDropDownMenuTemplate")
    borderDropdown:SetPoint("TOPLEFT", borderLabel, "BOTTOMLEFT", -16, -4)
    UIDropDownMenu_SetWidth(borderDropdown, 180)

    local speedInfo = speedPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    speedInfo:SetPoint("TOPLEFT", borderDropdown, "BOTTOMLEFT", 16, -18)
    speedInfo:SetPoint("RIGHT", speedPanel, "RIGHT", -12, 0)
    speedInfo:SetJustifyH("LEFT")
    speedInfo:SetText("Uses Blizzard speed data when available and a lightweight 0.25s fallback while flying, so you can monitor dragonriding speeds without jitter.")

    local function RefreshSpeedPanelDropdowns()
        local fontKey = addon.db.speedPanelFontKey or (addon:GetSpeedPanelFontOptions()[1] and addon:GetSpeedPanelFontOptions()[1].key)
        UIDropDownMenu_SetSelectedValue(fontDropdown, fontKey)
        UIDropDownMenu_SetText(fontDropdown, addon:GetSpeedPanelFontName(fontKey))

        local backgroundKey = addon.db.speedPanelBackgroundKey or (addon:GetSpeedPanelBackgroundOptions()[1] and addon:GetSpeedPanelBackgroundOptions()[1].key)
        UIDropDownMenu_SetSelectedValue(backgroundDropdown, backgroundKey)
        UIDropDownMenu_SetText(backgroundDropdown, addon:GetSpeedPanelBackgroundName(backgroundKey))

        local borderKey = addon.db.speedPanelBorderKey or (addon:GetSpeedPanelBorderOptions()[1] and addon:GetSpeedPanelBorderOptions()[1].key)
        UIDropDownMenu_SetSelectedValue(borderDropdown, borderKey)
        UIDropDownMenu_SetText(borderDropdown, addon:GetSpeedPanelBorderName(borderKey))
    end

    UIDropDownMenu_Initialize(fontDropdown, function(self, level)
        if not level then
            return
        end
        local selected = addon.db.speedPanelFontKey or (addon:GetSpeedPanelFontOptions()[1] and addon:GetSpeedPanelFontOptions()[1].key)
        for _, option in ipairs(addon:GetSpeedPanelFontOptions()) do
            local info = UIDropDownMenu_CreateInfo()
            local key = option.key
            info.text = option.name
            info.value = key
            info.checked = key == selected
            info.func = function()
                addon:SetSpeedPanelFont(key)
                RefreshSpeedPanelDropdowns()
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    UIDropDownMenu_Initialize(backgroundDropdown, function(self, level)
        if not level then
            return
        end
        local selected = addon.db.speedPanelBackgroundKey or (addon:GetSpeedPanelBackgroundOptions()[1] and addon:GetSpeedPanelBackgroundOptions()[1].key)
        for _, option in ipairs(addon:GetSpeedPanelBackgroundOptions()) do
            local info = UIDropDownMenu_CreateInfo()
            local key = option.key
            info.text = option.name
            info.value = key
            info.checked = key == selected
            info.func = function()
                addon:SetSpeedPanelBackground(key)
                RefreshSpeedPanelDropdowns()
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    UIDropDownMenu_Initialize(borderDropdown, function(self, level)
        if not level then
            return
        end
        local selected = addon.db.speedPanelBorderKey or (addon:GetSpeedPanelBorderOptions()[1] and addon:GetSpeedPanelBorderOptions()[1].key)
        for _, option in ipairs(addon:GetSpeedPanelBorderOptions()) do
            local info = UIDropDownMenu_CreateInfo()
            local key = option.key
            info.text = option.name
            info.value = key
            info.checked = key == selected
            info.func = function()
                addon:SetSpeedPanelBorder(key)
                RefreshSpeedPanelDropdowns()
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    local function UpdateSpeedPanelControls()
        local enabled = addon.db.speedPanelEnabled
        lockCheckbox:SetChecked(addon.db.speedPanelLocked)
        lockCheckbox:SetEnabled(enabled)
        resetButton:SetEnabled(enabled)
        if enabled then
            lockCheckbox.Text:SetTextColor(1, 1, 1)
            fontLabel:SetTextColor(1, 1, 1)
            backgroundLabel:SetTextColor(1, 1, 1)
            borderLabel:SetTextColor(1, 1, 1)
            if UIDropDownMenu_EnableDropDown then
                UIDropDownMenu_EnableDropDown(fontDropdown)
                UIDropDownMenu_EnableDropDown(backgroundDropdown)
                UIDropDownMenu_EnableDropDown(borderDropdown)
            end
        else
            lockCheckbox.Text:SetTextColor(0.5, 0.5, 0.5)
            fontLabel:SetTextColor(0.5, 0.5, 0.5)
            backgroundLabel:SetTextColor(0.5, 0.5, 0.5)
            borderLabel:SetTextColor(0.5, 0.5, 0.5)
            if UIDropDownMenu_DisableDropDown then
                UIDropDownMenu_DisableDropDown(fontDropdown)
                UIDropDownMenu_DisableDropDown(backgroundDropdown)
                UIDropDownMenu_DisableDropDown(borderDropdown)
            end
        end
        RefreshSpeedPanelDropdowns()
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
    ResizeSection(speedPanel, speedInfo, 260)

    scrollChild:SetHeight(math.max(totalHeight, 1))
    
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
