---@diagnostic disable: undefined-global
-- Garage UI Tweaks Settings
local addonName, addon = ...
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

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
    
    -- Enable checkbox (Global)
    local enabledCheckbox = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    enabledCheckbox:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -12)
    enabledCheckbox.Text:SetText("Enable Garage UI Tweaks")
    enabledCheckbox:SetChecked(addon.db.enabled)
    enabledCheckbox:SetScript("OnClick", function(self)
        addon.db.enabled = self:GetChecked()
        print("|cff00ff00Garage UI Tweaks:|r " .. (addon.db.enabled and "Enabled" or "Disabled"))
    end)

    -- Tabs Container
    local tabContainer = CreateFrame("Frame", nil, panel)
    tabContainer:SetPoint("TOPLEFT", enabledCheckbox, "BOTTOMLEFT", 0, -20)
    tabContainer:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -16, 16)
    
    -- Tab Content Frames
    local tabs = {}
    local currentTab = nil

    local function ShowTab(tabID)
        for id, tab in pairs(tabs) do
            if id == tabID then
                tab.frame:Show()
                if PanelTemplates_SelectTab then
                    PanelTemplates_SelectTab(tab.button)
                else
                    tab.button:LockHighlight()
                    tab.button:Disable() -- Traditional tab behavior
                    if tab.button.SetChecked then tab.button:SetChecked(true) end
                end
            else
                tab.frame:Hide()
                if PanelTemplates_DeselectTab then
                    PanelTemplates_DeselectTab(tab.button)
                else
                    tab.button:UnlockHighlight()
                    tab.button:Enable()
                    if tab.button.SetChecked then tab.button:SetChecked(false) end
                end
            end
        end
        currentTab = tabID
    end

    local function CreateTabButton(id, text, index)
        -- Using PanelTopTabButtonTemplate for the 'Tab' look
        local btnName = "GarageUITweaksTab" .. index
        local btn = CreateFrame("Button", btnName, panel, "PanelTopTabButtonTemplate")
        btn:SetID(index)
        btn:SetText(text)
        
        -- Position tabs relative to tabContainer or previously created tab
        -- Standard tab placement is usually tied to the panel top or bottom of previous element
        if index == 1 then
             btn:SetPoint("BOTTOMLEFT", tabContainer, "TOPLEFT", 6, -2)
        else
             local prevTab = tabs[tabs[index-1]] -- Need ordered access, but tabs is hash map? No, I control insertion
             -- Actually, simple positioning based on index works if we assume order
             -- But since tabs is keyed by ID string, let's just use strict positioning
             btn:SetPoint("LEFT", _G["GarageUITweaksTab" .. (index - 1)], "RIGHT", 2, 0)
        end

        -- Resize to fit text
        if PanelTemplates_TabResize then
            PanelTemplates_TabResize(btn, 0)
        else
            local textWidth = btn:GetFontString():GetStringWidth()
            btn:SetWidth(textWidth + 20)
        end
        
        local content = CreateFrame("Frame", nil, tabContainer)
        content:SetAllPoints()
        content:Hide()

        -- Add scroll frame support for content
        local scrollFrame = CreateFrame("ScrollFrame", nil, content, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 0, 0)
        scrollFrame:SetPoint("BOTTOMRIGHT", -26, 0)
        
        local scrollChild = CreateFrame("Frame", nil, scrollFrame)
        scrollChild:SetWidth(tabContainer:GetWidth() - 26)
        scrollChild:SetHeight(1) -- Will grow
        scrollFrame:SetScrollChild(scrollChild)

        scrollFrame:SetScript("OnSizeChanged", function(self)
            scrollChild:SetWidth(self:GetWidth())
        end)

        btn:SetScript("OnClick", function() ShowTab(id) end)

        tabs[id] = { button = btn, frame = content, scrollChild = scrollChild, totalHeight = 0, lastSection = nil }
        return tabs[id]
    end

    -- Tab Definitions
    local tabGeneral = CreateTabButton("general", "General", 1)
    local tabChat = CreateTabButton("chat", "Chat Box", 2)
    local tabSpeed = CreateTabButton("speed", "Speed Panel", 3)
    local tabPRD = CreateTabButton("prd", "PRD", 4)

    -- Helper to add sections to a tab
    local function CreateSection(tab, titleText, descriptionText, height)
        local parent = tab.scrollChild
        local section = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        section:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })

        if tab.lastSection then
            section:SetPoint("TOPLEFT", tab.lastSection, "BOTTOMLEFT", 0, -16)
            tab.totalHeight = tab.totalHeight + 16
        else
            section:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -4)
            tab.totalHeight = tab.totalHeight + 4
        end
        section:SetPoint("RIGHT", parent, "RIGHT", -4, 0)
        section:SetHeight(height)

        local title = section:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        title:SetPoint("TOPLEFT", 10, -10)
        title:SetText(titleText)

        local desc = section:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        desc:SetPoint("TOPLEFT", title, "TOPRIGHT", 12, 0)
        desc:SetPoint("RIGHT", section, "RIGHT", -12, 0)
        desc:SetJustifyH("LEFT")
        desc:SetText(descriptionText)

        tab.lastSection = section
        tab.totalHeight = tab.totalHeight + height
        parent:SetHeight(math.max(tab.totalHeight, 100))

        return section, title, desc
    end

    -- ====================
    -- GENERAL TAB CONTENT
    -- ====================
    
    -- Error Text Background
    local errorBG, errorTitle = CreateSection(tabGeneral, "Error Text Background", "Draws a backdrop behind UI errors briefly to improve visibility.", 170)
    
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

    errorCheckbox:SetScript("OnClick", function(self)
        addon.db.errorTextBackgroundEnabled = self:GetChecked()
        addon:SetErrorTextBackground(addon.db.errorTextBackgroundEnabled, addon.db.errorTextBackgroundAlpha, addon.db.errorTextBackgroundDuration)
        alphaSlider:SetEnabled(addon.db.errorTextBackgroundEnabled)
        durationSlider:SetEnabled(addon.db.errorTextBackgroundEnabled)
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


    -- Map Scale
    local bgMapScale, bgMapTitle = CreateSection(tabGeneral, "Battleground Map Scale", "Adjust the battlefield map size (Shift+M).", 100)
    
    local scaleSlider = CreateFrame("Slider", nil, bgMapScale, "OptionsSliderTemplate")
    scaleSlider:SetPoint("TOPLEFT", bgMapTitle, "BOTTOMLEFT", 0, -28)
    scaleSlider:SetMinMaxValues(0.5, 2.0)
    scaleSlider:SetValue(addon.db.battlegroundMapScale or 1.0)
    scaleSlider:SetValueStep(0.1)
    scaleSlider:SetObeyStepOnDrag(true)
    scaleSlider:SetWidth(200)
    scaleSlider.Text:SetText(string.format("Scale: %.0f%%", (addon.db.battlegroundMapScale or 1.0) * 100))
    scaleSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value * 10 + 0.5) / 10
        self.Text:SetText(string.format("Scale: %.0f%%", value * 100))
        addon.db.battlegroundMapScale = value
        addon:ApplyTweaks()
    end)


    -- ====================
    -- CHAT TAB
    -- ====================
    local chatPanel, chatTitle = CreateSection(tabChat, "Chat Entry Box", "Customize the position and appearance of the chat input box.", 300)

    -- Unlock / Drag
    local chatUnlock = CreateFrame("CheckButton", nil, chatPanel, "InterfaceOptionsCheckButtonTemplate")
    chatUnlock:SetPoint("TOPLEFT", chatTitle, "BOTTOMLEFT", 0, -12)
    chatUnlock.Text:SetText("Unlock Chat Entry Box (Hold SHIFT to Drag)")
    chatUnlock:SetChecked(addon.db.chatEditBoxUnlock)
    chatUnlock:SetScript("OnClick", function(self)
        addon.db.chatEditBoxUnlock = self:GetChecked()
        addon:SetChatEditBoxUnlock(addon.db.chatEditBoxUnlock)
    end)

    -- Disable Borders
    local borderCheckbox = CreateFrame("CheckButton", nil, chatPanel, "InterfaceOptionsCheckButtonTemplate")
    borderCheckbox:SetPoint("TOPLEFT", chatUnlock, "BOTTOMLEFT", 0, -12)
    borderCheckbox.Text:SetText("Hide Default Borders")
    borderCheckbox:SetChecked(addon.db.chatEditBoxHideBorder)
    borderCheckbox:SetScript("OnClick", function(self)
        addon.db.chatEditBoxHideBorder = self:GetChecked()
        addon:UpdateChatEditBox()
    end)
    
    -- Width Slider
    local widthSlider = CreateFrame("Slider", nil, chatPanel, "OptionsSliderTemplate")
    widthSlider:SetPoint("TOPLEFT", borderCheckbox, "BOTTOMLEFT", 6, -30)
    widthSlider:SetMinMaxValues(200, 1000)
    widthSlider:SetValue(addon.db.chatEditBoxWidth or 450)
    widthSlider:SetValueStep(10)
    widthSlider:SetObeyStepOnDrag(true)
    widthSlider:SetWidth(400)
    widthSlider.Low:SetText("200")
    widthSlider.High:SetText("1000")
    widthSlider.Text:SetText(string.format("Width: %d", addon.db.chatEditBoxWidth or 450))
    widthSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        self.Text:SetText(string.format("Width: %d", value))
        addon.db.chatEditBoxWidth = value
        addon:UpdateChatEditBox()
    end)
    
    -- Anchor Dropdown
    local anchorLabel = chatPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    anchorLabel:SetPoint("TOPLEFT", widthSlider, "BOTTOMLEFT", 0, -20)
    anchorLabel:SetText("Resize Anchor (Determines growth direction):")

    local anchorDropdown = CreateFrame("Frame", "GarageUIChatAnchorDropdown", chatPanel, "UIDropDownMenuTemplate")
    anchorDropdown:SetPoint("TOPLEFT", anchorLabel, "BOTTOMLEFT", -16, -5)
    
    local function UpdateAnchor(val)
        addon.db.chatEditBoxAnchor = val
        UIDropDownMenu_SetText(anchorDropdown, val)
        addon:UpdateChatEditBox()
    end

    UIDropDownMenu_Initialize(anchorDropdown, function(self, level, menuList)
        local selected = addon.db.chatEditBoxAnchor or "CENTER"
        local anchors = {"LEFT", "CENTER", "RIGHT"}
        for _, anchor in ipairs(anchors) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = anchor
            info.value = anchor
            info.func = function(b) 
                UpdateAnchor(b.value) 
                UIDropDownMenu_SetSelectedValue(anchorDropdown, b.value)
            end
            info.checked = (selected == anchor)
            UIDropDownMenu_AddButton(info)
        end
    end)
    
    UIDropDownMenu_SetText(anchorDropdown, addon.db.chatEditBoxAnchor or "CENTER")
    UIDropDownMenu_SetWidth(anchorDropdown, 120)


    -- ====================
    -- SPEED PANEL TAB
    -- ====================
    local speedPanel, speedTitle = CreateSection(tabSpeed, "Speed Panel", "Displays your current movement speed.", 280)
    
    local speedCheckbox = CreateFrame("CheckButton", nil, speedPanel, "InterfaceOptionsCheckButtonTemplate")
    speedCheckbox:SetPoint("TOPLEFT", speedTitle, "BOTTOMLEFT", 0, -12)
    speedCheckbox.Text:SetText("Enable Speed Panel")
    speedCheckbox:SetChecked(addon.db.speedPanelEnabled)

    local lockCheckbox = CreateFrame("CheckButton", nil, speedPanel, "InterfaceOptionsCheckButtonTemplate")
    lockCheckbox:SetPoint("TOPLEFT", speedCheckbox, "BOTTOMLEFT", 0, -12)
    lockCheckbox.Text:SetText("Lock Panel Position")
    lockCheckbox:SetChecked(addon.db.speedPanelLocked)

    local debugCheckbox = CreateFrame("CheckButton", nil, speedPanel, "InterfaceOptionsCheckButtonTemplate")
    debugCheckbox:SetPoint("LEFT", speedCheckbox, "RIGHT", 150, 0)
    debugCheckbox.Text:SetText("Debug Mode")
    debugCheckbox:SetChecked(addon.db.speedPanelDebug or false)

    local resetButton = CreateFrame("Button", nil, speedPanel, "UIPanelButtonTemplate")
    resetButton:SetPoint("TOPLEFT", lockCheckbox, "BOTTOMLEFT", 0, -16)
    resetButton:SetSize(120, 22)
    resetButton:SetText("Reset Position")
    
    local speedInfo = speedPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    speedInfo:SetPoint("TOPLEFT", resetButton, "BOTTOMLEFT", 0, -16)
    speedInfo:SetWidth(300)
    speedInfo:SetJustifyH("LEFT")
    speedInfo:SetText("Use /speedpanel to toggle options from chat.\nDrag the panel to move it when unlocked.")

    -- Speed Panel Logic
    local function UpdateSpeedControls()
        local enabled = addon.db.speedPanelEnabled
        lockCheckbox:Enable()
        resetButton:SetEnabled(enabled)
        if enabled then
             lockCheckbox.Text:SetTextColor(1, 1, 1)
        else
             lockCheckbox:SetChecked(true) -- Always lock when disabled visually
             lockCheckbox:Disable()
             lockCheckbox.Text:SetTextColor(0.5, 0.5, 0.5)
        end
    end
    
    speedCheckbox:SetScript("OnClick", function(self)
        addon.db.speedPanelEnabled = self:GetChecked()
        addon:SetSpeedPanelEnabled(addon.db.speedPanelEnabled)
        UpdateSpeedControls()
    end)
    
    lockCheckbox:SetScript("OnClick", function(self)
        addon.db.speedPanelLocked = self:GetChecked()
        if addon.SpeedPanel then addon.SpeedPanel:EnableMouse(not addon.db.speedPanelLocked) end
    end)

    debugCheckbox:SetScript("OnClick", function(self)
        addon.db.speedPanelDebug = self:GetChecked()
        if addon.SpeedPanel then addon.SpeedPanel:SetDebug(addon.db.speedPanelDebug) end
    end)

    resetButton:SetScript("OnClick", function() addon:ResetSpeedPanelPosition() end)
    UpdateSpeedControls()

    -- ====================
    -- PRD TAB
    -- ====================
    local prdPanel, prdTitle = CreateSection(tabPRD, "Personal Resource Display", "Manage appearance of the Personal Resource Display (PRD).", 200)

    -- Visibility Options
    local enemyTargetCheck = CreateFrame("CheckButton", nil, prdPanel, "InterfaceOptionsCheckButtonTemplate")
    enemyTargetCheck:SetPoint("TOPLEFT", prdTitle, "BOTTOMLEFT", 0, -12)
    enemyTargetCheck.Text:SetText("Show when Enemy Target Selected")
    enemyTargetCheck:SetChecked(addon.db.prdShowWithTargetEnemy)
    enemyTargetCheck:SetScript("OnClick", function(self)
        addon.db.prdShowWithTargetEnemy = self:GetChecked()
        addon:SetPRDVisibilityOptions()
    end)

    local friendlyTargetCheck = CreateFrame("CheckButton", nil, prdPanel, "InterfaceOptionsCheckButtonTemplate")
    friendlyTargetCheck:SetPoint("TOPLEFT", enemyTargetCheck, "BOTTOMLEFT", 0, -8)
    friendlyTargetCheck.Text:SetText("Show when Friendly Target Selected")
    friendlyTargetCheck:SetChecked(addon.db.prdShowWithTargetFriendly)
    friendlyTargetCheck:SetScript("OnClick", function(self)
        addon.db.prdShowWithTargetFriendly = self:GetChecked()
        addon:SetPRDVisibilityOptions()
    end)

    -- Texture Selection
    local textureLabel = prdPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    textureLabel:SetPoint("TOPLEFT", friendlyTargetCheck, "BOTTOMLEFT", 6, -20)
    textureLabel:SetText("Status Bar Texture:")

    -- Texture Dropdown (using LibSharedMedia or fallback)
    local textureDropdown = CreateFrame("Frame", "GarageUITweaksPRDTextureDropdown", prdPanel, "UIDropDownMenuTemplate")
    textureDropdown:SetPoint("TOPLEFT", textureLabel, "BOTTOMLEFT", -16, -2)
    
    local function UpdateTexture(val)
        addon.db.prdTexture = val
        addon:SetPRDTexture(val)
        UIDropDownMenu_SetText(textureDropdown, val:match("([^\\]+)$") or val) -- Try to show filename
    end

    UIDropDownMenu_Initialize(textureDropdown, function(self, level, menuList)
        local selected = addon.db.prdTexture or "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill"
        
        -- Default/Blizzard Option
        local info = UIDropDownMenu_CreateInfo()
        info.text = "Blizzard Default"
        info.value = "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill"
        info.func = function(b) 
            UpdateTexture(b.value) 
            UIDropDownMenu_SetSelectedValue(textureDropdown, b.value)
        end
        info.checked = (selected == info.value)
        UIDropDownMenu_AddButton(info)

        -- LibSharedMedia Options
        if LSM then
             local textures = LSM:HashTable("statusbar")
             local keys = {}
             for k in pairs(textures) do table.insert(keys, k) end
             table.sort(keys)

             for _, k in ipairs(keys) do
                 local path = textures[k]
                 info = UIDropDownMenu_CreateInfo()
                 info.text = k
                 info.value = path
                 info.func = function(b) 
                    UpdateTexture(b.value) 
                    UIDropDownMenu_SetSelectedValue(textureDropdown, b.value)
                end
                 info.checked = (selected == path)
                 UIDropDownMenu_AddButton(info)
             end
        end
    end)
    
    -- Set Initial Text
    local currentTex = addon.db.prdTexture or "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill"
    -- Try to find friendly name
    local friendlyName = "Custom/Unknown"
    if currentTex == "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill" then friendlyName = "Blizzard Default" end
    if LSM then
        for name, path in pairs(LSM:HashTable("statusbar")) do
            if path == currentTex then friendlyName = name break end
        end
    end
    UIDropDownMenu_SetText(textureDropdown, friendlyName)
    UIDropDownMenu_SetWidth(textureDropdown, 180)


    -- Initialization
    ShowTab("general")

    -- Add to Interface Options
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        addon.settingsCategory = category
    else
        InterfaceOptions_AddCategory(panel)
    end
    addon.settingsPanel = panel
end

-- Open settings panel (Helper)
function addon:OpenSettings()
    if not self.settingsPanel then self:CreateSettingsPanel() end
    if Settings and Settings.OpenToCategory then
        local id = self.settingsCategory and self.settingsCategory:GetID()
        if not id then id = Settings.GetCategory("Garage UI Tweaks"):GetID() end
        Settings.OpenToCategory(id)
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(self.settingsPanel)
        InterfaceOptionsFrame_OpenToCategory(self.settingsPanel)
    end
end

-- Initialize on Login
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
         addon:CreateSettingsPanel()
    end
end)
