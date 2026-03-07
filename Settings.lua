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
    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
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
                
                -- Trigger refresh if needed
                if id == "background" and addon.RefreshSettings then
                    addon:RefreshSettings("background")
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
    local tabGeneral = CreateTabButton("general", "General Tweaks", 1)
    local tabChat = CreateTabButton("chat", "Chat Tweaks", 2)
    local tabSpeed = CreateTabButton("speed", "Speed Tweaks", 3)
    local tabPRD = CreateTabButton("prd", "PRD Tweaks", 4)
    local tabNameplates = CreateTabButton("nameplates", "Nameplate Tweaks", 5)
    local tabBackground = CreateTabButton("background", "Background", 6)

    -- Helper to add sections to a tab
    local function CreateSection(tab, titleText, descriptionText, height)
        local parent = tab.scrollChild
        local section = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        section:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        section:SetBackdropColor(0.1, 0.1, 0.1, 0.4)
        section:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)

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
        title:SetPoint("TOPLEFT", 10, -12) -- Adjusted padding to match Knack's padding roughly
        title:SetText(titleText)

        local desc = section:CreateFontString(nil, "ARTWORK", "GameFontHighlight") -- Changed from Small
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


    -- Override Action Bar
    local overrideBarGroup, overrideBarTitle = CreateSection(tabGeneral, "Override Action Bar", "Adjust the position of the Vehicle/Override Action Bar.", 100)

    local overrideYSlider = CreateFrame("Slider", nil, overrideBarGroup, "OptionsSliderTemplate")
    overrideYSlider:SetPoint("TOPLEFT", overrideBarTitle, "BOTTOMLEFT", 0, -28)
    overrideYSlider:SetMinMaxValues(0, 300)
    overrideYSlider:SetValue(addon.db.overrideActionBarYOffset or 0)
    overrideYSlider:SetValueStep(1)
    overrideYSlider:SetObeyStepOnDrag(true)
    overrideYSlider:SetWidth(400)
    overrideYSlider.Low:SetText("0")
    overrideYSlider.High:SetText("300")
    overrideYSlider.Text:SetText(string.format("Y Offset: %d", addon.db.overrideActionBarYOffset or 0))
    overrideYSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        self.Text:SetText(string.format("Y Offset: %d", value))
        addon.db.overrideActionBarYOffset = value
        addon:UpdateOverrideActionBar()
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

    -- Chat Frame Button Background
    local chatButtonBG, chatButtonTitle = CreateSection(tabChat, "Chat Frame Buttons", "Hide the minimize button, background and borders on chat frames.", 140)
    
    local hideChatButtonBG = CreateFrame("CheckButton", nil, chatButtonBG, "InterfaceOptionsCheckButtonTemplate")
    hideChatButtonBG:SetPoint("TOPLEFT", chatButtonTitle, "BOTTOMLEFT", 0, -12)
    hideChatButtonBG.Text:SetText("Hide Button Background, Border & Minimize")
    hideChatButtonBG:SetChecked(addon.db.hideChatButtonFrameBackground)
    hideChatButtonBG:SetScript("OnClick", function(self)
        addon.db.hideChatButtonFrameBackground = self:GetChecked()
        addon:ApplyTweaks()
    end)

    local hideMenuButton = CreateFrame("CheckButton", nil, chatButtonBG, "InterfaceOptionsCheckButtonTemplate")
    hideMenuButton:SetPoint("TOPLEFT", hideChatButtonBG, "BOTTOMLEFT", 0, -4)
    hideMenuButton.Text:SetText("Hide Chat Menu Button")
    hideMenuButton:SetChecked(addon.db.hideChatFrameMenuButton)
    hideMenuButton:SetScript("OnClick", function(self)
        addon.db.hideChatFrameMenuButton = self:GetChecked()
        addon:ApplyTweaks()
    end)

    local hideChannelButton = CreateFrame("CheckButton", nil, chatButtonBG, "InterfaceOptionsCheckButtonTemplate")
    hideChannelButton:SetPoint("TOPLEFT", hideMenuButton, "BOTTOMLEFT", 0, -4)
    hideChannelButton.Text:SetText("Hide Chat Channel Button")
    hideChannelButton:SetChecked(addon.db.hideChatFrameChannelButton)
    hideChannelButton:SetScript("OnClick", function(self)
        addon.db.hideChatFrameChannelButton = self:GetChecked()
        addon:ApplyTweaks()
    end)

    local hideQuickJoinButton = CreateFrame("CheckButton", nil, chatButtonBG, "InterfaceOptionsCheckButtonTemplate")
    hideQuickJoinButton:SetPoint("TOPLEFT", hideChannelButton, "BOTTOMLEFT", 0, -4)
    hideQuickJoinButton.Text:SetText("Hide Social Button (Quick Join)")
    hideQuickJoinButton:SetChecked(addon.db.hideQuickJoinToastButton)
    hideQuickJoinButton:SetScript("OnClick", function(self)
        addon.db.hideQuickJoinToastButton = self:GetChecked()
        addon:ApplyTweaks()
    end)


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

    -- Texture Selection Helper
    local function CreateTextureDropdown(label, dbKey, updateFunc, anchorParent, relativeTo, x, y)
        local lbl = anchorParent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        lbl:SetPoint("TOPLEFT", relativeTo, "BOTTOMLEFT", x, y)
        lbl:SetText(label)

        local dropdown = CreateFrame("Frame", "GUIT_" .. dbKey, anchorParent, "UIDropDownMenuTemplate")
        dropdown:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", -16, -2)

        local function InitMenu(self, level, menuList)
            local selected = addon.db[dbKey] or "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill"
            local info = UIDropDownMenu_CreateInfo()
            
            -- Default
            info.text = "Blizzard Default"
            info.value = "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill"
            info.func = function(b) updateFunc(b.value) UIDropDownMenu_SetSelectedValue(dropdown, b.value) end
            info.checked = (selected == info.value)
            UIDropDownMenu_AddButton(info)

            -- LSM
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
                     info.func = function(b) updateFunc(b.value) UIDropDownMenu_SetSelectedValue(dropdown, b.value) end
                     info.checked = (selected == path)
                     UIDropDownMenu_AddButton(info)
                 end
            end
        end

        UIDropDownMenu_Initialize(dropdown, InitMenu)
        
        -- Set Initial Text
        local currentTex = addon.db[dbKey] or "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill"
        local friendlyName = "Custom/Unknown"
        if currentTex == "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill" then friendlyName = "Blizzard Default" end
        if LSM then
            for name, path in pairs(LSM:HashTable("statusbar")) do
                if path == currentTex then friendlyName = name break end
            end
        end
        UIDropDownMenu_SetText(dropdown, friendlyName)
        UIDropDownMenu_SetWidth(dropdown, 180)
        
        return dropdown, lbl
    end

    -- Color Picker Helper
    local function CreateColorPicker(parent, dbKey, updateFunc, relativeTo, x, y)
        local swatch = CreateFrame("Button", nil, parent, "BackdropTemplate")
        swatch:SetSize(20, 20)
        swatch:SetPoint("LEFT", relativeTo, "RIGHT", x, y)
        swatch:SetBackdrop({
            edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1,
            bgFile = "Interface\\Buttons\\WHITE8x8", tiling = false
        })
        swatch:SetBackdropBorderColor(0.6, 0.6, 0.6)
        
        local function UpdateSwatch()
            local c = addon.db[dbKey] or {r=0, g=0, b=0, a=0.5}
            swatch:SetBackdropColor(c.r, c.g, c.b, c.a or 1)
        end
        UpdateSwatch()

        swatch:SetScript("OnClick", function()
            local c = addon.db[dbKey] or {r=0, g=0, b=0, a=0.5}
            
            local function GetAlphaSafe()
                if ColorPickerFrame.GetColorAlpha then
                    return ColorPickerFrame:GetColorAlpha()
                elseif OpacitySliderFrame then
                    return 1 - OpacitySliderFrame:GetValue()
                end
                return 1
            end

            local info = {
                r = c.r, g = c.g, b = c.b, opacity = (1 - (c.a or 1)),
                hasOpacity = true,
                swatchFunc = function()
                    local r, g, b = ColorPickerFrame:GetColorRGB()
                    local a = GetAlphaSafe()
                    addon.db[dbKey] = {r=r, g=g, b=b, a=a}
                    swatch:SetBackdropColor(r, g, b, a)
                    if updateFunc then updateFunc() end
                end,
                opacityFunc = function()
                    local r, g, b = ColorPickerFrame:GetColorRGB()
                    local a = GetAlphaSafe()
                    addon.db[dbKey] = {r=r, g=g, b=b, a=a}
                    swatch:SetBackdropColor(r, g, b, a)
                    if updateFunc then updateFunc() end
                end,
                cancelFunc = function()
                    addon.db[dbKey] = c
                    UpdateSwatch()
                    if updateFunc then updateFunc() end
                end,
            }
            -- Fix for modern ColorPickerFrame opacity handling if accessible
            if ColorPickerFrame.Content and ColorPickerFrame.Content.ColorPicker then
                 -- Setup might be different, but usually SetupColorPickerAndShow handles mapping
                 -- Just ensuring we don't crash is step 1.
            end
            ColorPickerFrame:SetupColorPickerAndShow(info)
        end)
        return swatch
    end

    -- Group Box Helper
    local function CreateGroupBox(titleText, parent, relativeTo, height)
        local group = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        group:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        })
        group:SetBackdropColor(0.15, 0.15, 0.15, 0.5)
        group:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.6)
        
        if relativeTo then
            group:SetPoint("TOPLEFT", relativeTo, "BOTTOMLEFT", 0, -10)
        else
            group:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -10)
        end
        group:SetPoint("RIGHT", parent, "RIGHT", -10, 0)
        group:SetHeight(height)

        local title = group:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        title:SetPoint("TOPLEFT", 8, -8)
        title:SetText(titleText)
        
        return group
    end

    -- Create Dropdowns & Groups
    
    -- 1. Health Bar Group
    local grpHealth = CreateGroupBox("Health Bar", prdPanel, friendlyTargetCheck, 110)
    
    local chkMatchHealth = CreateFrame("CheckButton", nil, grpHealth, "InterfaceOptionsCheckButtonTemplate")
    chkMatchHealth:SetPoint("TOPLEFT", grpHealth, "TOPLEFT", 10, -25)
    chkMatchHealth.Text:SetText("Match Player Frame Texture")
    chkMatchHealth:SetChecked(addon.db.prdMatchHealth)
    
    local dropHealth, lblHealth = CreateTextureDropdown("Bar Texture", "prdTextureHealth", function(v) addon.db.prdTextureHealth = v; addon:UpdatePRDTextures() end, grpHealth, nil, 10, -30)
    dropHealth:ClearAllPoints()
    dropHealth:SetPoint("TOPLEFT", grpHealth, "TOPLEFT", 10, -65)
    lblHealth:SetPoint("TOPLEFT", dropHealth, "TOPLEFT", 0, 16)
    
    local dropHealthBG, lblHealthBG = CreateTextureDropdown("Background Texture", "prdBackgroundHealth", function(v) addon.db.prdBackgroundHealth = v; addon:UpdatePRDTextures() end, grpHealth, nil, 230, 0)
    dropHealthBG:ClearAllPoints()
    dropHealthBG:SetPoint("TOPLEFT", grpHealth, "TOPLEFT", 230, -65)
    lblHealthBG:SetPoint("TOPLEFT", dropHealthBG, "TOPLEFT", 0, 16)
    
    local cpHealth = CreateColorPicker(grpHealth, "prdBackgroundHealthColor", function() addon:UpdatePRDTextures() end, dropHealthBG, 170, 0)
    -- Need to manually position cpHealth better to ensure visibility
    cpHealth:ClearAllPoints()
    cpHealth:SetPoint("LEFT", dropHealthBG, "RIGHT", -10, 2) -- To the right of the dropdown

    -- Logic to Grey Out
    local function UpdateHealthState() 
       local match = addon.db.prdMatchHealth
       if match then
           UIDropDownMenu_DisableDropDown(dropHealth)
           lblHealth:SetTextColor(0.5, 0.5, 0.5)
           UIDropDownMenu_DisableDropDown(dropHealthBG)
           lblHealthBG:SetTextColor(0.5, 0.5, 0.5)
           cpHealth:Disable()
           cpHealth:SetAlpha(0.5)
       else
           UIDropDownMenu_EnableDropDown(dropHealth)
           lblHealth:SetTextColor(1, 1, 1)
           UIDropDownMenu_EnableDropDown(dropHealthBG)
           lblHealthBG:SetTextColor(1, 1, 1)
           cpHealth:Enable()
           cpHealth:SetAlpha(1)
       end
    end
    UpdateHealthState()

    chkMatchHealth:SetScript("OnClick", function(self)
        addon.db.prdMatchHealth = self:GetChecked()
        UpdateHealthState()
        addon:UpdatePRDTextures()
    end)
    
    -- 2. Power Bar Group
    local grpPower = CreateGroupBox("Power Bar", prdPanel, grpHealth, 110)
    
    local chkMatchPower = CreateFrame("CheckButton", nil, grpPower, "InterfaceOptionsCheckButtonTemplate")
    chkMatchPower:SetPoint("TOPLEFT", grpPower, "TOPLEFT", 10, -25)
    chkMatchPower.Text:SetText("Match Player Frame Texture")
    chkMatchPower:SetChecked(addon.db.prdMatchPower)

    local dropPower, lblPower = CreateTextureDropdown("Bar Texture", "prdTexturePower", function(v) addon.db.prdTexturePower = v; addon:UpdatePRDTextures() end, grpPower, nil, 10, -35)
    dropPower:ClearAllPoints(); dropPower:SetPoint("TOPLEFT", grpPower, "TOPLEFT", 10, -65)
    lblPower:SetPoint("TOPLEFT", dropPower, "TOPLEFT", 0, 16)
    
    local dropPowerBG, lblPowerBG = CreateTextureDropdown("Background Texture", "prdBackgroundPower", function(v) addon.db.prdBackgroundPower = v; addon:UpdatePRDTextures() end, grpPower, nil, 230, -35)
    dropPowerBG:ClearAllPoints(); dropPowerBG:SetPoint("TOPLEFT", grpPower, "TOPLEFT", 230, -65)
    lblPowerBG:SetPoint("TOPLEFT", dropPowerBG, "TOPLEFT", 0, 16)

    local cpPower = CreateColorPicker(grpPower, "prdBackgroundPowerColor", function() addon:UpdatePRDTextures() end, dropPowerBG, 170, 0)
    cpPower:ClearAllPoints()
    cpPower:SetPoint("LEFT", dropPowerBG, "RIGHT", -10, 2)
    
    local function UpdatePowerState() 
       local match = addon.db.prdMatchPower
       if match then
           UIDropDownMenu_DisableDropDown(dropPower)
           lblPower:SetTextColor(0.5, 0.5, 0.5)
           UIDropDownMenu_DisableDropDown(dropPowerBG)
           lblPowerBG:SetTextColor(0.5, 0.5, 0.5)
           cpPower:Disable()
           cpPower:SetAlpha(0.5)
       else
           UIDropDownMenu_EnableDropDown(dropPower)
           lblPower:SetTextColor(1, 1, 1)
           UIDropDownMenu_EnableDropDown(dropPowerBG)
           lblPowerBG:SetTextColor(1, 1, 1)
           cpPower:Enable()
           cpPower:SetAlpha(1)
       end
    end
    UpdatePowerState()

    chkMatchPower:SetScript("OnClick", function(self)
        addon.db.prdMatchPower = self:GetChecked()
        UpdatePowerState()
        addon:UpdatePRDTextures()
    end)


    -- 3. Alt Bar Group
    local grpAlt = CreateGroupBox("Class/Alternate Bar", prdPanel, grpPower, 110)

    local chkMatchAlt = CreateFrame("CheckButton", nil, grpAlt, "InterfaceOptionsCheckButtonTemplate")
    chkMatchAlt:SetPoint("TOPLEFT", grpAlt, "TOPLEFT", 10, -25)
    chkMatchAlt.Text:SetText("Match Player Frame Texture")
    chkMatchAlt:SetChecked(addon.db.prdMatchAlternate)

    local dropAlt, lblAlt = CreateTextureDropdown("Bar Texture", "prdTextureAlternate", function(v) addon.db.prdTextureAlternate = v; addon:UpdatePRDTextures() end, grpAlt, nil, 10, -35)
    dropAlt:ClearAllPoints(); dropAlt:SetPoint("TOPLEFT", grpAlt, "TOPLEFT", 10, -65)
    lblAlt:SetPoint("TOPLEFT", dropAlt, "TOPLEFT", 0, 16)
    
    local dropAltBG, lblAltBG = CreateTextureDropdown("Background Texture", "prdBackgroundAlternate", function(v) addon.db.prdBackgroundAlternate = v; addon:UpdatePRDTextures() end, grpAlt, nil, 230, -35)
    dropAltBG:ClearAllPoints(); dropAltBG:SetPoint("TOPLEFT", grpAlt, "TOPLEFT", 230, -65)
    lblAltBG:SetPoint("TOPLEFT", dropAltBG, "TOPLEFT", 0, 16)

    local cpAlt = CreateColorPicker(grpAlt, "prdBackgroundAlternateColor", function() addon:UpdatePRDTextures() end, dropAltBG, 170, 0)
    cpAlt:ClearAllPoints()
    cpAlt:SetPoint("LEFT", dropAltBG, "RIGHT", -10, 2)
    
    local function UpdateAltState() 
       local match = addon.db.prdMatchAlternate
       if match then
           UIDropDownMenu_DisableDropDown(dropAlt)
           lblAlt:SetTextColor(0.5, 0.5, 0.5)
           UIDropDownMenu_DisableDropDown(dropAltBG)
           lblAltBG:SetTextColor(0.5, 0.5, 0.5)
           cpAlt:Disable()
           cpAlt:SetAlpha(0.5)
       else
           UIDropDownMenu_EnableDropDown(dropAlt)
           lblAlt:SetTextColor(1, 1, 1)
           UIDropDownMenu_EnableDropDown(dropAltBG)
           lblAltBG:SetTextColor(1, 1, 1)
           cpAlt:Enable()
           cpAlt:SetAlpha(1)
       end
    end
    UpdateAltState()

    chkMatchAlt:SetScript("OnClick", function(self)
        addon.db.prdMatchAlternate = self:GetChecked()
        UpdateAltState()
        addon:UpdatePRDTextures()
    end)
    
    -- Increase height of section to fit
    prdPanel:SetHeight(540)

    -------------------------------------------------------
    -- Background Panel Tab
    -------------------------------------------------------
    local bgPanel = CreateSection(tabBackground, "Background Panel", "Configure the global background panel.", 300)

    -- Enable Panel
    local chkBGEnable = CreateFrame("CheckButton", nil, bgPanel, "InterfaceOptionsCheckButtonTemplate")
    chkBGEnable:SetPoint("TOPLEFT", bgPanel, "TOPLEFT", 16, -40)
    chkBGEnable.Text:SetText("Enable Background Panel")
    chkBGEnable:SetChecked(addon.db.backgroundPanelEnabled)
    chkBGEnable:SetScript("OnClick", function(self)
        addon.db.backgroundPanelEnabled = self:GetChecked()
        addon:UpdateBackgroundPanel()
    end)
    
    -- Lock Panel
    local chkBGLock = CreateFrame("CheckButton", nil, bgPanel, "InterfaceOptionsCheckButtonTemplate")
    chkBGLock:SetPoint("TOPLEFT", chkBGEnable, "BOTTOMLEFT", 0, -8)
    chkBGLock.Text:SetText("Lock Panel Position")
    chkBGLock:SetChecked(addon.db.backgroundPanelLocked)
    chkBGLock:SetScript("OnClick", function(self)
        addon.db.backgroundPanelLocked = self:GetChecked()
        addon:UpdateBackgroundPanel()
    end)
    
    -- Force Screen Width
    local chkBGForce = CreateFrame("CheckButton", nil, bgPanel, "InterfaceOptionsCheckButtonTemplate")
    chkBGForce:SetPoint("TOPLEFT", chkBGLock, "BOTTOMLEFT", 0, -8)
    chkBGForce.Text:SetText("Force Screen Width")
    chkBGForce:SetChecked(addon.db.backgroundPanelForceWidth)
    
    -- Color Picker
    local lblBGColor = bgPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    lblBGColor:SetPoint("TOPLEFT", chkBGForce, "BOTTOMLEFT", 0, -20)
    lblBGColor:SetText("Panel Color / Alpha")
    
    local btnBGColor = CreateFrame("Button", nil, bgPanel)
    btnBGColor:SetSize(20, 20)
    btnBGColor:SetPoint("LEFT", lblBGColor, "RIGHT", 10, 0)
    btnBGColor.texture = btnBGColor:CreateTexture(nil, "ARTWORK")
    btnBGColor.texture:SetAllPoints()
    btnBGColor.texture:SetColorTexture(1, 1, 1, 1) -- placeholder
    
    local function UpdateBGColorSwatch()
        local c = addon.db.backgroundPanelColor
        btnBGColor.texture:SetColorTexture(c.r, c.g, c.b, c.a)
    end
    UpdateBGColorSwatch()
    
    btnBGColor:SetScript("OnClick", function()
        local c = addon.db.backgroundPanelColor
        
        if ColorPickerFrame.SetupColorPickerAndShow then
            -- New Color Picker API (10.2.5+)
            local info = {
                r = c.r, g = c.g, b = c.b, opacity = c.a,
                hasOpacity = true,
                swatchFunc = function()
                     local r,g,b = ColorPickerFrame:GetColorRGB()
                     local a = ColorPickerFrame:GetColorAlpha()
                     addon.db.backgroundPanelColor = {r=r, g=g, b=b, a=a}
                     UpdateBGColorSwatch()
                     addon:UpdateBackgroundPanel()
                end,
                opacityFunc = function() 
                     local r,g,b = ColorPickerFrame:GetColorRGB()
                     local a = ColorPickerFrame:GetColorAlpha()
                     addon.db.backgroundPanelColor = {r=r, g=g, b=b, a=a}
                     UpdateBGColorSwatch()
                     addon:UpdateBackgroundPanel()
                end,
                cancelFunc = function()
                     addon.db.backgroundPanelColor = {r=c.r, g=c.g, b=c.b, a=c.a}
                     UpdateBGColorSwatch()
                     addon:UpdateBackgroundPanel()
                end
            }
            ColorPickerFrame:SetupColorPickerAndShow(info)
        else
            -- Legacy Color Picker API
            local info = {
                r = c.r, g = c.g, b = c.b, opacity = 1 - c.a,
                hasOpacity = true,
                swatchFunc = function()
                     local r,g,b = ColorPickerFrame:GetColorRGB()
                     local a = 1 - OpacitySliderFrame:GetValue()
                     addon.db.backgroundPanelColor = {r=r, g=g, b=b, a=a}
                     UpdateBGColorSwatch()
                     addon:UpdateBackgroundPanel()
                end,
                opacityFunc = function() 
                     local r,g,b = ColorPickerFrame:GetColorRGB()
                     local a = 1 - OpacitySliderFrame:GetValue()
                     addon.db.backgroundPanelColor = {r=r, g=g, b=b, a=a}
                     UpdateBGColorSwatch()
                     addon:UpdateBackgroundPanel()
                end,
                cancelFunc = function()
                     addon.db.backgroundPanelColor = {r=c.r, g=c.g, b=c.b, a=c.a}
                     UpdateBGColorSwatch()
                     addon:UpdateBackgroundPanel()
                end
            }
            ColorPickerFrame:SetColorRGB(info.r, info.g, info.b)
            ColorPickerFrame.hasOpacity = info.hasOpacity
            ColorPickerFrame.opacity = info.opacity
            ColorPickerFrame.previousValues = {r = info.r, g = info.g, b = info.b, opacity = info.opacity}
            ColorPickerFrame.func = info.swatchFunc
            ColorPickerFrame.opacityFunc = info.opacityFunc
            ColorPickerFrame.cancelFunc = info.cancelFunc
            ColorPickerFrame:Show()
        end
    end)
    
    -- Width / Height Inputs
    local lblDimensions = bgPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    lblDimensions:SetPoint("TOPLEFT", lblBGColor, "BOTTOMLEFT", 0, -20)
    lblDimensions:SetText("Dimensions (Width x Height)")

    local editWidth = CreateFrame("EditBox", nil, bgPanel, "InputBoxTemplate")
    editWidth:SetSize(60, 20)
    editWidth:SetPoint("LEFT", lblDimensions, "RIGHT", 10, 0)
    editWidth:SetAutoFocus(false)
    editWidth:SetNumeric(true)
    editWidth:SetNumber(addon.db.backgroundPanelWidth)
    editWidth:SetScript("OnEnterPressed", function(self) 
        addon.db.backgroundPanelWidth = self:GetNumber()
        self:ClearFocus() 
        addon:UpdateBackgroundPanel()
    end)
    
    local lblX = bgPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    lblX:SetPoint("LEFT", editWidth, "RIGHT", 5, 0)
    lblX:SetText("x")
    
    local editHeight = CreateFrame("EditBox", nil, bgPanel, "InputBoxTemplate")
    editHeight:SetSize(60, 20)
    editHeight:SetPoint("LEFT", lblX, "RIGHT", 5, 0)
    editHeight:SetAutoFocus(false)
    editHeight:SetNumeric(true)
    editHeight:SetNumber(addon.db.backgroundPanelHeight)
    editHeight:SetScript("OnEnterPressed", function(self)
        addon.db.backgroundPanelHeight = self:GetNumber()
        self:ClearFocus()
        addon:UpdateBackgroundPanel()
    end)


    -- Anchor Dropdown
    local lblAnchor = bgPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    lblAnchor:SetPoint("TOPLEFT", lblDimensions, "BOTTOMLEFT", 0, -20)
    lblAnchor:SetText("Anchor Point")

    local dropAnchor = CreateFrame("Frame", "GarageUITweaksBGAnchorDrop", bgPanel, "UIDropDownMenuTemplate")
    dropAnchor:SetPoint("LEFT", lblAnchor, "RIGHT", -10, -2)
    
    local function InitAnchorMenu(self, level, menuList)
        local anchors = {
            "TOPLEFT", "TOP", "TOPRIGHT",
            "LEFT", "CENTER", "RIGHT",
            "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT"
        }
        
        local info = UIDropDownMenu_CreateInfo()
        for _, anchor in ipairs(anchors) do
            info.text = anchor
            info.func = function()
                -- When changing anchor, we want to keep the panel in the same visual spot
                -- But X/Y need to be recalculated relative to the new anchor
                -- This is tricky without the frame being available here easily to GetCenter etc
                -- However, BackgroundPanel.lua has the frame.
                
                -- We'll just set the DB and let UpdateBackgroundPanel handle potential jumps
                -- OR we could try to be smart if the frame is shown.
                -- For now, simple switch. User can drag to fix.
                
                addon.db.backgroundPanelAnchor = anchor
                UIDropDownMenu_SetSelectedValue(dropAnchor, anchor)
                if addon.UpdateBackgroundPanel then
                     -- Ideally we reset position to center if it goes off screen, but let's just update
                     addon:UpdateBackgroundPanel(true) -- Pass true to indicate "Anchor Changed" if we want special logic
                end
            end
            info.checked = (addon.db.backgroundPanelAnchor == anchor)
            UIDropDownMenu_AddButton(info)
        end
    end
    
    UIDropDownMenu_Initialize(dropAnchor, InitAnchorMenu)
    UIDropDownMenu_SetWidth(dropAnchor, 120)
    UIDropDownMenu_SetSelectedValue(dropAnchor, addon.db.backgroundPanelAnchor or "CENTER")
    UIDropDownMenu_JustifyText(dropAnchor, "LEFT")



    -- Reset Button
    local btnReset = CreateFrame("Button", nil, bgPanel, "UIPanelButtonTemplate")
    btnReset:SetSize(120, 22)
    btnReset:SetPoint("TOPLEFT", lblAnchor, "BOTTOMLEFT", 0, -30)
    btnReset:SetText("Reset Position")
    btnReset:SetScript("OnClick", function()
        -- Reset database values to default
        addon.db.backgroundPanelWidth = 400
        addon.db.backgroundPanelHeight = 100
        addon.db.backgroundPanelX = 0
        addon.db.backgroundPanelY = 0
        addon.db.backgroundPanelAnchor = "CENTER"
        addon.db.backgroundPanelForceWidth = false
        
        -- Update UI
        addon:UpdateBackgroundPanel()
        addon:RefreshSettings("background")
    end)


    -- Force width update logic
    local function UpdateWidthState()
        if addon.db.backgroundPanelForceWidth then
             editWidth:Disable()
             editWidth:SetTextColor(0.5, 0.5, 0.5)
        else
             editWidth:Enable()
             editWidth:SetTextColor(1, 1, 1)
        end
    end
    UpdateWidthState()
    
    chkBGForce:SetScript("OnClick", function(self)
        addon.db.backgroundPanelForceWidth = self:GetChecked()
        UpdateWidthState()
        addon:UpdateBackgroundPanel()
    end)
    
    -- Listener for external updates (e.g. drag resizing)
    function addon:RefreshSettings(module)
        if module == "background" and editWidth:IsVisible() then
             -- Round to avoid excessive decimals
             editWidth:SetNumber(math.floor(addon.db.backgroundPanelWidth + 0.5))
             editHeight:SetNumber(math.floor(addon.db.backgroundPanelHeight + 0.5))
             chkBGEnable:SetChecked(addon.db.backgroundPanelEnabled)
             chkBGLock:SetChecked(addon.db.backgroundPanelLocked)
             
             UIDropDownMenu_SetSelectedValue(dropAnchor, addon.db.backgroundPanelAnchor)
             UIDropDownMenu_SetText(dropAnchor, addon.db.backgroundPanelAnchor)
        end
    end


    -- ====================
    -- NAMEPLATE TAB CONTENT
    -- ====================
    local npPanel, npTitle = CreateSection(tabNameplates, "Nameplate Settings", "Configure nameplate behavior and appearance.", 220)

    -- Simplified Nameplate Scale Slider
    local npScaleSlider = CreateFrame("Slider", nil, npPanel, "OptionsSliderTemplate")
    npScaleSlider:SetPoint("TOPLEFT", npTitle, "BOTTOMLEFT", 0, -28)
    npScaleSlider:SetMinMaxValues(0.15, 1.0)
    npScaleSlider:SetValue(addon.db.nameplateSimplifiedScale or 1.0)
    npScaleSlider:SetValueStep(0.05)
    npScaleSlider:SetObeyStepOnDrag(true)
    npScaleSlider:SetWidth(200)
    npScaleSlider.Low:SetText("15%")
    npScaleSlider.High:SetText("100%")
    npScaleSlider.Text:SetText(string.format("Simplified Scale: %.0f%%", (addon.db.nameplateSimplifiedScale or 1.0) * 100))
    npScaleSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value * 20 + 0.5) / 20 -- Rounding to nearest 0.05
        self.Text:SetText(string.format("Simplified Scale: %.0f%%", value * 100))
        addon.db.nameplateSimplifiedScale = value
        
        -- Apply the scale using our addon logic
        if addon.UpdateNameplateScale then
             addon:UpdateNameplateScale()
        end
    end)

    -- Friendly Name Class Color Checkbox
    local npClassColor = CreateFrame("CheckButton", nil, npPanel, "InterfaceOptionsCheckButtonTemplate")
    npClassColor:SetPoint("TOPLEFT", npScaleSlider, "BOTTOMLEFT", 0, -28)
    npClassColor.Text:SetText("Use Class Colors on Friendly Names")
    npClassColor:SetChecked(addon.db.nameplateUseClassColorForFriendlyPlayerUnitNames)
    npClassColor:SetScript("OnClick", function(self)
        local isChecked = self:GetChecked()
        addon.db.nameplateUseClassColorForFriendlyPlayerUnitNames = isChecked
        if addon.SetFriendlyClassColorCVar then
            addon:SetFriendlyClassColorCVar(isChecked)
        else
            local val = isChecked and "1" or "0"
            if C_CVar and C_CVar.SetCVar then
                pcall(function() C_CVar.SetCVar("nameplateUseClassColorForFriendlyPlayerUnitNames", val) end)
            elseif SetCVar then
                pcall(function() SetCVar("nameplateUseClassColorForFriendlyPlayerUnitNames", val) end)
            end
            if ConsoleExec then
                ConsoleExec("nameplateUseClassColorForFriendlyPlayerUnitNames " .. val)
            end
        end
        if addon.UpdateFriendlyNameplates then
            addon:UpdateFriendlyNameplates()
        end
    end)

    local npFriendlyPanel, npFriendlyTitle = CreateSection(tabNameplates, "Friendly Simplified Names", "Render readable names above simplified friendly player nameplates.", 470)
    local npFriendlyLeftInset = 10

    local npFriendlyEnabled = CreateFrame("CheckButton", nil, npFriendlyPanel, "InterfaceOptionsCheckButtonTemplate")
    npFriendlyEnabled:SetPoint("TOPLEFT", npFriendlyTitle, "BOTTOMLEFT", npFriendlyLeftInset, -12)
    npFriendlyEnabled.Text:SetText("Enable Friendly Name Rendering")
    npFriendlyEnabled:SetChecked(addon.db.nameplateFriendlyNamesEnabled ~= false)
    npFriendlyEnabled:SetScript("OnClick", function(self)
        addon.db.nameplateFriendlyNamesEnabled = self:GetChecked()
        if addon.UpdateFriendlyNameplates then addon:UpdateFriendlyNameplates() end
    end)

    local npFriendlyShowTitle = CreateFrame("CheckButton", nil, npFriendlyPanel, "InterfaceOptionsCheckButtonTemplate")
    npFriendlyShowTitle:SetPoint("TOPLEFT", npFriendlyEnabled, "BOTTOMLEFT", 0, -4)
    npFriendlyShowTitle.Text:SetText("Show Title")
    npFriendlyShowTitle:SetChecked(addon.db.nameplateFriendlyNamesShowTitle == true)
    npFriendlyShowTitle:SetScript("OnClick", function(self)
        addon.db.nameplateFriendlyNamesShowTitle = self:GetChecked()
        if addon.UpdateFriendlyNameplates then addon:UpdateFriendlyNameplates() end
    end)

    local fontLabel = npFriendlyPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    fontLabel:SetPoint("TOPLEFT", npFriendlyPanel, "TOPLEFT", npFriendlyLeftInset, -96)
    fontLabel:SetText("Font")

    local fontDropdown = CreateFrame("Frame", "GUIT_FriendlyNameFontDropdown", npFriendlyPanel, "UIDropDownMenuTemplate")
    fontDropdown:SetPoint("TOPLEFT", fontLabel, "BOTTOMLEFT", -8, -2)
    UIDropDownMenu_SetWidth(fontDropdown, 210)

    local function BuildFriendlyFontList()
        local fontList = {
            { name = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF", group = "Blizzard" },
            { name = "Arial Narrow", path = "Fonts\\ARIALN.TTF", group = "Blizzard" },
            { name = "Morpheus", path = "Fonts\\MORPHEUS.TTF", group = "Blizzard" },
            { name = "Skurri", path = "Fonts\\SKURRI.TTF", group = "Blizzard" },
        }

        local seenByPath = {}
        for _, item in ipairs(fontList) do
            seenByPath[item.path] = true
        end

        local function AddFontOption(name, path, group)
            if not path or path == "" or seenByPath[path] then
                return
            end
            seenByPath[path] = true
            table.insert(fontList, { name = name, path = path, group = group or "Other" })
        end

        if LSM then
            local fonts = LSM:HashTable("font")
            local keys = {}
            for k in pairs(fonts) do table.insert(keys, k) end
            table.sort(keys)
            for _, key in ipairs(keys) do
                local fontPath = fonts[key]
                AddFontOption(key, fontPath, "LibSharedMedia")
            end
        end

        local function AddFontMagicFonts()
            local hasFontMagic = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("FontMagic")
            if not hasFontMagic then
                return
            end

            local fontMagicPath = "Interface\\AddOns\\FontMagic\\"
            local groups = {
                { label = "Popular", folder = "Popular", fonts = {
                    "Pepsi.ttf", "bignoodletitling.ttf", "Expressway.ttf", "Bangers.ttf", "PTSansNarrow-Bold.ttf", "Roboto Condensed Bold.ttf",
                    "NotoSans_Condensed-Bold.ttf", "Roboto-Bold.ttf", "AlteHaasGroteskBold.ttf", "CalibriBold.ttf", "Orbitron.ttf", "Prototype.ttf",
                    "914Solid.ttf", "Halo.ttf", "Proxima Nova Condensed Bold.ttf", "Comfortaa-Bold.ttf", "Andika-Bold.ttf", "lemon-milk.ttf",
                    "Good Brush.ttf", "KG HAPPY.ttf",
                } },
                { label = "Clean & Readable", folder = "Easy-to-Read", fonts = {
                    "BauhausRegular.ttf", "Butterpop.ttf", "Diogenes.ttf", "Junegull.ttf", "Pantalone.ttf", "Resoft.ttf",
                    "Retro Amour.ttf", "SF-Pro.ttf", "Solange.ttf", "Takeaway.ttf",
                } },
                { label = "Bold & Impact", folder = "BoldImpact", fonts = {
                    "airstrikebold.ttf", "Blazed.ttf", "DieDieDie.ttf", "graff.ttf", "Green Fuz.otf", "Love Craft.ttf",
                    "modernwarfare.ttf", "Showpop.ttf", "Skratchpunk.ttf", "Skullphabet.ttf", "Trashco.ttf", "Whiplash.ttf",
                } },
                { label = "Fantasy & RP", folder = "Fun", fonts = {
                    "Acadian.ttf", "akash.ttf", "Caesar.ttf", "ComicRunes.ttf", "crygords.ttf", "Deltarune.ttf",
                    "Elven.ttf", "Gunung.ttf", "Guroes.ttf", "HarryP.ttf", "Hobbit.ttf", "Kting.ttf",
                    "leviathans.ttf", "MystikOrbs.ttf", "Odinson.ttf", "ParryHotter.ttf", "Pau.ttf", "Pokemon.ttf",
                    "Runic.ttf", "Runy.ttf", "Ruritania.ttf", "Spongebob.ttf", "Starborn.ttf", "Starshines.ttf",
                    "The Centurion .ttf", "Vampire Wars.ttf", "VTKS.ttf", "WaltographUI.ttf", "Wasser.ttf", "Wickedmouse.ttf",
                    "WKnight.ttf", "Zombie.ttf",
                } },
                { label = "Sci-Fi & Tech", folder = "Future", fonts = {
                    "04b.ttf", "albra.TTF", "Audiowide.ttf", "continuum.ttf", "dalek.ttf", "digital-7.ttf",
                    "Digital.ttf", "Exocet.ttf", "Galaxyone.ttf", "Minecrafter.Reg.ttf", "pf_tempesta_seven.ttf", "Price.ttf",
                    "RaceSpace.ttf", "RushDriver.ttf", "space age.ttf", "Terminator.ttf",
                } },
                { label = "Random", folder = "Random", fonts = {
                    "accidentalpres.ttf", "animeace.ttf", "Barriecito.ttf", "baskethammer.ttf", "ChopSic.ttf", "college.ttf",
                    "Disko.ttf", "Dmagic.ttf", "edgyh.ttf", "edkies.ttf", "FastHand.ttf", "figtoen.ttf",
                    "font2.ttf", "Fraks.ttf", "Ginko.ttf", "Homespun.ttf", "IKARRG.TTF", "JJSTS.TTF",
                    "KOMIKAX_.ttf", "Ktingw.ttf", "Melted.ttf", "Midorima.ttf", "Munsteria.ttf", "Rebuffed.TTF",
                    "Shiruken.ttf", "shog.ttf", "Starcine.ttf", "Stentiga.ttf", "tsuchigumo.ttf", "WhoAsksSatan.ttf",
                } },
            }

            local function TryAdd(groupLabel, basePath, fileName)
                local fullPath = basePath .. fileName
                if seenByPath[fullPath] then
                    return
                end

                local label = fileName:gsub("%.[Tt][Tt][Ff]$", ""):gsub("%.[Oo][Tt][Ff]$", "")
                AddFontOption(label, fullPath, "FontMagic: " .. groupLabel)
            end

            for _, group in ipairs(groups) do
                local basePath = fontMagicPath .. group.folder .. "\\"
                for _, fileName in ipairs(group.fonts) do
                    TryAdd(group.label, basePath, fileName)
                end
            end

            local customPath = "Interface\\AddOns\\FontMagicCustomFonts\\Custom\\"
            if type(FontMagicCustomFonts) == "table" and type(FontMagicCustomFonts.PATH) == "string" and FontMagicCustomFonts.PATH ~= "" then
                customPath = FontMagicCustomFonts.PATH
            end
            for i = 1, 20 do
                TryAdd("Custom", customPath, i .. ".ttf")
            end
        end

        AddFontMagicFonts()

        local grouped = {}
        local groupOrder = { "Blizzard", "LibSharedMedia" }
        local known = { Blizzard = true, LibSharedMedia = true }

        for _, item in ipairs(fontList) do
            local group = item.group or "Other"
            grouped[group] = grouped[group] or {}
            table.insert(grouped[group], item)
            if not known[group] then
                known[group] = true
                table.insert(groupOrder, group)
            end
        end

        table.sort(groupOrder, function(a, b)
            if a:find("^FontMagic:") and not b:find("^FontMagic:") then return false end
            if b:find("^FontMagic:") and not a:find("^FontMagic:") then return true end
            return a < b
        end)

        for _, group in ipairs(groupOrder) do
            table.sort(grouped[group], function(a, b)
                return a.name:lower() < b.name:lower()
            end)
        end

        return fontList, grouped, groupOrder
    end

    local function GetFriendlyFontDisplayName(path)
        local list = BuildFriendlyFontList()
        for _, item in ipairs(list) do
            if item.path == path then
                return item.group and (item.group .. " - " .. item.name) or item.name
            end
        end
        return "Custom/Unknown"
    end

    UIDropDownMenu_Initialize(fontDropdown, function(self, level)
        local selected = addon.db.nameplateFriendlyNameFont or "Fonts\\FRIZQT__.TTF"
        local _, grouped, groupOrder = BuildFriendlyFontList()
        local menuList = UIDROPDOWNMENU_MENU_VALUE

        if level == 1 then
            for _, group in ipairs(groupOrder) do
                local fontsInGroup = grouped[group] or {}
                if #fontsInGroup > 0 then
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = group
                    info.hasArrow = true
                    info.notCheckable = true
                    info.value = { kind = "group", group = group }
                    UIDropDownMenu_AddButton(info, level)
                end
            end
            return
        end

        if level == 2 and type(menuList) == "table" and menuList.kind == "group" then
            local group = menuList.group
            local fontsInGroup = grouped[group] or {}
            if #fontsInGroup > 24 then
                local idx = 1
                while idx <= #fontsInGroup do
                    local finish = math.min(idx + 23, #fontsInGroup)
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = string.format("%d-%d", idx, finish)
                    info.hasArrow = true
                    info.notCheckable = true
                    info.value = { kind = "page", group = group, startIndex = idx, endIndex = finish }
                    UIDropDownMenu_AddButton(info, level)
                    idx = finish + 1
                end
            else
                for _, item in ipairs(fontsInGroup) do
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = item.name
                    info.value = item.path
                    info.func = function(btn)
                        addon.db.nameplateFriendlyNameFont = btn.value
                        UIDropDownMenu_SetSelectedValue(fontDropdown, btn.value)
                        UIDropDownMenu_SetText(fontDropdown, GetFriendlyFontDisplayName(btn.value))
                        if addon.UpdateFriendlyNameplates then addon:UpdateFriendlyNameplates() end
                    end
                    info.checked = (selected == item.path)
                    UIDropDownMenu_AddButton(info, level)
                end
            end
            return
        end

        if level == 3 and type(menuList) == "table" and menuList.kind == "page" then
            local group = menuList.group
            local fontsInGroup = grouped[group] or {}
            for idx = menuList.startIndex, menuList.endIndex do
                local item = fontsInGroup[idx]
                if item then
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = item.name
                    info.value = item.path
                    info.func = function(btn)
                        addon.db.nameplateFriendlyNameFont = btn.value
                        UIDropDownMenu_SetSelectedValue(fontDropdown, btn.value)
                        UIDropDownMenu_SetText(fontDropdown, GetFriendlyFontDisplayName(btn.value))
                        if addon.UpdateFriendlyNameplates then addon:UpdateFriendlyNameplates() end
                    end
                    info.checked = (selected == item.path)
                    UIDropDownMenu_AddButton(info, level)
                end
            end
        end
    end)

    local selectedFriendlyFont = addon.db.nameplateFriendlyNameFont or "Fonts\\FRIZQT__.TTF"
    UIDropDownMenu_SetSelectedValue(fontDropdown, selectedFriendlyFont)
    UIDropDownMenu_SetText(fontDropdown, GetFriendlyFontDisplayName(selectedFriendlyFont))

    local function CreateNameColorSwatch(parent, relativeTo)
        local lbl = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        lbl:SetPoint("LEFT", relativeTo, "RIGHT", 26, 0)
        lbl:SetText("Color")

        local swatch = CreateFrame("Button", nil, parent, "BackdropTemplate")
        swatch:SetSize(20, 20)
        swatch:SetPoint("LEFT", lbl, "RIGHT", 8, 0)
        swatch:SetBackdrop({
            edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1,
            bgFile = "Interface\\Buttons\\WHITE8x8", tiling = false
        })
        swatch:SetBackdropBorderColor(0.6, 0.6, 0.6)

        local function UpdateSwatch()
            local c = addon.db.nameplateFriendlyNameColor or { r = 1, g = 1, b = 1, a = 1 }
            swatch:SetBackdropColor(c.r, c.g, c.b, c.a or 1)
        end
        UpdateSwatch()

        swatch:SetScript("OnClick", function()
            local c = addon.db.nameplateFriendlyNameColor or { r = 1, g = 1, b = 1, a = 1 }

            local function GetAlphaSafe()
                if ColorPickerFrame.GetColorAlpha then
                    return ColorPickerFrame:GetColorAlpha()
                elseif OpacitySliderFrame then
                    return 1 - OpacitySliderFrame:GetValue()
                end
                return 1
            end

            local info = {
                r = c.r,
                g = c.g,
                b = c.b,
                opacity = 1 - (c.a or 1),
                hasOpacity = true,
                swatchFunc = function()
                    local r, g, b = ColorPickerFrame:GetColorRGB()
                    local a = GetAlphaSafe()
                    addon.db.nameplateFriendlyNameColor = { r = r, g = g, b = b, a = a }
                    UpdateSwatch()
                    if addon.UpdateFriendlyNameplates then addon:UpdateFriendlyNameplates() end
                end,
                opacityFunc = function()
                    local r, g, b = ColorPickerFrame:GetColorRGB()
                    local a = GetAlphaSafe()
                    addon.db.nameplateFriendlyNameColor = { r = r, g = g, b = b, a = a }
                    UpdateSwatch()
                    if addon.UpdateFriendlyNameplates then addon:UpdateFriendlyNameplates() end
                end,
                cancelFunc = function()
                    addon.db.nameplateFriendlyNameColor = c
                    UpdateSwatch()
                    if addon.UpdateFriendlyNameplates then addon:UpdateFriendlyNameplates() end
                end,
            }

            ColorPickerFrame:SetupColorPickerAndShow(info)
        end)

        return swatch
    end

    local _ = CreateNameColorSwatch(npFriendlyPanel, fontDropdown)

    local outlineLabel = npFriendlyPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    outlineLabel:SetPoint("TOPLEFT", fontDropdown, "BOTTOMLEFT", 0, -18)
    outlineLabel:SetText("Outline Type")

    local outlineDropdown = CreateFrame("Frame", "GUIT_FriendlyNameOutlineDropdown", npFriendlyPanel, "UIDropDownMenuTemplate")
    outlineDropdown:SetPoint("TOPLEFT", outlineLabel, "BOTTOMLEFT", -8, -2)
    UIDropDownMenu_SetWidth(outlineDropdown, 160)

    UIDropDownMenu_Initialize(outlineDropdown, function(self, level)
        local selected = (addon.db.nameplateFriendlyNameOutline or "OUTLINE"):upper()
        local options = {
            { text = "None", value = "NONE" },
            { text = "Outline", value = "OUTLINE" },
            { text = "Thick Outline", value = "THICKOUTLINE" },
        }

        for _, option in ipairs(options) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.text
            info.value = option.value
            info.checked = selected == option.value
            info.func = function(btn)
                addon.db.nameplateFriendlyNameOutline = btn.value
                UIDropDownMenu_SetSelectedValue(outlineDropdown, btn.value)
                UIDropDownMenu_SetText(outlineDropdown, option.text)
                if addon.UpdateFriendlyNameplates then addon:UpdateFriendlyNameplates() end
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    local selectedOutline = (addon.db.nameplateFriendlyNameOutline or "OUTLINE"):upper()
    local outlineText = selectedOutline == "NONE" and "None" or (selectedOutline == "THICKOUTLINE" and "Thick Outline" or "Outline")
    UIDropDownMenu_SetSelectedValue(outlineDropdown, selectedOutline)
    UIDropDownMenu_SetText(outlineDropdown, outlineText)

    local sizeSlider = CreateFrame("Slider", nil, npFriendlyPanel, "OptionsSliderTemplate")
    sizeSlider:SetPoint("TOPLEFT", npFriendlyPanel, "TOPLEFT", npFriendlyLeftInset + 8, -232)
    sizeSlider:SetMinMaxValues(8, 64)
    sizeSlider:SetValueStep(1)
    sizeSlider:SetObeyStepOnDrag(true)
    sizeSlider:SetWidth(220)
    sizeSlider.Low:SetText("8")
    sizeSlider.High:SetText("64")
    sizeSlider:SetValue(addon.db.nameplateFriendlyNameSize or 13)
    sizeSlider.Text:SetText(string.format("Font Size: %d", addon.db.nameplateFriendlyNameSize or 13))
    sizeSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        addon.db.nameplateFriendlyNameSize = value
        self.Text:SetText(string.format("Font Size: %d", value))
        if addon.UpdateFriendlyNameplates then addon:UpdateFriendlyNameplates() end
    end)

    local xSlider = CreateFrame("Slider", nil, npFriendlyPanel, "OptionsSliderTemplate")
    xSlider:SetPoint("TOPLEFT", sizeSlider, "BOTTOMLEFT", 0, -30)
    xSlider:SetMinMaxValues(-100, 100)
    xSlider:SetValueStep(1)
    xSlider:SetObeyStepOnDrag(true)
    xSlider:SetWidth(220)
    xSlider.Low:SetText("-100")
    xSlider.High:SetText("100")
    xSlider:SetValue(addon.db.nameplateFriendlyNameOffsetX or 0)
    xSlider.Text:SetText(string.format("X Offset: %d", addon.db.nameplateFriendlyNameOffsetX or 0))
    xSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        addon.db.nameplateFriendlyNameOffsetX = value
        self.Text:SetText(string.format("X Offset: %d", value))
        if addon.UpdateFriendlyNameplates then addon:UpdateFriendlyNameplates() end
    end)

    local ySlider = CreateFrame("Slider", nil, npFriendlyPanel, "OptionsSliderTemplate")
    ySlider:SetPoint("TOPLEFT", xSlider, "BOTTOMLEFT", 0, -30)
    ySlider:SetMinMaxValues(-100, 100)
    ySlider:SetValueStep(1)
    ySlider:SetObeyStepOnDrag(true)
    ySlider:SetWidth(220)
    ySlider.Low:SetText("-100")
    ySlider.High:SetText("100")
    ySlider:SetValue(addon.db.nameplateFriendlyNameOffsetY or 10)
    ySlider.Text:SetText(string.format("Y Offset: %d", addon.db.nameplateFriendlyNameOffsetY or 10))
    ySlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        addon.db.nameplateFriendlyNameOffsetY = value
        self.Text:SetText(string.format("Y Offset: %d", value))
        if addon.UpdateFriendlyNameplates then addon:UpdateFriendlyNameplates() end
    end)

    local justifyLabel = npFriendlyPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    justifyLabel:SetPoint("TOPLEFT", ySlider, "BOTTOMLEFT", 0, -22)
    justifyLabel:SetText("Justification")

    local justifyDropdown = CreateFrame("Frame", "GUIT_FriendlyNameJustifyDropdown", npFriendlyPanel, "UIDropDownMenuTemplate")
    justifyDropdown:SetPoint("TOPLEFT", justifyLabel, "BOTTOMLEFT", -8, -2)
    UIDropDownMenu_SetWidth(justifyDropdown, 120)

    UIDropDownMenu_Initialize(justifyDropdown, function(self, level)
        local selected = (addon.db.nameplateFriendlyNameJustify or "CENTER"):upper()
        local options = {
            { text = "Left", value = "LEFT" },
            { text = "Center", value = "CENTER" },
            { text = "Right", value = "RIGHT" },
        }

        for _, option in ipairs(options) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.text
            info.value = option.value
            info.checked = selected == option.value
            info.func = function(btn)
                addon.db.nameplateFriendlyNameJustify = btn.value
                UIDropDownMenu_SetSelectedValue(justifyDropdown, btn.value)
                UIDropDownMenu_SetText(justifyDropdown, option.text)
                if addon.UpdateFriendlyNameplates then addon:UpdateFriendlyNameplates() end
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    local selectedJustify = (addon.db.nameplateFriendlyNameJustify or "CENTER"):upper()
    local justifyText = selectedJustify == "LEFT" and "Left" or (selectedJustify == "RIGHT" and "Right" or "Center")
    UIDropDownMenu_SetSelectedValue(justifyDropdown, selectedJustify)
    UIDropDownMenu_SetText(justifyDropdown, justifyText)

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
