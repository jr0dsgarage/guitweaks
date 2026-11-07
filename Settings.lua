---@diagnostic disable: undefined-global
-- Garage UI Tweaks Settings
local addonName, addon = ...
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
local W = addon.SettingsWidgets

-- Slider with the Settings panel's stepper arrows and a typeable value (see SettingsWidgets.lua).
-- Stores into addon.db[dbKey] and then runs apply(value), if given.
local function CreateDBSlider(parent, label, dbKey, default, minVal, maxVal, step, width, decimals, scale, apply)
    return W.CreateSlider(parent, {
        label = label, min = minVal, max = maxVal, step = step, width = width,
        decimals = decimals, scale = scale,
        value = addon.db[dbKey] or default,
        onChange = function(value)
            addon.db[dbKey] = value
            if apply then apply(value) end
        end,
    })
end

-- Dropdown over { text, value } choices, stored in addon.db[dbKey].
local function CreateDBChoiceDropdown(parent, width, options, dbKey, default, apply)
    return W.CreateChoiceDropdown(parent, width, options,
        function() return addon.db[dbKey] or default end,
        function(value)
            addon.db[dbKey] = value
            if apply then apply(value) end
        end)
end

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
    local enabledCheckbox = W.CreateCheckbox(panel)
    enabledCheckbox:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -12)
    W.AttachHover(enabledCheckbox)
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

        local scrollFrame = W.CreateScrollFrame(page)
        scrollFrame:SetPoint("TOPLEFT", descText, "BOTTOMLEFT", 0, -12)
        scrollFrame:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -20, 12)

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
    local errorBG, errorTitle = CreateSection(tabGeneral, "Error Text Background", "Draws a backdrop behind UI errors briefly to improve visibility.", 174)
    
    local errorCheckbox = W.CreateCheckbox(errorBG)
    errorCheckbox:SetPoint("TOPLEFT", errorTitle, "BOTTOMLEFT", 0, -12)
    W.AttachHover(errorCheckbox, { body = "Draws a dark backdrop behind the red error messages at the top of the screen, such as \"Not enough rage\", so they're easier to read." })
    errorCheckbox.Text:SetText("Enable Background")
    errorCheckbox:SetChecked(addon.db.errorTextBackgroundEnabled)

    local function ApplyErrorBackground()
        addon:SetErrorTextBackground(addon.db.errorTextBackgroundEnabled, addon.db.errorTextBackgroundAlpha, addon.db.errorTextBackgroundDuration)
    end

    local alphaSlider = CreateDBSlider(errorBG, "Opacity (%)", "errorTextBackgroundAlpha", 0.7, 0, 1, 0.05, 220, 0, 100, ApplyErrorBackground)
    alphaSlider:SetPoint("TOPLEFT", errorCheckbox, "BOTTOMLEFT", 0, -28)
    W.AttachHover(alphaSlider, { body = "How solid the backdrop behind error messages is." })

    local durationSlider = CreateDBSlider(errorBG, "Duration (s)", "errorTextBackgroundDuration", 3.0, 1, 5, 0.1, 200, 1, nil, ApplyErrorBackground)
    durationSlider:SetPoint("TOPLEFT", alphaSlider, "BOTTOMLEFT", 0, -32)
    W.AttachHover(durationSlider, { body = "How long the backdrop stays after an error message appears, in seconds." })

    errorCheckbox:SetScript("OnClick", function(self)
        addon.db.errorTextBackgroundEnabled = self:GetChecked()
        ApplyErrorBackground()
        alphaSlider:SetEnabled(addon.db.errorTextBackgroundEnabled)
        durationSlider:SetEnabled(addon.db.errorTextBackgroundEnabled)
    end)


    -- Override Action Bar
    local overrideBarGroup, overrideBarTitle = CreateSection(tabGeneral, "Override Action Bar", "Adjust the position of the Vehicle/Override Action Bar.", 100)

    local overrideYSlider = CreateDBSlider(overrideBarGroup, "Y Offset", "overrideActionBarYOffset", 0, 0, 300, 1, 340, 0, nil,
        function() addon:UpdateOverrideActionBar() end)
    overrideYSlider:SetPoint("TOPLEFT", overrideBarTitle, "BOTTOMLEFT", 0, -28)
    W.AttachHover(overrideYSlider, { body = "Raises the vehicle / override action bar this many pixels above the bottom of the screen." })

    -- Encounter Bar Prey %
    local encounterBarGroup, encounterBarTitle = CreateSection(tabGeneral, "Encounter Bar", "Show the prey's health percentage on the encounter bar when hunting prey in outdoor zones.", 80, "preyPercent")

    local encounterPercentCheck = W.CreateCheckbox(encounterBarGroup)
    encounterPercentCheck:SetPoint("TOPLEFT", encounterBarTitle, "BOTTOMLEFT", 0, -10)
    W.AttachHover(encounterPercentCheck, { body = "While hunting prey outdoors, shows the prey's remaining health as a percentage on the encounter bar." })
    encounterPercentCheck.Text:SetText("Show prey encounter percentage")
    encounterPercentCheck:SetChecked(addon.db.encounterBarPreyPercentEnabled)
    encounterPercentCheck:SetScript("OnClick", function(self)
        addon.db.encounterBarPreyPercentEnabled = self:GetChecked()
        addon:InitEncounterBarPreyPercent()
    end)

    -- Armor Set Action Highlights
    local armorSetHighlightGroup, armorSetHighlightTitle = CreateSection(tabGeneral, "Armor Set Action Highlights", "Outline action buttons that trigger your currently equipped armor set.", 80, "armorSetHighlight")

    local armorSetHighlightCheck = W.CreateCheckbox(armorSetHighlightGroup)
    armorSetHighlightCheck:SetPoint("TOPLEFT", armorSetHighlightTitle, "BOTTOMLEFT", 0, -10)
    W.AttachHover(armorSetHighlightCheck, { body = "Outlines action buttons that trigger your currently equipped armor set, in the same style as the assisted combat highlight." })
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

    local microMenuArtCheck = W.CreateCheckbox(microMenuGroup)
    microMenuArtCheck:SetPoint("TOPLEFT", microMenuTitle, "BOTTOMLEFT", 0, -10)
    W.AttachHover(microMenuArtCheck, { body = "Hides the background art behind the micro menu buttons." })
    microMenuArtCheck.Text:SetText("Hide micro menu background art")
    microMenuArtCheck:SetChecked(addon.db.hideMicroMenuBackgroundArt)
    microMenuArtCheck:SetScript("OnClick", function(self)
        addon.db.hideMicroMenuBackgroundArt = self:GetChecked()
        addon:UpdateMicroMenuArt()
    end)

    local microMenuBorderCheck = W.CreateCheckbox(microMenuGroup)
    microMenuBorderCheck:SetPoint("TOPLEFT", microMenuArtCheck, "BOTTOMLEFT", 0, -6)
    W.AttachHover(microMenuBorderCheck, { body = "Hides the border art around the micro menu." })
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
    
    local scaleSlider = CreateDBSlider(bgMapScale, "Scale (%)", "battlegroundMapScale", 1.0, 0.5, 2.0, 0.1, 200, 0, 100,
        function() addon:ApplyTweaks() end)
    scaleSlider:SetPoint("TOPLEFT", bgMapTitle, "BOTTOMLEFT", 0, -28)
    W.AttachHover(scaleSlider, { body = "Size of the battlefield map (Shift+M), where 100% is its normal size." })

    local mapLowestStrataCheckbox = W.CreateCheckbox(bgMapScale)
    mapLowestStrataCheckbox:SetPoint("TOPLEFT", scaleSlider, "BOTTOMLEFT", 0, -10)
    W.AttachHover(mapLowestStrataCheckbox, { body = "Draws the battlefield map beneath other frames, so it never covers them." })
    mapLowestStrataCheckbox.Text:SetText("Force map to lowest strata")
    mapLowestStrataCheckbox:SetChecked(addon.db.battlegroundMapForceLowestStrata)
    mapLowestStrataCheckbox:SetScript("OnClick", function(self)
        addon.db.battlegroundMapForceLowestStrata = self:GetChecked()
        addon:ApplyTweaks()
    end)

    -- Experience Bars
    local expBarStrataGroup, expBarStrataTitle = CreateSection(tabFrameAdjustments, "Experience Bars", "Adjust strata behavior for XP/reputation/honor tracking bars.", 80)

    local expBarHighestStrataCheckbox = W.CreateCheckbox(expBarStrataGroup)
    expBarHighestStrataCheckbox:SetPoint("TOPLEFT", expBarStrataTitle, "BOTTOMLEFT", 0, -10)
    W.AttachHover(expBarHighestStrataCheckbox, { body = "Draws the experience, reputation and honor bars above other frames, so nothing covers them." })
    expBarHighestStrataCheckbox.Text:SetText("Force experience bars to highest strata")
    expBarHighestStrataCheckbox:SetChecked(addon.db.experienceBarsForceHighestStrata)
    expBarHighestStrataCheckbox:SetScript("OnClick", function(self)
        addon.db.experienceBarsForceHighestStrata = self:GetChecked()
        addon:ApplyTweaks()
    end)

    -- Center Raid/Party Frames
    local centerFramesGroup, centerFramesTitle = CreateSection(tabFrameAdjustments, "Raid & Party Frames", "Keep party and raid frame groups centered as they resize.", 110)

    local centerPartyCheckbox = W.CreateCheckbox(centerFramesGroup)
    centerPartyCheckbox:SetPoint("TOPLEFT", centerFramesTitle, "BOTTOMLEFT", 0, -10)
    W.AttachHover(centerPartyCheckbox, { right = centerPartyCheckbox.Text, body = "Keeps the party frames centered on their position as members join and leave." })
    centerPartyCheckbox.Text:SetText("Center party frames")
    centerPartyCheckbox:SetChecked(addon.db.centerPartyFramesEnabled)
    centerPartyCheckbox:SetScript("OnClick", function(self)
        addon.db.centerPartyFramesEnabled = self:GetChecked()
        addon:SetPartyFrameCenteringEnabled(addon.db.centerPartyFramesEnabled)
    end)

    local centerRaidCheckbox = W.CreateCheckbox(centerFramesGroup)
    centerRaidCheckbox:SetPoint("TOPLEFT", centerPartyCheckbox, "BOTTOMLEFT", 0, -6)
    W.AttachHover(centerRaidCheckbox, { body = "Keeps the raid frame groups centered as the raid grows and shrinks." })
    centerRaidCheckbox.Text:SetText("Center raid frames")
    centerRaidCheckbox:SetChecked(addon.db.centerRaidFramesEnabled)
    centerRaidCheckbox:SetScript("OnClick", function(self)
        addon.db.centerRaidFramesEnabled = self:GetChecked()
        addon:SetRaidFrameCenteringEnabled(addon.db.centerRaidFramesEnabled)
    end)

    local centerFramesDebugCheckbox = W.CreateCheckbox(centerFramesGroup)
    centerFramesDebugCheckbox:SetPoint("LEFT", centerPartyCheckbox, "RIGHT", 220, 0)
    W.AttachHover(centerFramesDebugCheckbox, { left = centerFramesDebugCheckbox, body = "Prints a message to chat each time the party or raid frames are re-centered, for troubleshooting." })
    centerFramesDebugCheckbox.Text:SetText("Debug logging")
    centerFramesDebugCheckbox:SetChecked(addon.db.centerFramesDebug)
    centerFramesDebugCheckbox:SetScript("OnClick", function(self)
        addon.db.centerFramesDebug = self:GetChecked()
    end)


    -- Top Center Widget Offset
    local topCenterWidgetGroup, topCenterWidgetTitle = CreateSection(tabFrameAdjustments, "Top Center Widget Offset", "Move UIWidgetTopCenterContainerFrame downward on the screen.", 100)

    local topCenterWidgetSlider = CreateDBSlider(topCenterWidgetGroup, "Offset", "topCenterWidgetOffset", 0, 0, 100, 1, 340, 0, nil,
        function(value) addon:ApplyTopCenterWidgetOffset(value) end)
    topCenterWidgetSlider:SetPoint("TOPLEFT", topCenterWidgetTitle, "BOTTOMLEFT", 0, -28)
    W.AttachHover(topCenterWidgetSlider, { body = "Moves the widgets at the top center of the screen, such as battleground scores and zone objectives, down by this many pixels." })

    -- ====================
    -- CHAT TAB
    -- ====================
    local chatPanel, chatTitle = CreateSection(tabChat, "Chat Entry Box", "Customize the position and appearance of the chat input box.", 264)

    -- Unlock / Drag
    local chatUnlock = W.CreateCheckbox(chatPanel)
    chatUnlock:SetPoint("TOPLEFT", chatTitle, "BOTTOMLEFT", 0, -12)
    W.AttachHover(chatUnlock, { body = "Lets you move the chat entry box: hold Shift and drag it." })
    chatUnlock.Text:SetText("Unlock Chat Entry Box (Hold SHIFT to Drag)")
    chatUnlock:SetChecked(addon.db.chatEditBoxUnlock)
    chatUnlock:SetScript("OnClick", function(self)
        addon.db.chatEditBoxUnlock = self:GetChecked()
        addon:SetChatEditBoxUnlock(addon.db.chatEditBoxUnlock)
    end)

    -- Disable Borders
    local borderCheckbox = W.CreateCheckbox(chatPanel)
    borderCheckbox:SetPoint("TOPLEFT", chatUnlock, "BOTTOMLEFT", 0, -12)
    W.AttachHover(borderCheckbox, { body = "Hides the default border textures around the chat entry box." })
    borderCheckbox.Text:SetText("Hide Default Borders")
    borderCheckbox:SetChecked(addon.db.chatEditBoxHideBorder)
    borderCheckbox:SetScript("OnClick", function(self)
        addon.db.chatEditBoxHideBorder = self:GetChecked()
        addon:UpdateChatEditBox()
    end)
    
    -- Width Slider
    local widthSlider = CreateDBSlider(chatPanel, "Width", "chatEditBoxWidth", 450, 200, 1000, 10, 340, 0, nil,
        function() addon:UpdateChatEditBox() end)
    widthSlider:SetPoint("TOPLEFT", borderCheckbox, "BOTTOMLEFT", 6, -30)
    W.AttachHover(widthSlider, { body = "Width of the chat entry box, in pixels." })

    -- Anchor Dropdown
    local anchorLabel = chatPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    anchorLabel:SetPoint("TOPLEFT", widthSlider, "BOTTOMLEFT", 0, -20)
    anchorLabel:SetText("Resize Anchor (Determines growth direction):")

    local anchorDropdown = CreateDBChoiceDropdown(chatPanel, 120, {
        { text = "LEFT", value = "LEFT" },
        { text = "CENTER", value = "CENTER" },
        { text = "RIGHT", value = "RIGHT" },
    }, "chatEditBoxAnchor", "CENTER", function() addon:UpdateChatEditBox() end)
    anchorDropdown:SetPoint("TOPLEFT", anchorLabel, "BOTTOMLEFT", 0, -5)
    W.AttachHover(anchorDropdown, { top = anchorLabel, body = "Which part of the chat entry box stays in place when its width changes: Left grows it to the right, Right grows it to the left, and Center grows it both ways." })

    -- Extend the main chat frame over the strip the entry box used to occupy
    local extendChatPane = W.CreateCheckbox(chatPanel)
    extendChatPane:SetPoint("TOPLEFT", anchorLabel, "BOTTOMLEFT", -6, -44) -- -6 lines it up with the checkboxes above
    W.AttachHover(extendChatPane, { body = "Stretches the main chat window down over the strip the game keeps free for the chat entry box." })
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
    
    local hideChatButtonBG = W.CreateCheckbox(chatButtonBG)
    hideChatButtonBG:SetPoint("TOPLEFT", chatButtonTitle, "BOTTOMLEFT", 0, -12)
    W.AttachHover(hideChatButtonBG, { body = "Hides the background and border behind the buttons beside the chat window, and the minimize button." })
    hideChatButtonBG.Text:SetText("Hide Button Background, Border & Minimize")
    hideChatButtonBG:SetChecked(addon.db.hideChatButtonFrameBackground)
    hideChatButtonBG:SetScript("OnClick", function(self)
        addon.db.hideChatButtonFrameBackground = self:GetChecked()
        addon:ApplyTweaks()
    end)

    local hideMenuButton = W.CreateCheckbox(chatButtonBG)
    hideMenuButton:SetPoint("TOPLEFT", hideChatButtonBG, "BOTTOMLEFT", 0, -4)
    W.AttachHover(hideMenuButton, { body = "Hides the chat menu button beside the chat window." })
    hideMenuButton.Text:SetText("Hide Chat Menu Button")
    hideMenuButton:SetChecked(addon.db.hideChatFrameMenuButton)
    hideMenuButton:SetScript("OnClick", function(self)
        addon.db.hideChatFrameMenuButton = self:GetChecked()
        addon:ApplyTweaks()
    end)

    local hideChannelButton = W.CreateCheckbox(chatButtonBG)
    hideChannelButton:SetPoint("TOPLEFT", hideMenuButton, "BOTTOMLEFT", 0, -4)
    W.AttachHover(hideChannelButton, { body = "Hides the chat channels button beside the chat window." })
    hideChannelButton.Text:SetText("Hide Chat Channel Button")
    hideChannelButton:SetChecked(addon.db.hideChatFrameChannelButton)
    hideChannelButton:SetScript("OnClick", function(self)
        addon.db.hideChatFrameChannelButton = self:GetChecked()
        addon:ApplyTweaks()
    end)

    local hideQuickJoinButton = W.CreateCheckbox(chatButtonBG)
    hideQuickJoinButton:SetPoint("TOPLEFT", hideChannelButton, "BOTTOMLEFT", 0, -4)
    W.AttachHover(hideQuickJoinButton, { body = "Hides the social (Quick Join) button beside the chat window." })
    hideQuickJoinButton.Text:SetText("Hide Social Button (Quick Join)")
    hideQuickJoinButton:SetChecked(addon.db.hideQuickJoinToastButton)
    hideQuickJoinButton:SetScript("OnClick", function(self)
        addon.db.hideQuickJoinToastButton = self:GetChecked()
        addon:ApplyTweaks()
    end)

    local chatButtonsOnRight = W.CreateCheckbox(chatButtonBG)
    chatButtonsOnRight:SetPoint("TOPLEFT", hideQuickJoinButton, "BOTTOMLEFT", 0, -4)
    W.AttachHover(chatButtonsOnRight, { body = "Moves the chat window's buttons to its right side." })
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

    local hideChatTabs = W.CreateCheckbox(chatTabsGroup)
    hideChatTabs:SetPoint("TOPLEFT", chatTabsTitle, "BOTTOMLEFT", 0, -10)
    W.AttachHover(hideChatTabs, { body = "Hides the tabs above each chat window." })
    hideChatTabs.Text:SetText("Hide Chat Tabs")
    hideChatTabs:SetChecked(addon.db.hideChatTabs)

    local showChatTabsOnHover = W.CreateCheckbox(chatTabsGroup)
    showChatTabsOnHover:SetPoint("TOPLEFT", hideChatTabs, "BOTTOMLEFT", 16, -6)
    W.AttachHover(showChatTabsOnHover, { body = "While chat tabs are hidden, shows them again when you mouse over the chat window. Needs Hide Chat Tabs." })
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
    
    local speedCheckbox = W.CreateCheckbox(speedPanel)
    speedCheckbox:SetPoint("TOPLEFT", speedTitle, "BOTTOMLEFT", 0, -12)
    W.AttachHover(speedCheckbox, { body = "Shows a small panel with your current movement speed." })
    speedCheckbox.Text:SetText("Enable Speed Panel")
    speedCheckbox:SetChecked(addon.db.speedPanelEnabled)

    local lockCheckbox = W.CreateCheckbox(speedPanel)
    lockCheckbox:SetPoint("TOPLEFT", speedCheckbox, "BOTTOMLEFT", 0, -12)
    W.AttachHover(lockCheckbox, { body = "Stops the speed panel from being dragged. Unlock it to move it." })
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
    local chkBGEnable = W.CreateCheckbox(bgPanel)
    chkBGEnable:SetPoint("TOPLEFT", bgPanel, "TOPLEFT", 16, -40)
    W.AttachHover(chkBGEnable, { body = "Shows a colored panel you can size and place anywhere, for example behind other parts of your UI." })
    chkBGEnable.Text:SetText("Enable Background Panel")
    chkBGEnable:SetChecked(addon.db.backgroundPanelEnabled)
    chkBGEnable:SetScript("OnClick", function(self)
        addon.db.backgroundPanelEnabled = self:GetChecked()
        addon:UpdateBackgroundPanel()
    end)
    
    -- Lock Panel
    local chkBGLock = W.CreateCheckbox(bgPanel)
    chkBGLock:SetPoint("TOPLEFT", chkBGEnable, "BOTTOMLEFT", 0, -8)
    W.AttachHover(chkBGLock, { body = "Stops the background panel from being dragged or resized." })
    chkBGLock.Text:SetText("Lock Panel Position")
    chkBGLock:SetChecked(addon.db.backgroundPanelLocked)
    chkBGLock:SetScript("OnClick", function(self)
        addon.db.backgroundPanelLocked = self:GetChecked()
        addon:UpdateBackgroundPanel()
    end)
    
    -- Force Screen Width
    local chkBGForce = W.CreateCheckbox(bgPanel)
    chkBGForce:SetPoint("TOPLEFT", chkBGLock, "BOTTOMLEFT", 0, -8)
    W.AttachHover(chkBGForce, { body = "Makes the background panel exactly as wide as the screen." })
    chkBGForce.Text:SetText("Force Screen Width")
    chkBGForce:SetChecked(addon.db.backgroundPanelForceWidth)

    -- Force Screen Height
    local chkBGForceH = W.CreateCheckbox(bgPanel)
    chkBGForceH:SetPoint("TOPLEFT", chkBGForce, "BOTTOMLEFT", 0, -8)
    W.AttachHover(chkBGForceH, { body = "Makes the background panel exactly as tall as the screen." })
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
    lblDimensions:SetText("Dimensions")

    -- Setter for the dimension sliders; refreshes every dimension control
    local function SetBGDimension(key, value)
        value = math.max(16, math.floor((tonumber(value) or 0) + 0.5))
        if addon.db[key] == value then return end
        addon.db[key] = value
        addon:UpdateBackgroundPanel()
        addon:RefreshSettings("background")
    end

    -- Width / Height Sliders (max is the screen size, set when the page opens)
    local function CreateDimensionSlider(key, label, anchorTo)
        local slider = W.CreateSlider(bgPanel, {
            label = label, min = 16, max = 4096, step = 1, width = 300,
            value = addon.db[key] or 16,
            onChange = function(value) SetBGDimension(key, value) end,
        })
        slider:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, -30)
        W.AttachHover(slider, { body = label .. " of the background panel, in pixels, up to the size of the screen. Fixed to the screen's " .. label:lower() .. " while Force Screen " .. label .. " is on." })
        return slider
    end

    local sliderWidth = CreateDimensionSlider("backgroundPanelWidth", "Width", lblDimensions)
    local sliderHeight = CreateDimensionSlider("backgroundPanelHeight", "Height", sliderWidth)

    -- Anchor Dropdown
    local lblAnchor = bgPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    lblAnchor:SetPoint("TOPLEFT", sliderHeight, "BOTTOMLEFT", 0, -24)
    lblAnchor:SetText("Anchor Point")

    local anchorOptions = {}
    for i, anchor in ipairs({ "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }) do
        anchorOptions[i] = { text = anchor, value = anchor }
    end
    -- Just switches the anchor; X/Y aren't converted, so the panel may jump. Drag it to fix.
    -- UpdateBackgroundPanel(true) signals the anchor changed.
    local dropAnchor = CreateDBChoiceDropdown(bgPanel, 120, anchorOptions, "backgroundPanelAnchor", "CENTER",
        function() addon:UpdateBackgroundPanel(true) end)
    dropAnchor:SetPoint("LEFT", lblAnchor, "RIGHT", 10, 0)
    W.AttachHover(dropAnchor, { top = lblAnchor, body = "The point of the screen the panel's position is measured from. Changing it can make the panel jump; drag it back into place." })



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

    -- Listener for external updates (e.g. drag resizing)
    function addon:RefreshSettings(module)
        if module ~= "background" or not sliderWidth:IsVisible() then return end
        local db = addon.db

        -- Always show the panel's real size (screen size when forced)
        local w, h = addon:GetBackgroundPanelSize()
        local bgFrame = addon.backgroundPanel
        if bgFrame and bgFrame.dragRect then
            w, h = bgFrame.dragRect[3], bgFrame.dragRect[4]
        end
        w, h = math.floor(w + 0.5), math.floor(h + 0.5)
        local sw, sh = math.floor(GetScreenWidth() + 0.5), math.floor(GetScreenHeight() + 0.5)

        sliderWidth:SetMinMaxValues(16, math.max(sw, w))
        sliderWidth:SetValue(w, true)
        sliderHeight:SetMinMaxValues(16, math.max(sh, h))
        sliderHeight:SetValue(h, true)

        sliderWidth:SetEnabled(not db.backgroundPanelForceWidth)
        sliderHeight:SetEnabled(not db.backgroundPanelForceHeight)

        chkBGEnable:SetChecked(db.backgroundPanelEnabled)
        chkBGLock:SetChecked(db.backgroundPanelLocked)
        chkBGForce:SetChecked(db.backgroundPanelForceWidth)
        chkBGForceH:SetChecked(db.backgroundPanelForceHeight)

        dropAnchor:Refresh()
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

    -- Every control in this section shares the title's left edge.
    local npFriendlyEnabled = W.CreateCheckbox(npFriendlyPanel)
    npFriendlyEnabled:SetPoint("TOPLEFT", npFriendlyTitle, "BOTTOMLEFT", 0, -12)
    W.AttachHover(npFriendlyEnabled, { body = "Draws a readable name above friendly players' simplified nameplates." })
    npFriendlyEnabled.Text:SetText("Enable Friendly Name Rendering")
    npFriendlyEnabled:SetChecked(addon.db.nameplateFriendlyNamesEnabled ~= false)
    npFriendlyEnabled:SetScript("OnClick", function(self)
        addon.db.nameplateFriendlyNamesEnabled = self:GetChecked()
        if addon.UpdateFriendlyNameplates then addon:UpdateFriendlyNameplates() end
    end)

    local npFriendlyShowTitle = W.CreateCheckbox(npFriendlyPanel)
    npFriendlyShowTitle:SetPoint("TOPLEFT", npFriendlyEnabled, "BOTTOMLEFT", 0, -4)
    W.AttachHover(npFriendlyShowTitle, { body = "Includes the player's title in their name." })
    npFriendlyShowTitle.Text:SetText("Show Title")
    npFriendlyShowTitle:SetChecked(addon.db.nameplateFriendlyNamesShowTitle == true)
    npFriendlyShowTitle:SetScript("OnClick", function(self)
        addon.db.nameplateFriendlyNamesShowTitle = self:GetChecked()
        if addon.UpdateFriendlyNameplates then addon:UpdateFriendlyNameplates() end
    end)

    local npFriendlyShowGuild = W.CreateCheckbox(npFriendlyPanel)
    npFriendlyShowGuild:SetPoint("TOPLEFT", npFriendlyShowTitle, "BOTTOMLEFT", 0, -4)
    W.AttachHover(npFriendlyShowGuild, { body = "Also shows the player's guild name." })
    npFriendlyShowGuild.Text:SetText("Show Guild Name")
    npFriendlyShowGuild:SetChecked(addon.db.nameplateFriendlyNamesShowGuild == true)
    npFriendlyShowGuild:SetScript("OnClick", function(self)
        addon.db.nameplateFriendlyNamesShowGuild = self:GetChecked()
        addon:UpdateFriendlyNameplates()
    end)

    local npClassColor = W.CreateCheckbox(npFriendlyPanel)
    npClassColor:SetPoint("TOPLEFT", npFriendlyShowGuild, "BOTTOMLEFT", 0, -4)
    W.AttachHover(npClassColor, { body = "Colors friendly player names by class." })
    npClassColor.Text:SetText("Use Class Colors on Friendly Names")
    npClassColor:SetChecked(addon.db.nameplateUseClassColorForFriendlyPlayerUnitNames)
    npClassColor:SetScript("OnClick", function(self)
        addon.db.nameplateUseClassColorForFriendlyPlayerUnitNames = self:GetChecked()
        addon:SetFriendlyClassColorCVar(self:GetChecked())
        addon:UpdateFriendlyNameplates()
    end)

    local function UpdateFriendlyNameplates()
        if addon.UpdateFriendlyNameplates then addon:UpdateFriendlyNameplates() end
    end

    local npFriendlyScale = CreateDBSlider(npFriendlyPanel, "Nameplate Scale (%)", "nameplateFriendlyScale", 1.0, 0.5, 3.0, 0.05, 220, 0, 100, UpdateFriendlyNameplates)
    npFriendlyScale:SetPoint("TOPLEFT", npClassColor, "BOTTOMLEFT", 0, -28)
    W.AttachHover(npFriendlyScale, { body = "Size of friendly nameplates, where 100% is their normal size." })

    -- Sits between the class colour checkbox and the scale slider; scoped to stay under the local limit
    do
        local npFullInInstances = W.CreateCheckbox(npFriendlyPanel)
        npFullInInstances:SetPoint("TOPLEFT", npClassColor, "BOTTOMLEFT", 0, -4)
        W.AttachHover(npFullInInstances, { body = "Addons can't draw on friendly nameplates in dungeons, raids and scenarios, so simplified plates show no names there. This turns simplified friendly player nameplates off while you are inside one and back on when you leave." })
        npFullInInstances.Text:SetText("Use Default Friendly Nameplates in Instances")
        npFullInInstances:SetChecked(addon.db.nameplateFullFriendlyInInstances == true)
        npFullInInstances:SetScript("OnClick", function(self)
            addon.db.nameplateFullFriendlyInInstances = self:GetChecked()
            addon:UpdateInstanceSimplifiedNameplates()
        end)

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

    -- Typeface dropdown whose entries are each drawn in their own font, one submenu per
    -- source. getPath returns the chosen font file (nil, or one not listed, shows
    -- "Default"); setPath stores a new one. The stepper buttons walk every group in turn.
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

    local function CreateFontDropdown(parent, getPath, setPath)
        local function IsSelected(path) return getPath() == path end
        local function SetSelected(path) setPath(path) end

        local dropdown = W.CreateDropdown(parent, 210, function(_, rootDescription)
            local _, grouped, groupOrder = BuildFriendlyFontList()
            for _, group in ipairs(groupOrder) do
                local fontsInGroup = grouped[group] or {}
                if #fontsInGroup > 0 then
                    local groupDescription = rootDescription:CreateButton(group)
                    for _, item in ipairs(fontsInGroup) do
                        W.CreateFontRadio(groupDescription, item.name, GetPreviewFont(item.path), IsSelected, SetSelected, item.path)
                    end
                    W.LimitMenuHeight(groupDescription, #fontsInGroup)
                end
            end
        end)
        dropdown.Dropdown:SetDefaultText("Default")
        return dropdown
    end

    local fontDropdown = CreateFontDropdown(npFriendlyPanel,
        function() return addon.db.nameplateFriendlyNameFont or "Fonts\\FRIZQT__.TTF" end,
        function(path)
            addon.db.nameplateFriendlyNameFont = path
            addon:UpdateFriendlyNameplates()
        end)
    fontDropdown:SetPoint("TOPLEFT", fontLabel, "BOTTOMLEFT", 0, -2)
    W.AttachHover(fontDropdown, { top = fontLabel, body = "Typeface for friendly names. Lists fonts from LibSharedMedia and FontMagic too, when they're installed." })

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

    -- Saved values may be lower case from older versions
    local function UpperDBChoice(dbKey, default)
        return function() return (addon.db[dbKey] or default):upper() end
    end

    local outlineDropdown = W.CreateChoiceDropdown(npFriendlyPanel, 160, {
        { text = "None", value = "NONE" },
        { text = "Outline", value = "OUTLINE" },
        { text = "Thick Outline", value = "THICKOUTLINE" },
    }, UpperDBChoice("nameplateFriendlyNameOutline", "OUTLINE"), function(value)
        addon.db.nameplateFriendlyNameOutline = value
        UpdateFriendlyNameplates()
    end)
    outlineDropdown:SetPoint("TOPLEFT", outlineLabel, "BOTTOMLEFT", 0, -2)
    W.AttachHover(outlineDropdown, { top = outlineLabel, body = "Outline drawn around friendly names." })

    local sizeSlider = CreateDBSlider(npFriendlyPanel, "Font Size", "nameplateFriendlyNameSize", 13, 8, 64, 1, 220, 0, nil, UpdateFriendlyNameplates)
    sizeSlider:SetPoint("TOPLEFT", outlineLabel, "BOTTOMLEFT", 0, -62)
    W.AttachHover(sizeSlider, { body = "Size of friendly names." })

    local xSlider = CreateDBSlider(npFriendlyPanel, "X Offset", "nameplateFriendlyNameOffsetX", 0, -100, 100, 1, 220, 0, nil, UpdateFriendlyNameplates)
    xSlider:SetPoint("TOPLEFT", sizeSlider, "BOTTOMLEFT", 0, -30)
    W.AttachHover(xSlider, { body = "Moves friendly names left or right of the nameplate's center." })

    local ySlider = CreateDBSlider(npFriendlyPanel, "Y Offset", "nameplateFriendlyNameOffsetY", 10, -100, 100, 1, 220, 0, nil, UpdateFriendlyNameplates)
    ySlider:SetPoint("TOPLEFT", xSlider, "BOTTOMLEFT", 0, -30)
    W.AttachHover(ySlider, { body = "Moves friendly names up or down from the nameplate." })

    local justifyLabel = npFriendlyPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    justifyLabel:SetPoint("TOPLEFT", ySlider, "BOTTOMLEFT", 0, -22)
    justifyLabel:SetText("Justification")

    local justifyDropdown = W.CreateChoiceDropdown(npFriendlyPanel, 120, {
        { text = "Left", value = "LEFT" },
        { text = "Center", value = "CENTER" },
        { text = "Right", value = "RIGHT" },
    }, UpperDBChoice("nameplateFriendlyNameJustify", "CENTER"), function(value)
        addon.db.nameplateFriendlyNameJustify = value
        UpdateFriendlyNameplates()
    end)
    justifyDropdown:SetPoint("TOPLEFT", justifyLabel, "BOTTOMLEFT", 0, -2)
    W.AttachHover(justifyDropdown, { top = justifyLabel, body = "Which edge of the name area friendly names line up against." })

    -- ====================
    -- COOLDOWN TAB CONTENT
    -- ====================
    -- Lives after the nameplate section to use the font dropdown; scoped to stay under the local limit
    do
        local cdMouseGroup, cdMouseTitle = CreateSection(tabCooldowns, "Cooldown Timer at Mouse", "Shows the time remaining beside the cursor when you press a spell that is still on cooldown.", 380, "cooldownAtMouse")

        local cdMouseCheckbox = W.CreateCheckbox(cdMouseGroup)
        cdMouseCheckbox:SetPoint("TOPLEFT", cdMouseTitle, "BOTTOMLEFT", 0, -12)
        W.AttachHover(cdMouseCheckbox, { body = "When you press a spell that's still on cooldown, shows the time left beside your cursor." })
        cdMouseCheckbox.Text:SetText("Show Cooldown Timer at Mouse")
        cdMouseCheckbox:SetChecked(addon.db.cooldownAtMouseEnabled)

        local cdMouseDurationSlider = CreateDBSlider(cdMouseGroup, "Duration (s)", "cooldownAtMouseDuration", 3.0, 1, 10, 0.5, 200, 1)
        cdMouseDurationSlider:SetPoint("TOPLEFT", cdMouseCheckbox, "BOTTOMLEFT", 0, -28)
        W.AttachHover(cdMouseDurationSlider, { body = "How long the timer stays beside the cursor, in seconds." })

        local cdMouseOffsetSlider = CreateDBSlider(cdMouseGroup, "Offset Distance", "cooldownAtMouseOffset", 40, 0, 300, 1, 300)
        cdMouseOffsetSlider:SetPoint("TOPLEFT", cdMouseDurationSlider, "BOTTOMLEFT", 0, -36)
        W.AttachHover(cdMouseOffsetSlider, { body = "How far from the cursor the timer appears, in pixels." })

        -- 0 is straight above the cursor
        local cdMouseAngleSlider = CreateDBSlider(cdMouseGroup, "Offset Rotation (0 = above)", "cooldownAtMouseAngle", 90, 0, 355, 5, 300)
        cdMouseAngleSlider:SetPoint("TOPLEFT", cdMouseOffsetSlider, "BOTTOMLEFT", 0, -36)
        W.AttachHover(cdMouseAngleSlider, { body = "Which direction from the cursor the timer appears, in degrees clockwise from straight above: 90 is to the right, 180 below." })

        local cdMouseSizeSlider = CreateDBSlider(cdMouseGroup, "Font Size", "cooldownAtMouseFontSize", 22, 8, 72, 1, 300, 0, nil,
            function() addon:UpdateCooldownAtMouseFont() end)
        cdMouseSizeSlider:SetPoint("TOPLEFT", cdMouseAngleSlider, "BOTTOMLEFT", 0, -36)
        W.AttachHover(cdMouseSizeSlider, { body = "Size of the cooldown timer text." })

        local cdMouseFontLabel = cdMouseGroup:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        cdMouseFontLabel:SetPoint("TOPLEFT", cdMouseSizeSlider, "BOTTOMLEFT", 0, -24)
        cdMouseFontLabel:SetText("Typeface")

        local cdMouseFontDropdown = CreateFontDropdown(cdMouseGroup,
            function() return addon.db.cooldownAtMouseFont or "Fonts\\FRIZQT__.TTF" end,
            function(path)
                addon.db.cooldownAtMouseFont = path
                addon:UpdateCooldownAtMouseFont()
            end)
        cdMouseFontDropdown:SetPoint("TOPLEFT", cdMouseFontLabel, "BOTTOMLEFT", 0, -2)
        W.AttachHover(cdMouseFontDropdown, { top = cdMouseFontLabel, body = "Typeface for the cooldown timer." })

        local function UpdateCooldownControls()
            local enabled = addon.db.cooldownAtMouseEnabled
            cdMouseDurationSlider:SetEnabled(enabled)
            cdMouseOffsetSlider:SetEnabled(enabled)
            cdMouseAngleSlider:SetEnabled(enabled)
            cdMouseSizeSlider:SetEnabled(enabled)
            cdMouseFontDropdown:SetEnabled(enabled)
            W.SetFontStringEnabled(cdMouseFontLabel, enabled)
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
        local RefreshChatFontControls

        local windowLabel = chatFontGroup:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        windowLabel:SetPoint("TOPLEFT", chatFontTitle, "BOTTOMLEFT", 0, -14)
        windowLabel:SetText("Chat Window")

        -- Options are rebuilt each time it opens, so new and renamed windows are listed
        local windowDropdown = W.CreateChoiceDropdown(chatFontGroup, 210,
            function()
                local options = {}
                for i, id in ipairs(addon:GetChatWindowIDs()) do
                    options[i] = { text = addon:GetChatWindowName(id), value = id }
                end
                return options
            end,
            function() return selectedWindow end,
            function(id)
                selectedWindow = id
                RefreshChatFontControls()
            end)
        windowDropdown:SetPoint("TOPLEFT", windowLabel, "BOTTOMLEFT", 0, -2)
        W.AttachHover(windowDropdown, { top = windowLabel, body = "The chat window whose font the settings below change. Each window keeps its own." })

        local fontLabel = chatFontGroup:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        fontLabel:SetPoint("TOPLEFT", windowLabel, "BOTTOMLEFT", 0, -46)
        fontLabel:SetText("Typeface")

        local fontDropdown = CreateFontDropdown(chatFontGroup,
            function() return addon:GetChatFontOverride(selectedWindow).font end,
            function(path) addon:SetChatFontOverride(selectedWindow, "font", path) end)
        fontDropdown:SetPoint("TOPLEFT", fontLabel, "BOTTOMLEFT", 0, -2)
        W.AttachHover(fontDropdown, { top = fontLabel, body = "Typeface for the text in the selected chat window." })

        local sizeSlider = W.CreateSlider(chatFontGroup, {
            label = "Font Size", min = 8, max = 32, step = 1, width = 300,
            value = addon:GetChatFontSize(selectedWindow),
            onChange = function(value) addon:SetChatFontOverride(selectedWindow, "size", value) end,
        })
        sizeSlider:SetPoint("TOPLEFT", fontLabel, "BOTTOMLEFT", 0, -62)
        W.AttachHover(sizeSlider, { body = "Size of the text in the selected chat window." })

        local resetButton = CreateFrame("Button", nil, chatFontGroup, "UIPanelButtonTemplate")
        resetButton:SetPoint("TOPLEFT", sizeSlider, "BOTTOMLEFT", 0, -26)
        resetButton:SetSize(160, 22)
        resetButton:SetText("Reset This Window")

        -- Shows the selected window's current font and size
        function RefreshChatFontControls()
            windowDropdown:Refresh()
            fontDropdown:Refresh()
            sizeSlider:SetValue(addon:GetChatFontSize(selectedWindow), true)
        end

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
        local function CreateChoiceDropdown(options, dbKey, defaultKey)
            local choices = {}
            for i, option in ipairs(options) do
                choices[i] = { text = option.name, value = option.key }
            end
            return CreateDBChoiceDropdown(speedLookGroup, 210, choices, dbKey, defaultKey, Apply)
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
        local fontDropdown = CreateFontDropdown(speedLookGroup,
            function() return addon.db.speedPanelFont end,
            function(path)
                addon.db.speedPanelFont = path
                Apply()
            end)
        fontDropdown:SetPoint("TOPLEFT", fontLabel, "BOTTOMLEFT", 0, -2)
        W.AttachHover(fontDropdown, { top = fontLabel, body = "Typeface for the speed panel's text." })

        local outlineLabel = CreateLabel("Outline", fontLabel, -46)
        local outlineDropdown = CreateChoiceDropdown(addon:GetSpeedPanelOutlineOptions(), "speedPanelFontOutline", "NONE")
        outlineDropdown:SetPoint("TOPLEFT", outlineLabel, "BOTTOMLEFT", 0, -2)
        W.AttachHover(outlineDropdown, { top = outlineLabel, body = "Outline drawn around the speed panel's text." })

        local sizeSlider = CreateDBSlider(speedLookGroup, "Font Size", "speedPanelFontSize", 16, 8, 40, 1, 300, 0, nil, Apply)
        sizeSlider:SetPoint("TOPLEFT", outlineLabel, "BOTTOMLEFT", 0, -62)
        W.AttachHover(sizeSlider, { body = "Size of the speed panel's text." })

        local textColorRow = CreateColorRow("Text Color", "speedPanelTextColor", { r = 1, g = 1, b = 1, a = 1 })
        textColorRow:SetPoint("TOPLEFT", sizeSlider, "BOTTOMLEFT", 0, -28)

        -- Background
        local backgroundLabel = CreateLabel("Background", textColorRow, -18)
        local backgroundDropdown = CreateChoiceDropdown(addon:GetSpeedPanelBackgroundOptions(), "speedPanelBackgroundKey", "dialog")
        backgroundDropdown:SetPoint("TOPLEFT", backgroundLabel, "BOTTOMLEFT", 0, -2)
        W.AttachHover(backgroundDropdown, { top = backgroundLabel, body = "Texture filling the speed panel's background. Its color is set below." })

        local backgroundColorRow = CreateColorRow("Background Color / Opacity", "speedPanelBackgroundColor", { r = 0, g = 0, b = 0, a = 0.55 })
        backgroundColorRow:SetPoint("TOPLEFT", backgroundLabel, "BOTTOMLEFT", 0, -46)

        -- Border
        local borderLabel = CreateLabel("Border", backgroundColorRow, -18)
        local borderDropdown = CreateChoiceDropdown(addon:GetSpeedPanelBorderOptions(), "speedPanelBorderKey", "tooltip")
        borderDropdown:SetPoint("TOPLEFT", borderLabel, "BOTTOMLEFT", 0, -2)
        W.AttachHover(borderDropdown, { top = borderLabel, body = "Border drawn around the speed panel. Its color is set below." })

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
