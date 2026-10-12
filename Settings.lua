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

    local overview = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    overview:SetPoint("TOPLEFT", enabledCheckbox, "BOTTOMLEFT", 4, -12)
    overview:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
    overview:SetJustifyH("LEFT")
    overview:SetText("Expand Garage UI Tweaks in the Settings list to open individual tweak pages.")

    local orderedPages = {}

    local function CreateSettingsPage(id, pageTitle, pageDescription)
        local frameName = "GarageUITweaksSettingsPage_" .. id
        local page = CreateFrame("Frame", frameName, UIParent)
        page.name = pageTitle
        page.parent = panel.name

        local titleText = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        titleText:SetPoint("TOPLEFT", 16, -16)
        titleText:SetText(pageTitle)

        local descText = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        descText:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -8)
        descText:SetPoint("RIGHT", page, "RIGHT", -16, 0)
        descText:SetJustifyH("LEFT")
        descText:SetText(pageDescription or "")

        local scrollFrame = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", descText, "BOTTOMLEFT", 0, -12)
        scrollFrame:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -32, 12)

        local scrollChild = CreateFrame("Frame", nil, scrollFrame)
        scrollChild:SetHeight(1)
        scrollChild:SetWidth(1)
        scrollFrame:SetScrollChild(scrollChild)

        scrollFrame:SetScript("OnSizeChanged", function(self)
            scrollChild:SetWidth(self:GetWidth())
        end)

        if id == "background" then
            page:SetScript("OnShow", function()
                if addon.RefreshSettings then
                    addon:RefreshSettings("background")
                end
            end)
        end

        local pageInfo = {
            id = id,
            name = pageTitle,
            frame = page,
            scrollChild = scrollChild,
            totalHeight = 0,
            lastSection = nil,
            visibleSections = 0,
        }

        table.insert(orderedPages, pageInfo)
        return pageInfo
    end

    -- Page Definitions
    local tabGeneral = CreateSettingsPage("general", "General Tweaks", "Core quality-of-life improvements and shared behavior.")
    local tabFrameAdjustments = CreateSettingsPage("frameadjustments", "Frame Tweaks", "Adjust frame strata and status tracking positioning.")
    local tabChat = CreateSettingsPage("chat", "Chat Tweaks", "Customize chat behavior and chat frame controls.")
    local tabSpeed = CreateSettingsPage("speed", "Speed Panel Tweaks", "Configure movement speed display options.")
    local tabCooldowns = CreateSettingsPage("cooldowns", "Cooldown Tweaks", "Configure cooldown display options.")
    local tabNameplates = CreateSettingsPage("nameplates", "Nameplate Tweaks", "Configure friendly nameplate appearance.")
    local tabBackground = CreateSettingsPage("background", "Background Panel Tweaks", "Background panel and visual backdrop options.")

    -- Helper to add sections to a tab
    -- featureID (optional): a Compat.lua feature; when the client can't support it the
    -- section is still built, so the control code below it runs, but left out of the layout.
    local function CreateSection(tab, titleText, descriptionText, height, featureID)
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
        section:SetHeight(height)

        local supported = not featureID or addon:IsFeatureSupported(featureID)
        if not supported then
            section:Hide()
        elseif tab.lastSection then
            section:SetPoint("TOPLEFT", tab.lastSection, "BOTTOMLEFT", 0, -16)
            section:SetPoint("RIGHT", parent, "RIGHT", -4, 0)
            tab.totalHeight = tab.totalHeight + 16
        else
            section:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -4)
            section:SetPoint("RIGHT", parent, "RIGHT", -4, 0)
            tab.totalHeight = tab.totalHeight + 4
        end

        local title = section:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        title:SetPoint("TOPLEFT", 10, -12) -- Adjusted padding to match Knack's padding roughly
        title:SetText(titleText)

        local desc = section:CreateFontString(nil, "ARTWORK", "GameFontHighlight") -- Changed from Small
        desc:SetPoint("TOPLEFT", title, "TOPRIGHT", 12, 0)
        desc:SetPoint("RIGHT", section, "RIGHT", -12, 0)
        desc:SetJustifyH("LEFT")
        desc:SetText(descriptionText)

        if supported then
            tab.lastSection = section
            tab.visibleSections = tab.visibleSections + 1
            tab.totalHeight = tab.totalHeight + height
            parent:SetHeight(math.max(tab.totalHeight, 100))
        end

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

    -- Encounter Bar Prey %
    local encounterBarGroup, encounterBarTitle = CreateSection(tabGeneral, "Encounter Bar", "Show the prey's health percentage on the encounter bar when hunting prey in outdoor zones.", 80, "preyPercent")

    local encounterPercentCheck = CreateFrame("CheckButton", nil, encounterBarGroup, "InterfaceOptionsCheckButtonTemplate")
    encounterPercentCheck:SetPoint("TOPLEFT", encounterBarTitle, "BOTTOMLEFT", 0, -10)
    encounterPercentCheck.Text:SetText("Show prey encounter percentage")
    encounterPercentCheck:SetChecked(addon.db.encounterBarPreyPercentEnabled)
    encounterPercentCheck:SetScript("OnClick", function(self)
        addon.db.encounterBarPreyPercentEnabled = self:GetChecked()
        addon:InitEncounterBarPreyPercent()
    end)

    -- Armor Set Action Highlights
    local armorSetHighlightGroup, armorSetHighlightTitle = CreateSection(tabGeneral, "Armor Set Action Highlights", "Outline action buttons that trigger your currently equipped armor set.", 80, "armorSetHighlight")

    local armorSetHighlightCheck = CreateFrame("CheckButton", nil, armorSetHighlightGroup, "InterfaceOptionsCheckButtonTemplate")
    armorSetHighlightCheck:SetPoint("TOPLEFT", armorSetHighlightTitle, "BOTTOMLEFT", 0, -10)
    armorSetHighlightCheck.Text:SetText("Use assisted-combat style outline for equipped set buttons")
    armorSetHighlightCheck:SetChecked(addon.db.armorSetActionHighlightEnabled)
    armorSetHighlightCheck:SetScript("OnClick", function(self)
        addon.db.armorSetActionHighlightEnabled = self:GetChecked()
        if addon.SetArmorSetActionHighlightEnabled then
            addon:SetArmorSetActionHighlightEnabled(addon.db.armorSetActionHighlightEnabled)
        end
    end)

    -- Micro Menu
    local microMenuGroup, microMenuTitle = CreateSection(tabGeneral, "Micro Menu", "Adjust the appearance of the micro menu bar.", 110, "microMenuArt")

    local microMenuArtCheck = CreateFrame("CheckButton", nil, microMenuGroup, "InterfaceOptionsCheckButtonTemplate")
    microMenuArtCheck:SetPoint("TOPLEFT", microMenuTitle, "BOTTOMLEFT", 0, -10)
    microMenuArtCheck.Text:SetText("Hide micro menu background art")
    microMenuArtCheck:SetChecked(addon.db.hideMicroMenuBackgroundArt)
    microMenuArtCheck:SetScript("OnClick", function(self)
        addon.db.hideMicroMenuBackgroundArt = self:GetChecked()
        addon:UpdateMicroMenuArt()
    end)

    local microMenuBorderCheck = CreateFrame("CheckButton", nil, microMenuGroup, "InterfaceOptionsCheckButtonTemplate")
    microMenuBorderCheck:SetPoint("TOPLEFT", microMenuArtCheck, "BOTTOMLEFT", 0, -6)
    microMenuBorderCheck.Text:SetText("Hide micro menu border art")
    microMenuBorderCheck:SetChecked(addon.db.hideMicroMenuBorderArt)
    microMenuBorderCheck:SetScript("OnClick", function(self)
        addon.db.hideMicroMenuBorderArt = self:GetChecked()
        addon:UpdateMicroMenuArt()
    end)

    -- ====================
    -- FRAME ADJUSTMENTS TAB CONTENT
    -- ====================

    -- Map Scale
    local bgMapScale, bgMapTitle = CreateSection(tabFrameAdjustments, "Battleground Map Scale", "Adjust the battlefield map size (Shift+M).", 130)
    
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

    local mapLowestStrataCheckbox = CreateFrame("CheckButton", nil, bgMapScale, "InterfaceOptionsCheckButtonTemplate")
    mapLowestStrataCheckbox:SetPoint("TOPLEFT", scaleSlider, "BOTTOMLEFT", 0, -10)
    mapLowestStrataCheckbox.Text:SetText("Force map to lowest strata")
    mapLowestStrataCheckbox:SetChecked(addon.db.battlegroundMapForceLowestStrata)
    mapLowestStrataCheckbox:SetScript("OnClick", function(self)
        addon.db.battlegroundMapForceLowestStrata = self:GetChecked()
        addon:ApplyTweaks()
    end)

    -- Experience Bars
    local expBarStrataGroup, expBarStrataTitle = CreateSection(tabFrameAdjustments, "Experience Bars", "Adjust strata behavior for XP/reputation/honor tracking bars.", 80)

    local expBarHighestStrataCheckbox = CreateFrame("CheckButton", nil, expBarStrataGroup, "InterfaceOptionsCheckButtonTemplate")
    expBarHighestStrataCheckbox:SetPoint("TOPLEFT", expBarStrataTitle, "BOTTOMLEFT", 0, -10)
    expBarHighestStrataCheckbox.Text:SetText("Force experience bars to highest strata")
    expBarHighestStrataCheckbox:SetChecked(addon.db.experienceBarsForceHighestStrata)
    expBarHighestStrataCheckbox:SetScript("OnClick", function(self)
        addon.db.experienceBarsForceHighestStrata = self:GetChecked()
        addon:ApplyTweaks()
    end)

    -- Center Raid/Party Frames
    local centerFramesGroup, centerFramesTitle = CreateSection(tabFrameAdjustments, "Raid & Party Frames", "Keep party and raid frame groups centered as they resize.", 110)

    local centerPartyCheckbox = CreateFrame("CheckButton", nil, centerFramesGroup, "InterfaceOptionsCheckButtonTemplate")
    centerPartyCheckbox:SetPoint("TOPLEFT", centerFramesTitle, "BOTTOMLEFT", 0, -10)
    centerPartyCheckbox.Text:SetText("Center party frames")
    centerPartyCheckbox:SetChecked(addon.db.centerPartyFramesEnabled)
    centerPartyCheckbox:SetScript("OnClick", function(self)
        addon.db.centerPartyFramesEnabled = self:GetChecked()
        addon:SetPartyFrameCenteringEnabled(addon.db.centerPartyFramesEnabled)
    end)

    local centerRaidCheckbox = CreateFrame("CheckButton", nil, centerFramesGroup, "InterfaceOptionsCheckButtonTemplate")
    centerRaidCheckbox:SetPoint("TOPLEFT", centerPartyCheckbox, "BOTTOMLEFT", 0, -6)
    centerRaidCheckbox.Text:SetText("Center raid frames")
    centerRaidCheckbox:SetChecked(addon.db.centerRaidFramesEnabled)
    centerRaidCheckbox:SetScript("OnClick", function(self)
        addon.db.centerRaidFramesEnabled = self:GetChecked()
        addon:SetRaidFrameCenteringEnabled(addon.db.centerRaidFramesEnabled)
    end)

    local centerFramesDebugCheckbox = CreateFrame("CheckButton", nil, centerFramesGroup, "InterfaceOptionsCheckButtonTemplate")
    centerFramesDebugCheckbox:SetPoint("LEFT", centerPartyCheckbox, "RIGHT", 220, 0)
    centerFramesDebugCheckbox.Text:SetText("Debug logging")
    centerFramesDebugCheckbox:SetChecked(addon.db.centerFramesDebug)
    centerFramesDebugCheckbox:SetScript("OnClick", function(self)
        addon.db.centerFramesDebug = self:GetChecked()
    end)


    -- Top Center Widget Offset
    local topCenterWidgetGroup, topCenterWidgetTitle = CreateSection(tabFrameAdjustments, "Top Center Widget Offset", "Move UIWidgetTopCenterContainerFrame downward on the screen.", 100)

    local topCenterWidgetSlider = CreateFrame("Slider", nil, topCenterWidgetGroup, "OptionsSliderTemplate")
    topCenterWidgetSlider:SetPoint("TOPLEFT", topCenterWidgetTitle, "BOTTOMLEFT", 0, -28)
    topCenterWidgetSlider:SetMinMaxValues(0, 100)
    topCenterWidgetSlider:SetValue(addon.db.topCenterWidgetOffset or 0)
    topCenterWidgetSlider:SetValueStep(1)
    topCenterWidgetSlider:SetObeyStepOnDrag(true)
    topCenterWidgetSlider:SetWidth(400)
    topCenterWidgetSlider.Low:SetText("0")
    topCenterWidgetSlider.High:SetText("100")
    topCenterWidgetSlider.Text:SetText(string.format("Offset: %d", addon.db.topCenterWidgetOffset or 0))
    topCenterWidgetSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        self.Text:SetText(string.format("Offset: %d", value))
        addon.db.topCenterWidgetOffset = value
        addon:ApplyTopCenterWidgetOffset(value)
    end)

    -- ====================
    -- CHAT TAB
    -- ====================
    local chatPanel, chatTitle = CreateSection(tabChat, "Chat Entry Box", "Customize the position and appearance of the chat input box.", 264)

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

    -- Extend the main chat frame over the strip the entry box used to occupy
    local extendChatPane = CreateFrame("CheckButton", nil, chatPanel, "InterfaceOptionsCheckButtonTemplate")
    extendChatPane:SetPoint("TOPLEFT", anchorLabel, "BOTTOMLEFT", -6, -44) -- -6 lines it up with the checkboxes above
    extendChatPane.Text:SetText("Extend Default Chat Pane (fills the space left for the chat entry box)")
    extendChatPane:SetChecked(addon.db.extendDefaultChatPane)
    extendChatPane:SetScript("OnClick", function(self)
        addon.db.extendDefaultChatPane = self:GetChecked()
        addon:UpdateChatPaneExtend()
    end)
    if not addon:IsFeatureSupported("chatPaneExtend") then
        -- Last row of the section, so the section just gets shorter
        extendChatPane:Hide()
        chatPanel:SetHeight(chatPanel:GetHeight() - 34)
        tabChat.totalHeight = tabChat.totalHeight - 34
    end

    -- Chat Frame Button Background
    local chatButtonBG, chatButtonTitle = CreateSection(tabChat, "Chat Frame Buttons", "Hide the minimize button, background and borders on chat frames.", 200)
    
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

    local chatButtonsOnRight = CreateFrame("CheckButton", nil, chatButtonBG, "InterfaceOptionsCheckButtonTemplate")
    chatButtonsOnRight:SetPoint("TOPLEFT", hideQuickJoinButton, "BOTTOMLEFT", 0, -4)
    chatButtonsOnRight.Text:SetText("Move Buttons to Right Side of Chat")
    chatButtonsOnRight:SetChecked(addon.db.chatButtonsOnRight)
    chatButtonsOnRight:SetScript("OnClick", function(self)
        addon.db.chatButtonsOnRight = self:GetChecked()
        addon:ApplyTweaks()
    end)
    if not addon:IsFeatureSupported("chatButtonSide") then
        -- Last row of the section, so the section just gets shorter
        chatButtonsOnRight:Hide()
        chatButtonBG:SetHeight(chatButtonBG:GetHeight() - 30)
        tabChat.totalHeight = tabChat.totalHeight - 30
    end

    -- Chat Tabs
    local chatTabsGroup, chatTabsTitle = CreateSection(tabChat, "Chat Tabs", "Control visibility of the tabs above chat frames.", 110)

    local hideChatTabs = CreateFrame("CheckButton", nil, chatTabsGroup, "InterfaceOptionsCheckButtonTemplate")
    hideChatTabs:SetPoint("TOPLEFT", chatTabsTitle, "BOTTOMLEFT", 0, -10)
    hideChatTabs.Text:SetText("Hide Chat Tabs")
    hideChatTabs:SetChecked(addon.db.hideChatTabs)

    local showChatTabsOnHover = CreateFrame("CheckButton", nil, chatTabsGroup, "InterfaceOptionsCheckButtonTemplate")
    showChatTabsOnHover:SetPoint("TOPLEFT", hideChatTabs, "BOTTOMLEFT", 16, -6)
    showChatTabsOnHover.Text:SetText("Show Chat Tabs on Hover")
    showChatTabsOnHover:SetChecked(addon.db.showChatTabsOnHover)
    showChatTabsOnHover:SetScript("OnClick", function(self)
        addon.db.showChatTabsOnHover = self:GetChecked()
        addon:ApplyTweaks()
    end)

    local function UpdateChatTabHoverControl()
        if addon.db.hideChatTabs then
            showChatTabsOnHover:Enable()
            showChatTabsOnHover.Text:SetTextColor(1, 1, 1)
        else
            showChatTabsOnHover:Disable()
            showChatTabsOnHover.Text:SetTextColor(0.5, 0.5, 0.5)
        end
    end
    UpdateChatTabHoverControl()

    hideChatTabs:SetScript("OnClick", function(self)
        addon.db.hideChatTabs = self:GetChecked()
        UpdateChatTabHoverControl()
        addon:ApplyTweaks()
    end)


    -- ====================
    -- SPEED PANEL TAB
    -- ====================
    local speedPanel, speedTitle = CreateSection(tabSpeed, "Speed Panel", "Displays your current movement speed.", 185)
    
    local speedCheckbox = CreateFrame("CheckButton", nil, speedPanel, "InterfaceOptionsCheckButtonTemplate")
    speedCheckbox:SetPoint("TOPLEFT", speedTitle, "BOTTOMLEFT", 0, -12)
    speedCheckbox.Text:SetText("Enable Speed Panel")
    speedCheckbox:SetChecked(addon.db.speedPanelEnabled)

    local lockCheckbox = CreateFrame("CheckButton", nil, speedPanel, "InterfaceOptionsCheckButtonTemplate")
    lockCheckbox:SetPoint("TOPLEFT", speedCheckbox, "BOTTOMLEFT", 0, -12)
    lockCheckbox.Text:SetText("Lock Panel Position")
    lockCheckbox:SetChecked(addon.db.speedPanelLocked)

    local resetButton = CreateFrame("Button", nil, speedPanel, "UIPanelButtonTemplate")
    resetButton:SetPoint("TOPLEFT", lockCheckbox, "BOTTOMLEFT", 0, -16)
    resetButton:SetSize(120, 22)
    resetButton:SetText("Reset Position")
    
    local speedInfo = speedPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    speedInfo:SetPoint("TOPLEFT", resetButton, "BOTTOMLEFT", 0, -16)
    speedInfo:SetWidth(300)
    speedInfo:SetJustifyH("LEFT")
    speedInfo:SetText("Drag the panel to move it when unlocked.")

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
        addon:RefreshSpeedPanelLock()
    end)

    resetButton:SetScript("OnClick", function() addon:ResetSpeedPanelPosition() end)
    UpdateSpeedControls()

    -------------------------------------------------------
    -- Background Panel Tab
    -------------------------------------------------------
    local bgPanel = CreateSection(tabBackground, "Background Panel", "Configure the global background panel.", 470)

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

    -- Force Screen Height
    local chkBGForceH = CreateFrame("CheckButton", nil, bgPanel, "InterfaceOptionsCheckButtonTemplate")
    chkBGForceH:SetPoint("TOPLEFT", chkBGForce, "BOTTOMLEFT", 0, -8)
    chkBGForceH.Text:SetText("Force Screen Height")
    chkBGForceH:SetChecked(addon.db.backgroundPanelForceHeight)

    -- Color Picker
    local lblBGColor = bgPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    lblBGColor:SetPoint("TOPLEFT", chkBGForceH, "BOTTOMLEFT", 0, -20)
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

    -- Shared setter for edit boxes and sliders; refreshes every dimension control
    local function SetBGDimension(key, value)
        value = math.max(16, math.floor((tonumber(value) or 0) + 0.5))
        if addon.db[key] == value then return end
        addon.db[key] = value
        addon:UpdateBackgroundPanel()
        addon:RefreshSettings("background")
    end

    local function CreateDimensionEdit(key)
        local edit = CreateFrame("EditBox", nil, bgPanel, "InputBoxTemplate")
        edit:SetSize(60, 20)
        edit:SetAutoFocus(false)
        edit:SetNumeric(true)
        edit:SetScript("OnEnterPressed", function(self)
            local value = self:GetNumber()
            self:ClearFocus()
            SetBGDimension(key, value)
        end)
        edit:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
            addon:RefreshSettings("background")
        end)
        edit:SetScript("OnEditFocusLost", function()
            addon:RefreshSettings("background")
        end)
        return edit
    end

    local editWidth = CreateDimensionEdit("backgroundPanelWidth")
    editWidth:SetPoint("LEFT", lblDimensions, "RIGHT", 10, 0)

    local lblX = bgPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    lblX:SetPoint("LEFT", editWidth, "RIGHT", 5, 0)
    lblX:SetText("x")

    local editHeight = CreateDimensionEdit("backgroundPanelHeight")
    editHeight:SetPoint("LEFT", lblX, "RIGHT", 5, 0)

    -- Width / Height Sliders (max is the screen size)
    local bgRefreshing = false
    local function CreateDimensionSlider(key, label, anchorTo)
        local slider = CreateFrame("Slider", nil, bgPanel, "OptionsSliderTemplate")
        slider:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, -30)
        slider:SetWidth(300)
        slider:SetValueStep(1)
        slider:SetObeyStepOnDrag(true)
        slider.Low:SetText("16")
        slider.label = label
        slider:SetScript("OnValueChanged", function(self, value)
            self.Text:SetText(string.format("%s: %d", label, math.floor(value + 0.5)))
            if not bgRefreshing then
                SetBGDimension(key, value)
            end
        end)
        return slider
    end

    local sliderWidth = CreateDimensionSlider("backgroundPanelWidth", "Width", lblDimensions)
    local sliderHeight = CreateDimensionSlider("backgroundPanelHeight", "Height", sliderWidth)

    -- Anchor Dropdown
    local lblAnchor = bgPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    lblAnchor:SetPoint("TOPLEFT", sliderHeight, "BOTTOMLEFT", 0, -24)
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
        addon.db.backgroundPanelForceHeight = false

        -- Update UI
        addon:UpdateBackgroundPanel()
        addon:RefreshSettings("background")
    end)

    local function SetDimensionControlEnabled(edit, slider, enabled)
        edit:SetEnabled(enabled)
        edit:SetTextColor(enabled and 1 or 0.5, enabled and 1 or 0.5, enabled and 1 or 0.5)
        slider:SetEnabled(enabled)
        slider:SetAlpha(enabled and 1 or 0.5)
    end

    -- Listener for external updates (e.g. drag resizing)
    function addon:RefreshSettings(module)
        if module ~= "background" or not editWidth:IsVisible() then return end
        local db = addon.db

        -- Always show the panel's real size (screen size when forced)
        local w, h = addon:GetBackgroundPanelSize()
        local bgFrame = addon.backgroundPanel
        if bgFrame and bgFrame.dragRect then
            w, h = bgFrame.dragRect[3], bgFrame.dragRect[4]
        end
        w, h = math.floor(w + 0.5), math.floor(h + 0.5)
        local sw, sh = math.floor(GetScreenWidth() + 0.5), math.floor(GetScreenHeight() + 0.5)

        if not editWidth:HasFocus() then editWidth:SetNumber(w) end
        if not editHeight:HasFocus() then editHeight:SetNumber(h) end

        bgRefreshing = true
        sliderWidth:SetMinMaxValues(16, math.max(sw, w))
        sliderWidth.High:SetText(sw)
        sliderWidth:SetValue(w)
        sliderHeight:SetMinMaxValues(16, math.max(sh, h))
        sliderHeight.High:SetText(sh)
        sliderHeight:SetValue(h)
        bgRefreshing = false

        SetDimensionControlEnabled(editWidth, sliderWidth, not db.backgroundPanelForceWidth)
        SetDimensionControlEnabled(editHeight, sliderHeight, not db.backgroundPanelForceHeight)

        chkBGEnable:SetChecked(db.backgroundPanelEnabled)
        chkBGLock:SetChecked(db.backgroundPanelLocked)
        chkBGForce:SetChecked(db.backgroundPanelForceWidth)
        chkBGForceH:SetChecked(db.backgroundPanelForceHeight)

        UIDropDownMenu_SetSelectedValue(dropAnchor, db.backgroundPanelAnchor)
        UIDropDownMenu_SetText(dropAnchor, db.backgroundPanelAnchor)
    end

    chkBGForce:SetScript("OnClick", function(self)
        addon.db.backgroundPanelForceWidth = self:GetChecked()
        addon:UpdateBackgroundPanel()
        addon:RefreshSettings("background")
    end)

    chkBGForceH:SetScript("OnClick", function(self)
        addon.db.backgroundPanelForceHeight = self:GetChecked()
        addon:UpdateBackgroundPanel()
        addon:RefreshSettings("background")
    end)


    -- ====================
    -- NAMEPLATE TAB CONTENT
    -- ====================
    local npFriendlyPanel, npFriendlyTitle = CreateSection(tabNameplates, "Friendly Simplified Names", "Render readable names above simplified friendly player nameplates.", 590)

    -- Every control in this section shares the title's left edge. Dropdowns are pulled
    -- 16px left because the template pads its visible box by that much.
    local npFriendlyEnabled = CreateFrame("CheckButton", nil, npFriendlyPanel, "InterfaceOptionsCheckButtonTemplate")
    npFriendlyEnabled:SetPoint("TOPLEFT", npFriendlyTitle, "BOTTOMLEFT", 0, -12)
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

    local npFriendlyShowGuild = CreateFrame("CheckButton", nil, npFriendlyPanel, "InterfaceOptionsCheckButtonTemplate")
    npFriendlyShowGuild:SetPoint("TOPLEFT", npFriendlyShowTitle, "BOTTOMLEFT", 0, -4)
    npFriendlyShowGuild.Text:SetText("Show Guild Name")
    npFriendlyShowGuild:SetChecked(addon.db.nameplateFriendlyNamesShowGuild == true)
    npFriendlyShowGuild:SetScript("OnClick", function(self)
        addon.db.nameplateFriendlyNamesShowGuild = self:GetChecked()
        addon:UpdateFriendlyNameplates()
    end)

    local npClassColor = CreateFrame("CheckButton", nil, npFriendlyPanel, "InterfaceOptionsCheckButtonTemplate")
    npClassColor:SetPoint("TOPLEFT", npFriendlyShowGuild, "BOTTOMLEFT", 0, -4)
    npClassColor.Text:SetText("Use Class Colors on Friendly Names")
    npClassColor:SetChecked(addon.db.nameplateUseClassColorForFriendlyPlayerUnitNames)
    npClassColor:SetScript("OnClick", function(self)
        addon.db.nameplateUseClassColorForFriendlyPlayerUnitNames = self:GetChecked()
        addon:SetFriendlyClassColorCVar(self:GetChecked())
        addon:UpdateFriendlyNameplates()
    end)

    local npFriendlyScale = CreateFrame("Slider", nil, npFriendlyPanel, "OptionsSliderTemplate")
    npFriendlyScale:SetPoint("TOPLEFT", npClassColor, "BOTTOMLEFT", 0, -28)
    npFriendlyScale:SetWidth(220)
    npFriendlyScale:SetMinMaxValues(0.5, 3.0)
    npFriendlyScale:SetValueStep(0.05)
    npFriendlyScale:SetObeyStepOnDrag(true)
    npFriendlyScale.Low:SetText("50%")
    npFriendlyScale.High:SetText("300%")
    npFriendlyScale:SetValue(addon.db.nameplateFriendlyScale or 1.0)
    npFriendlyScale.Text:SetText(string.format("Friendly Nameplate Scale: %.0f%%", (addon.db.nameplateFriendlyScale or 1.0) * 100))
    npFriendlyScale:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value * 20 + 0.5) / 20
        self.Text:SetText(string.format("Friendly Nameplate Scale: %.0f%%", value * 100))
        addon.db.nameplateFriendlyScale = value
        addon:UpdateFriendlyNameplates()
    end)

    -- Sits between the class colour checkbox and the scale slider; scoped to stay under the local limit
    do
        local npFullInInstances = CreateFrame("CheckButton", nil, npFriendlyPanel, "InterfaceOptionsCheckButtonTemplate")
        npFullInInstances:SetPoint("TOPLEFT", npClassColor, "BOTTOMLEFT", 0, -4)
        npFullInInstances.Text:SetText("Use Default Friendly Nameplates in Instances")
        npFullInInstances:SetChecked(addon.db.nameplateFullFriendlyInInstances == true)
        npFullInInstances:SetScript("OnClick", function(self)
            addon.db.nameplateFullFriendlyInInstances = self:GetChecked()
            addon:UpdateInstanceSimplifiedNameplates()
        end)
        npFullInInstances:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Addons can't draw on friendly nameplates in dungeons, raids and scenarios, so simplified plates show no names there. This turns simplified friendly player nameplates off while you are inside one and back on when you leave.", nil, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        npFullInInstances:SetScript("OnLeave", GameTooltip_Hide)

        if addon:IsFeatureSupported("simplifiedNameplateTypes") then
            npFriendlyScale:SetPoint("TOPLEFT", npFullInInstances, "BOTTOMLEFT", 0, -28)
        else
            npFullInInstances:Hide()
        end
    end

    local fontLabel = npFriendlyPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    fontLabel:SetPoint("TOPLEFT", npFriendlyScale, "BOTTOMLEFT", 0, -24)
    fontLabel:SetText("Font")

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
            if grouped[group] then
                table.sort(grouped[group], function(a, b)
                    return a.name:lower() < b.name:lower()
                end)
            end
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

    -- Typeface dropdown whose entries are each drawn in their own font. getPath returns the
    -- chosen font file (nil shows "Default"); setPath stores a new one.
    local previewFonts = {}
    local previewFontCount = 0
    local function GetPreviewFont(path)
        local font = previewFonts[path]
        if font == nil then
            previewFontCount = previewFontCount + 1
            font = CreateFont("GUIT_FontPreview" .. previewFontCount)
            -- Only an explicit false is a failure; SetFont returns nothing on success here
            if font:SetFont(path, 14, "") == false then
                font = false -- font file missing; fall back to the default menu font
            end
            previewFonts[path] = font
        end
        return font or nil
    end

    local function CreateFontDropdown(parent, globalName, getPath, setPath)
        local dropdown = CreateFrame("Frame", globalName, parent, "UIDropDownMenuTemplate")
        UIDropDownMenu_SetWidth(dropdown, 210)

        function dropdown:Refresh()
            local path = getPath()
            UIDropDownMenu_SetSelectedValue(dropdown, path)
            UIDropDownMenu_SetText(dropdown, path and GetFriendlyFontDisplayName(path) or "Default")
        end

        local function AddFontButton(item, level)
            local info = UIDropDownMenu_CreateInfo()
            info.text = item.name
            info.value = item.path
            info.fontObject = GetPreviewFont(item.path)
            info.checked = (getPath() == item.path)
            info.func = function(btn)
                setPath(btn.value)
                dropdown:Refresh()
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(info, level)
        end

        UIDropDownMenu_Initialize(dropdown, function(self, level)
            local _, grouped, groupOrder = BuildFriendlyFontList()
            local menuList = UIDROPDOWNMENU_MENU_VALUE

            if level == 1 then
                for _, group in ipairs(groupOrder) do
                    if #(grouped[group] or {}) > 0 then
                        local info = UIDropDownMenu_CreateInfo()
                        info.text = group
                        info.hasArrow = true
                        info.notCheckable = true
                        info.value = { kind = "group", group = group }
                        UIDropDownMenu_AddButton(info, level)
                    end
                end
            elseif level == 2 and type(menuList) == "table" and menuList.kind == "group" then
                local fontsInGroup = grouped[menuList.group] or {}
                if #fontsInGroup > 24 then
                    for idx = 1, #fontsInGroup, 24 do
                        local finish = math.min(idx + 23, #fontsInGroup)
                        local info = UIDropDownMenu_CreateInfo()
                        info.text = string.format("%d-%d", idx, finish)
                        info.hasArrow = true
                        info.notCheckable = true
                        info.value = { kind = "page", group = menuList.group, startIndex = idx, endIndex = finish }
                        UIDropDownMenu_AddButton(info, level)
                    end
                else
                    for _, item in ipairs(fontsInGroup) do
                        AddFontButton(item, level)
                    end
                end
            elseif level == 3 and type(menuList) == "table" and menuList.kind == "page" then
                local fontsInGroup = grouped[menuList.group] or {}
                for idx = menuList.startIndex, menuList.endIndex do
                    if fontsInGroup[idx] then
                        AddFontButton(fontsInGroup[idx], level)
                    end
                end
            end
        end)

        dropdown:Refresh()
        return dropdown
    end

    local fontDropdown = CreateFontDropdown(npFriendlyPanel, "GUIT_FriendlyNameFontDropdown",
        function() return addon.db.nameplateFriendlyNameFont or "Fonts\\FRIZQT__.TTF" end,
        function(path)
            addon.db.nameplateFriendlyNameFont = path
            addon:UpdateFriendlyNameplates()
        end)
    fontDropdown:SetPoint("TOPLEFT", fontLabel, "BOTTOMLEFT", -16, -2)

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
    outlineLabel:SetPoint("TOPLEFT", fontLabel, "BOTTOMLEFT", 0, -46)
    outlineLabel:SetText("Outline Type")

    local outlineDropdown = CreateFrame("Frame", "GUIT_FriendlyNameOutlineDropdown", npFriendlyPanel, "UIDropDownMenuTemplate")
    outlineDropdown:SetPoint("TOPLEFT", outlineLabel, "BOTTOMLEFT", -16, -2)
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
    sizeSlider:SetPoint("TOPLEFT", outlineLabel, "BOTTOMLEFT", 0, -62)
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
    justifyDropdown:SetPoint("TOPLEFT", justifyLabel, "BOTTOMLEFT", -16, -2)
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

    -- ====================
    -- COOLDOWN TAB CONTENT
    -- ====================
    -- Lives after the nameplate section to use the font dropdown; scoped to stay under the local limit
    do
        local cdMouseGroup, cdMouseTitle = CreateSection(tabCooldowns, "Cooldown Timer at Mouse", "Shows the time remaining beside the cursor when you press a spell that is still on cooldown.", 380, "cooldownAtMouse")

        local cdMouseCheckbox = CreateFrame("CheckButton", nil, cdMouseGroup, "InterfaceOptionsCheckButtonTemplate")
        cdMouseCheckbox:SetPoint("TOPLEFT", cdMouseTitle, "BOTTOMLEFT", 0, -12)
        cdMouseCheckbox.Text:SetText("Show Cooldown Timer at Mouse")
        cdMouseCheckbox:SetChecked(addon.db.cooldownAtMouseEnabled)

        local cdMouseDurationSlider = CreateFrame("Slider", nil, cdMouseGroup, "OptionsSliderTemplate")
        cdMouseDurationSlider:SetPoint("TOPLEFT", cdMouseCheckbox, "BOTTOMLEFT", 0, -28)
        cdMouseDurationSlider:SetWidth(200)
        cdMouseDurationSlider:SetMinMaxValues(1, 10)
        cdMouseDurationSlider:SetValue(addon.db.cooldownAtMouseDuration or 3.0)
        cdMouseDurationSlider:SetValueStep(0.5)
        cdMouseDurationSlider:SetObeyStepOnDrag(true)
        cdMouseDurationSlider.Low:SetText("1s")
        cdMouseDurationSlider.High:SetText("10s")
        cdMouseDurationSlider.Text:SetText(string.format("Duration: %.1fs", addon.db.cooldownAtMouseDuration or 3.0))

        local cdMouseOffsetSlider = CreateFrame("Slider", nil, cdMouseGroup, "OptionsSliderTemplate")
        cdMouseOffsetSlider:SetPoint("TOPLEFT", cdMouseDurationSlider, "BOTTOMLEFT", 0, -36)
        cdMouseOffsetSlider:SetWidth(300)
        cdMouseOffsetSlider:SetMinMaxValues(0, 300)
        cdMouseOffsetSlider:SetValue(addon.db.cooldownAtMouseOffset or 40)
        cdMouseOffsetSlider:SetValueStep(1)
        cdMouseOffsetSlider:SetObeyStepOnDrag(true)
        cdMouseOffsetSlider.Low:SetText("0")
        cdMouseOffsetSlider.High:SetText("300")
        cdMouseOffsetSlider.Text:SetText(string.format("Offset Distance: %d", addon.db.cooldownAtMouseOffset or 40))
        cdMouseOffsetSlider:SetScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            self.Text:SetText(string.format("Offset Distance: %d", value))
            addon.db.cooldownAtMouseOffset = value
        end)

        local cdMouseAngleSlider = CreateFrame("Slider", nil, cdMouseGroup, "OptionsSliderTemplate")
        cdMouseAngleSlider:SetPoint("TOPLEFT", cdMouseOffsetSlider, "BOTTOMLEFT", 0, -36)
        cdMouseAngleSlider:SetWidth(300)
        cdMouseAngleSlider:SetMinMaxValues(0, 355)
        cdMouseAngleSlider:SetValue(addon.db.cooldownAtMouseAngle or 90)
        cdMouseAngleSlider:SetValueStep(5)
        cdMouseAngleSlider:SetObeyStepOnDrag(true)
        cdMouseAngleSlider.Low:SetText("0 (above)")
        cdMouseAngleSlider.High:SetText("355")
        cdMouseAngleSlider.Text:SetText(string.format("Offset Rotation: %d", addon.db.cooldownAtMouseAngle or 90))
        cdMouseAngleSlider:SetScript("OnValueChanged", function(self, value)
            value = math.floor(value / 5 + 0.5) * 5
            self.Text:SetText(string.format("Offset Rotation: %d", value))
            addon.db.cooldownAtMouseAngle = value
        end)

        cdMouseDurationSlider:SetScript("OnValueChanged", function(self, value)
            value = math.floor(value * 2 + 0.5) / 2
            self.Text:SetText(string.format("Duration: %.1fs", value))
            addon.db.cooldownAtMouseDuration = value
        end)

        local cdMouseSizeSlider = CreateFrame("Slider", nil, cdMouseGroup, "OptionsSliderTemplate")
        cdMouseSizeSlider:SetPoint("TOPLEFT", cdMouseAngleSlider, "BOTTOMLEFT", 0, -36)
        cdMouseSizeSlider:SetWidth(300)
        cdMouseSizeSlider:SetMinMaxValues(8, 72)
        cdMouseSizeSlider:SetValue(addon.db.cooldownAtMouseFontSize or 22)
        cdMouseSizeSlider:SetValueStep(1)
        cdMouseSizeSlider:SetObeyStepOnDrag(true)
        cdMouseSizeSlider.Low:SetText("8")
        cdMouseSizeSlider.High:SetText("72")
        cdMouseSizeSlider.Text:SetText(string.format("Font Size: %d", addon.db.cooldownAtMouseFontSize or 22))
        cdMouseSizeSlider:SetScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            self.Text:SetText(string.format("Font Size: %d", value))
            addon.db.cooldownAtMouseFontSize = value
            addon:UpdateCooldownAtMouseFont()
        end)

        local cdMouseFontLabel = cdMouseGroup:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        cdMouseFontLabel:SetPoint("TOPLEFT", cdMouseSizeSlider, "BOTTOMLEFT", 0, -24)
        cdMouseFontLabel:SetText("Typeface")

        local cdMouseFontDropdown = CreateFontDropdown(cdMouseGroup, "GUIT_CooldownAtMouseFontDropdown",
            function() return addon.db.cooldownAtMouseFont or "Fonts\\FRIZQT__.TTF" end,
            function(path)
                addon.db.cooldownAtMouseFont = path
                addon:UpdateCooldownAtMouseFont()
            end)
        cdMouseFontDropdown:SetPoint("TOPLEFT", cdMouseFontLabel, "BOTTOMLEFT", -16, -2)

        local function UpdateCooldownControls()
            local enabled = addon.db.cooldownAtMouseEnabled
            cdMouseDurationSlider:SetEnabled(enabled)
            cdMouseOffsetSlider:SetEnabled(enabled)
            cdMouseAngleSlider:SetEnabled(enabled)
            cdMouseSizeSlider:SetEnabled(enabled)
            if enabled then
                UIDropDownMenu_EnableDropDown(cdMouseFontDropdown)
            else
                UIDropDownMenu_DisableDropDown(cdMouseFontDropdown)
            end
        end
        UpdateCooldownControls()

        cdMouseCheckbox:SetScript("OnClick", function(self)
            addon.db.cooldownAtMouseEnabled = self:GetChecked()
            addon:SetCooldownAtMouseEnabled(addon.db.cooldownAtMouseEnabled)
            UpdateCooldownControls()
        end)
    end

    -- ====================
    -- CHAT TEXT FONT (Chat tab; down here to use the font dropdown)
    -- ====================
    do
        local chatFontGroup, chatFontTitle = CreateSection(tabChat, "Chat Text Font", "Change the typeface and size of the text in each chat window.", 270)
        local selectedWindow = 1
        local refreshing = false

        local windowLabel = chatFontGroup:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        windowLabel:SetPoint("TOPLEFT", chatFontTitle, "BOTTOMLEFT", 0, -14)
        windowLabel:SetText("Chat Window")

        local windowDropdown = CreateFrame("Frame", "GUIT_ChatFontWindowDropdown", chatFontGroup, "UIDropDownMenuTemplate")
        windowDropdown:SetPoint("TOPLEFT", windowLabel, "BOTTOMLEFT", -16, -2)
        UIDropDownMenu_SetWidth(windowDropdown, 210)

        local fontLabel = chatFontGroup:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        fontLabel:SetPoint("TOPLEFT", windowLabel, "BOTTOMLEFT", 0, -46)
        fontLabel:SetText("Typeface")

        local fontDropdown = CreateFontDropdown(chatFontGroup, "GUIT_ChatFontDropdown",
            function() return addon:GetChatFontOverride(selectedWindow).font end,
            function(path) addon:SetChatFontOverride(selectedWindow, "font", path) end)
        fontDropdown:SetPoint("TOPLEFT", fontLabel, "BOTTOMLEFT", -16, -2)

        local sizeSlider = CreateFrame("Slider", nil, chatFontGroup, "OptionsSliderTemplate")
        sizeSlider:SetPoint("TOPLEFT", fontLabel, "BOTTOMLEFT", 0, -62)
        sizeSlider:SetWidth(300)
        sizeSlider:SetMinMaxValues(8, 32)
        sizeSlider:SetValueStep(1)
        sizeSlider:SetObeyStepOnDrag(true)
        sizeSlider.Low:SetText("8")
        sizeSlider.High:SetText("32")
        sizeSlider:SetScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            self.Text:SetText(string.format("Font Size: %d", value))
            if not refreshing then
                addon:SetChatFontOverride(selectedWindow, "size", value)
            end
        end)

        local resetButton = CreateFrame("Button", nil, chatFontGroup, "UIPanelButtonTemplate")
        resetButton:SetPoint("TOPLEFT", sizeSlider, "BOTTOMLEFT", 0, -26)
        resetButton:SetSize(160, 22)
        resetButton:SetText("Reset This Window")

        -- Shows the selected window's current font and size
        local function RefreshChatFontControls()
            UIDropDownMenu_SetSelectedValue(windowDropdown, selectedWindow)
            UIDropDownMenu_SetText(windowDropdown, addon:GetChatWindowName(selectedWindow))
            fontDropdown:Refresh()

            refreshing = true
            sizeSlider:SetValue(addon:GetChatFontSize(selectedWindow))
            refreshing = false
        end

        -- Built each time it opens, so new and renamed windows are listed
        UIDropDownMenu_Initialize(windowDropdown, function()
            for _, id in ipairs(addon:GetChatWindowIDs()) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = addon:GetChatWindowName(id)
                info.value = id
                info.checked = (id == selectedWindow)
                info.func = function(btn)
                    selectedWindow = btn.value
                    RefreshChatFontControls()
                end
                UIDropDownMenu_AddButton(info)
            end
        end)

        resetButton:SetScript("OnClick", function()
            addon:ResetChatFont(selectedWindow)
            RefreshChatFontControls()
        end)

        chatFontGroup:SetScript("OnShow", RefreshChatFontControls)
        RefreshChatFontControls()
    end

    -- ====================
    -- SPEED PANEL APPEARANCE (Speed tab; down here to use the font dropdown)
    -- ====================
    do
        local speedLookGroup, speedLookTitle = CreateSection(tabSpeed, "Appearance", "Font, colors, background and border of the speed panel.", 460)

        local function Apply()
            addon:ApplySpeedPanelAppearance()
        end

        -- Dropdown over a list of { key = ..., name = ... } options
        local function CreateChoiceDropdown(globalName, options, dbKey, defaultKey)
            local dropdown = CreateFrame("Frame", globalName, speedLookGroup, "UIDropDownMenuTemplate")
            UIDropDownMenu_SetWidth(dropdown, 210)

            local function NameOf(key)
                for _, option in ipairs(options) do
                    if option.key == key then return option.name end
                end
                return key
            end

            UIDropDownMenu_Initialize(dropdown, function()
                local current = addon.db[dbKey] or defaultKey
                for _, option in ipairs(options) do
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = option.name
                    info.value = option.key
                    info.checked = (option.key == current)
                    info.func = function(btn)
                        addon.db[dbKey] = btn.value
                        UIDropDownMenu_SetSelectedValue(dropdown, btn.value)
                        UIDropDownMenu_SetText(dropdown, NameOf(btn.value))
                        Apply()
                    end
                    UIDropDownMenu_AddButton(info)
                end
            end)

            UIDropDownMenu_SetSelectedValue(dropdown, addon.db[dbKey] or defaultKey)
            UIDropDownMenu_SetText(dropdown, NameOf(addon.db[dbKey] or defaultKey))
            return dropdown
        end

        -- A label with a clickable color square that opens the color picker (with opacity)
        local function CreateColorRow(labelText, dbKey, default)
            local row = CreateFrame("Frame", nil, speedLookGroup)
            row:SetSize(260, 20)

            local label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            label:SetPoint("LEFT", row, "LEFT", 0, 0)
            label:SetText(labelText)

            local swatch = CreateFrame("Button", nil, row)
            swatch:SetSize(20, 20)
            swatch:SetPoint("LEFT", label, "RIGHT", 10, 0)
            local border = swatch:CreateTexture(nil, "BACKGROUND")
            border:SetAllPoints()
            border:SetColorTexture(1, 1, 1, 1)
            local fill = swatch:CreateTexture(nil, "ARTWORK")
            fill:SetPoint("TOPLEFT", 1, -1)
            fill:SetPoint("BOTTOMRIGHT", -1, 1)

            local function Get()
                return addon.db[dbKey] or default
            end
            local function Set(r, g, b, a)
                addon.db[dbKey] = { r = r, g = g, b = b, a = a }
                fill:SetColorTexture(r, g, b, 1)
                Apply()
            end
            fill:SetColorTexture(Get().r, Get().g, Get().b, 1)

            swatch:SetScript("OnClick", function()
                if not ColorPickerFrame or not ColorPickerFrame.SetupColorPickerAndShow then
                    return
                end
                local old = Get()
                local function OnChanged()
                    local r, g, b = ColorPickerFrame:GetColorRGB()
                    Set(r, g, b, ColorPickerFrame:GetColorAlpha())
                end
                ColorPickerFrame:SetupColorPickerAndShow({
                    r = old.r, g = old.g, b = old.b, opacity = old.a,
                    hasOpacity = true,
                    swatchFunc = OnChanged,
                    opacityFunc = OnChanged,
                    cancelFunc = function() Set(old.r, old.g, old.b, old.a) end,
                })
            end)

            return row
        end

        local function CreateLabel(text, anchorTo, offsetY)
            local label = speedLookGroup:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            label:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, offsetY)
            label:SetText(text)
            return label
        end

        -- Text
        local fontLabel = CreateLabel("Typeface", speedLookTitle, -14)
        local fontDropdown = CreateFontDropdown(speedLookGroup, "GUIT_SpeedPanelFontDropdown",
            function() return addon.db.speedPanelFont end,
            function(path)
                addon.db.speedPanelFont = path
                Apply()
            end)
        fontDropdown:SetPoint("TOPLEFT", fontLabel, "BOTTOMLEFT", -16, -2)

        local outlineLabel = CreateLabel("Outline", fontLabel, -46)
        local outlineDropdown = CreateChoiceDropdown("GUIT_SpeedPanelOutlineDropdown", addon:GetSpeedPanelOutlineOptions(), "speedPanelFontOutline", "NONE")
        outlineDropdown:SetPoint("TOPLEFT", outlineLabel, "BOTTOMLEFT", -16, -2)

        local sizeSlider = CreateFrame("Slider", nil, speedLookGroup, "OptionsSliderTemplate")
        sizeSlider:SetPoint("TOPLEFT", outlineLabel, "BOTTOMLEFT", 0, -62)
        sizeSlider:SetWidth(300)
        sizeSlider:SetMinMaxValues(8, 40)
        sizeSlider:SetValueStep(1)
        sizeSlider:SetObeyStepOnDrag(true)
        sizeSlider.Low:SetText("8")
        sizeSlider.High:SetText("40")
        sizeSlider:SetValue(addon.db.speedPanelFontSize or 16)
        sizeSlider.Text:SetText(string.format("Font Size: %d", addon.db.speedPanelFontSize or 16))
        sizeSlider:SetScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            self.Text:SetText(string.format("Font Size: %d", value))
            addon.db.speedPanelFontSize = value
            Apply()
        end)

        local textColorRow = CreateColorRow("Text Color", "speedPanelTextColor", { r = 1, g = 1, b = 1, a = 1 })
        textColorRow:SetPoint("TOPLEFT", sizeSlider, "BOTTOMLEFT", 0, -28)

        -- Background
        local backgroundLabel = CreateLabel("Background", textColorRow, -18)
        local backgroundDropdown = CreateChoiceDropdown("GUIT_SpeedPanelBackgroundDropdown", addon:GetSpeedPanelBackgroundOptions(), "speedPanelBackgroundKey", "dialog")
        backgroundDropdown:SetPoint("TOPLEFT", backgroundLabel, "BOTTOMLEFT", -16, -2)

        local backgroundColorRow = CreateColorRow("Background Color / Opacity", "speedPanelBackgroundColor", { r = 0, g = 0, b = 0, a = 0.55 })
        backgroundColorRow:SetPoint("TOPLEFT", backgroundLabel, "BOTTOMLEFT", 0, -46)

        -- Border
        local borderLabel = CreateLabel("Border", backgroundColorRow, -18)
        local borderDropdown = CreateChoiceDropdown("GUIT_SpeedPanelBorderDropdown", addon:GetSpeedPanelBorderOptions(), "speedPanelBorderKey", "tooltip")
        borderDropdown:SetPoint("TOPLEFT", borderLabel, "BOTTOMLEFT", -16, -2)

        local borderColorRow = CreateColorRow("Border Color (shown when locked)", "speedPanelBorderColor", { r = 0.4, g = 0.4, b = 0.4, a = 0.9 })
        borderColorRow:SetPoint("TOPLEFT", borderLabel, "BOTTOMLEFT", 0, -46)
    end

    addon.settingsPanel = panel
    addon.settingsPages = addon.settingsPages or {}
    for _, page in ipairs(orderedPages) do
        addon.settingsPages[page.id] = page
    end

    -- Add to Interface Options as parent + subpages (Macro Toolkit style)
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        addon.settingsCategory = category
        addon.settingsSubcategories = addon.settingsSubcategories or {}

        -- Pages with nothing viable on this client are left out of the list
        for _, page in ipairs(orderedPages) do
            if page.visibleSections > 0 then
                local sub = Settings.RegisterCanvasLayoutSubcategory(category, page.frame, page.name)
                addon.settingsSubcategories[page.id] = sub
            end
        end
    else
        InterfaceOptions_AddCategory(panel)
        for _, page in ipairs(orderedPages) do
            if page.visibleSections > 0 then
                page.frame.parent = panel.name
                page.frame.name = page.name
                InterfaceOptions_AddCategory(page.frame)
            end
        end
    end
end

-- Open settings panel (Helper)
function addon:OpenSettings()
    if not self.settingsPanel then self:CreateSettingsPanel() end

    local defaultPageID = "general"
    local defaultPage = self.settingsPages and self.settingsPages[defaultPageID]

    if Settings and Settings.OpenToCategory then
        local targetCategory = self.settingsSubcategories and self.settingsSubcategories[defaultPageID]
        if not targetCategory then
            targetCategory = self.settingsCategory
        end

        local id = targetCategory and targetCategory:GetID()
        if not id then
            local fallbackCategory = Settings.GetCategory("Garage UI Tweaks")
            id = fallbackCategory and fallbackCategory:GetID() or nil
        end

        if not id then
            return
        end

        Settings.OpenToCategory(id)
    elseif InterfaceOptionsFrame_OpenToCategory then
        local targetPanel = (defaultPage and defaultPage.frame) or self.settingsPanel
        InterfaceOptionsFrame_OpenToCategory(targetPanel)
        InterfaceOptionsFrame_OpenToCategory(targetPanel)
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
