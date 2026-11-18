---@diagnostic disable: undefined-global
-- Garage UI Tweaks - Settings
-- The settings pages, built from the game's own Settings panel controls (SettingsWidgets.lua).
-- Every control stores its value in addon.db and then calls the tweak's addon:Update...().
local addonName, addon = ...
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
local W = addon.SettingsWidgets

local PANEL_NAME = "Garage UI Tweaks"

-- ============================================================================
-- Controls bound to a setting
-- ============================================================================

-- Checkbox for the true/false setting addon.db[dbKey]. `hover` is the tooltip text, or
-- W.AttachHover's options, or false to attach the hover separately.
local function CreateDBCheckbox(parent, label, dbKey, hover, apply)
    local checkbox = W.CreateCheckbox(parent)
    checkbox.Text:SetText(label)
    checkbox:SetChecked(addon.db[dbKey])
    checkbox:SetScript("OnClick", function(self)
        addon.db[dbKey] = self:GetChecked()
        if apply then apply() end
    end)
    if hover ~= false then
        W.AttachHover(checkbox, type(hover) == "table" and hover or { body = hover })
    end
    return checkbox
end

-- Slider for the number addon.db[dbKey]. opts as for W.CreateSlider (label, min, max, step,
-- width, decimals, scale), plus apply(value) to run after storing a new value.
local function CreateDBSlider(parent, dbKey, opts, hover)
    local apply = opts.apply
    opts.value = addon.db[dbKey]
    opts.onChange = function(value)
        addon.db[dbKey] = value
        if apply then apply(value) end
    end
    local slider = W.CreateSlider(parent, opts)
    if hover then
        W.AttachHover(slider, { body = hover })
    end
    return slider
end

-- Dropdown over { text, value } choices, stored in addon.db[dbKey]
local function CreateDBChoiceDropdown(parent, width, options, dbKey, apply)
    return W.CreateChoiceDropdown(parent, width, options,
        function() return addon.db[dbKey] end,
        function(value)
            addon.db[dbKey] = value
            if apply then apply(value) end
        end)
end

local function CreateLabel(parent, text, fontObject)
    local label = parent:CreateFontString(nil, "ARTWORK", fontObject or "GameFontHighlightSmall")
    label:SetText(text)
    return label
end

local function CreateButton(parent, text, width, onClick, hover)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 22)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    if hover then
        W.AttachHover(button, { body = hover })
    end
    return button
end

-- Greys out `controls` (controls or labels) while `checkbox` is unticked. Call it after the
-- checkbox's OnClick is set, which would otherwise replace this.
local function DependOn(checkbox, controls)
    local function Update()
        local enabled = checkbox:GetChecked()
        for _, control in ipairs(controls) do
            if control.SetEnabled then
                control:SetEnabled(enabled)
            else
                W.SetFontStringEnabled(control, enabled)
            end
        end
    end
    checkbox:HookScript("OnClick", Update)
    Update()
end

-- Opens the color picker on the color in addon.db[dbKey]. Each change stores a new
-- { r, g, b, a } and runs onChange; cancelling puts the old color back.
local function OpenColorPicker(dbKey, onChange)
    local old = addon.db[dbKey]
    local function Store(r, g, b, a)
        addon.db[dbKey] = { r = r, g = g, b = b, a = a }
        onChange()
    end
    local function OnPicked()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        Store(r, g, b, ColorPickerFrame:GetColorAlpha())
    end

    ColorPickerFrame:SetupColorPickerAndShow({
        r = old.r, g = old.g, b = old.b, opacity = old.a or 1,
        hasOpacity = true,
        swatchFunc = OnPicked,
        opacityFunc = OnPicked,
        cancelFunc = function() Store(old.r, old.g, old.b, old.a) end,
    })
end

-- A label and a square showing the color in addon.db[dbKey]; clicking the square opens the
-- color picker, with opacity
local function CreateColorSwatch(parent, labelText, dbKey, apply)
    local row = CreateFrame("Frame", nil, parent)
    local label = CreateLabel(row, labelText)
    label:SetPoint("LEFT")

    local swatch = CreateFrame("Button", nil, row)
    swatch:SetSize(20, 20)
    swatch:SetPoint("LEFT", label, "RIGHT", 10, 0)
    local border = swatch:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(1, 1, 1, 1)
    local fill = swatch:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMRIGHT", -1, 1)

    local function ShowColor()
        local color = addon.db[dbKey]
        fill:SetColorTexture(color.r, color.g, color.b, 1)
    end
    ShowColor()

    swatch:SetScript("OnClick", function()
        OpenColorPicker(dbKey, function()
            ShowColor()
            apply()
        end)
    end)

    row:SetSize(label:GetStringWidth() + 30, 20)
    return row
end

-- ============================================================================
-- Font dropdown
-- ============================================================================

local FONTMAGIC_GROUPS = {
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

-- Every font on offer, by group: the game's own, LibSharedMedia's and FontMagic's.
-- Returns the groups' fonts ({ name, path } lists, sorted by name) and the groups in order.
local function BuildFontList()
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

    local function AddFont(name, path, group)
        if not path or path == "" or seenByPath[path] then
            return
        end
        seenByPath[path] = true
        table.insert(fontList, { name = name, path = path, group = group })
    end

    if LSM then
        local fonts = LSM:HashTable("font")
        local keys = {}
        for key in pairs(fonts) do
            table.insert(keys, key)
        end
        table.sort(keys)
        for _, key in ipairs(keys) do
            AddFont(key, fonts[key], "LibSharedMedia")
        end
    end

    if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("FontMagic") then
        local function AddFontMagicFont(groupLabel, basePath, fileName)
            local label = fileName:gsub("%.[Tt][Tt][Ff]$", ""):gsub("%.[Oo][Tt][Ff]$", "")
            AddFont(label, basePath .. fileName, "FontMagic: " .. groupLabel)
        end

        for _, group in ipairs(FONTMAGIC_GROUPS) do
            local basePath = "Interface\\AddOns\\FontMagic\\" .. group.folder .. "\\"
            for _, fileName in ipairs(group.fonts) do
                AddFontMagicFont(group.label, basePath, fileName)
            end
        end

        local customPath = "Interface\\AddOns\\FontMagicCustomFonts\\Custom\\"
        if type(FontMagicCustomFonts) == "table" and type(FontMagicCustomFonts.PATH) == "string" and FontMagicCustomFonts.PATH ~= "" then
            customPath = FontMagicCustomFonts.PATH
        end
        for i = 1, 20 do
            AddFontMagicFont("Custom", customPath, i .. ".ttf")
        end
    end

    local grouped = {}
    local groupOrder = { "Blizzard", "LibSharedMedia" }
    local known = { Blizzard = true, LibSharedMedia = true }
    for _, item in ipairs(fontList) do
        grouped[item.group] = grouped[item.group] or {}
        table.insert(grouped[item.group], item)
        if not known[item.group] then
            known[item.group] = true
            table.insert(groupOrder, item.group)
        end
    end

    -- FontMagic's groups go last
    table.sort(groupOrder, function(a, b)
        local aMagic, bMagic = a:find("^FontMagic:") ~= nil, b:find("^FontMagic:") ~= nil
        if aMagic ~= bMagic then
            return bMagic
        end
        return a < b
    end)
    for _, fonts in pairs(grouped) do
        table.sort(fonts, function(a, b) return a.name:lower() < b.name:lower() end)
    end

    return grouped, groupOrder
end

-- A font object per font file, to draw each menu entry in its own font. False for a file
-- that won't load (the FontMagic lists name files that may not be installed).
local previewFonts = {}
local previewFontCount = 0

local function GetPreviewFont(path)
    local font = previewFonts[path]
    if font == nil then
        previewFontCount = previewFontCount + 1
        font = CreateFont("GUIT_FontPreview" .. previewFontCount)
        -- A missing font file raises an error on some clients and returns false on
        -- others; SetFont returns nothing on success here
        local ok, result = pcall(font.SetFont, font, path, 14, "")
        if not ok or result == false then
            font = false
        end
        previewFonts[path] = font
    end
    return font or nil
end

-- Typeface dropdown whose entries are each drawn in their own font, one submenu per
-- source. getPath returns the chosen font file (nil, or one not listed, shows "Default");
-- setPath stores a new one. The stepper buttons walk every group in turn.
local function CreateFontDropdown(parent, getPath, setPath)
    local function IsSelected(path) return getPath() == path end
    local function SetSelected(path) setPath(path) end

    local dropdown = W.CreateDropdown(parent, 210, function(_, rootDescription)
        local grouped, groupOrder = BuildFontList()
        for _, group in ipairs(groupOrder) do
            local loadable = {}
            for _, item in ipairs(grouped[group] or {}) do
                if GetPreviewFont(item.path) then
                    table.insert(loadable, item)
                end
            end
            if #loadable > 0 then
                local groupDescription = rootDescription:CreateButton(group)
                for _, item in ipairs(loadable) do
                    W.CreateFontRadio(groupDescription, item.name, GetPreviewFont(item.path), IsSelected, SetSelected, item.path)
                end
                W.LimitMenuHeight(groupDescription, #loadable)
            end
        end
    end)
    dropdown.Dropdown:SetDefaultText("Default")
    return dropdown
end

-- Font dropdown for the font file in addon.db[dbKey]
local function CreateDBFontDropdown(parent, dbKey, apply)
    return CreateFontDropdown(parent,
        function() return addon.db[dbKey] end,
        function(path)
            addon.db[dbKey] = path
            apply()
        end)
end

-- ============================================================================
-- Pages and sections
-- ============================================================================

local function CreateSettingsPage(id, title, description)
    local page = CreateFrame("Frame", "GarageUITweaksSettingsPage_" .. id, UIParent)

    local titleText = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    titleText:SetPoint("TOPLEFT", 16, -16)
    titleText:SetText(title)

    local descText = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    descText:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -8)
    descText:SetPoint("RIGHT", page, "RIGHT", -16, 0)
    descText:SetJustifyH("LEFT")
    descText:SetText(description)

    local scrollFrame = W.CreateScrollFrame(page)
    scrollFrame:SetPoint("TOPLEFT", descText, "BOTTOMLEFT", 0, -12)
    scrollFrame:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -20, 12)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(1, 1)
    scrollFrame:SetScrollChild(scrollChild)
    scrollFrame:SetScript("OnSizeChanged", function(self)
        scrollChild:SetWidth(self:GetWidth())
    end)

    return {
        id = id,
        name = title,
        frame = page,
        scrollChild = scrollChild,
        totalHeight = 0,
        lastSection = nil,
        visibleSections = 0,
    }
end

-- Adds a boxed section to a page. featureID (optional) names a Compat.lua feature; when this
-- client can't support it the section is still built, so the code filling it runs, but it
-- is left out of the layout.
local function CreateSection(page, titleText, descriptionText, height, featureID)
    local parent = page.scrollChild
    local section = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    section:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    section:SetBackdropColor(0.1, 0.1, 0.1, 0.4)
    section:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
    section:SetHeight(height)

    local supported = not featureID or addon:IsFeatureSupported(featureID)
    if not supported then
        section:Hide()
    elseif page.lastSection then
        section:SetPoint("TOPLEFT", page.lastSection, "BOTTOMLEFT", 0, -16)
        section:SetPoint("RIGHT", parent, "RIGHT", -4, 0)
        page.totalHeight = page.totalHeight + 16
    else
        section:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -4)
        section:SetPoint("RIGHT", parent, "RIGHT", -4, 0)
        page.totalHeight = page.totalHeight + 4
    end

    local title = section:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPLEFT", 10, -12)
    title:SetText(titleText)

    local desc = section:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "TOPRIGHT", 12, 0)
    desc:SetPoint("RIGHT", section, "RIGHT", -12, 0)
    desc:SetJustifyH("LEFT")
    desc:SetText(descriptionText)

    if supported then
        page.lastSection = section
        page.visibleSections = page.visibleSections + 1
        page.totalHeight = page.totalHeight + height
        parent:SetHeight(math.max(page.totalHeight, 100))
    end

    return section, title
end

-- For a last row this client can't support: hides it, and the section and page get shorter
local function DropLastRow(page, section, row, height)
    row:Hide()
    section:SetHeight(section:GetHeight() - height)
    page.totalHeight = page.totalHeight - height
    page.scrollChild:SetHeight(math.max(page.totalHeight, 100))
end

-- ============================================================================
-- General
-- ============================================================================

local function BuildGeneralPage(page)
    local section, title

    -- Error text background
    section, title = CreateSection(page, "Error Text Background", "Draws a backdrop behind UI errors briefly to improve visibility.", 174)
    local function ApplyErrorBackground() addon:UpdateErrorTextBackground() end

    local errorEnabled = CreateDBCheckbox(section, "Enable Background", "errorTextBackgroundEnabled",
        "Draws a dark backdrop behind the red error messages at the top of the screen, such as \"Not enough rage\", so they're easier to read.",
        ApplyErrorBackground)
    errorEnabled:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)

    local errorAlpha = CreateDBSlider(section, "errorTextBackgroundAlpha",
        { label = "Opacity (%)", min = 0, max = 1, step = 0.05, width = 220, scale = 100, apply = ApplyErrorBackground },
        "How solid the backdrop behind error messages is.")
    errorAlpha:SetPoint("TOPLEFT", errorEnabled, "BOTTOMLEFT", 0, -28)

    local errorDuration = CreateDBSlider(section, "errorTextBackgroundDuration",
        { label = "Duration (s)", min = 1, max = 5, step = 0.1, width = 200, decimals = 1 },
        "How long the backdrop stays after an error message appears, in seconds.")
    errorDuration:SetPoint("TOPLEFT", errorAlpha, "BOTTOMLEFT", 0, -32)

    DependOn(errorEnabled, { errorAlpha, errorDuration })

    -- Override action bar
    section, title = CreateSection(page, "Override Action Bar", "Adjust the position of the Vehicle/Override Action Bar.", 100)
    local overrideOffset = CreateDBSlider(section, "overrideActionBarYOffset",
        { label = "Y Offset", min = 0, max = 300, step = 1, width = 340, apply = function() addon:UpdateOverrideActionBar() end },
        "Raises the vehicle / override action bar this many pixels above the bottom of the screen.")
    overrideOffset:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -28)

    -- Armor set highlights
    section, title = CreateSection(page, "Armor Set Action Highlights", "Outline action buttons that trigger your currently equipped armor set.", 80, "armorSetHighlight")
    CreateDBCheckbox(section, "Use assisted-combat style outline for equipped set buttons", "armorSetActionHighlightEnabled",
        "Outlines action buttons that trigger your currently equipped armor set, in the same style as the assisted combat highlight.",
        function() addon:UpdateArmorSetHighlights() end)
        :SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)

    -- Micro menu
    section, title = CreateSection(page, "Micro Menu", "Adjust the appearance of the micro menu bar.", 110, "microMenuArt")
    local function ApplyMicroMenu() addon:UpdateMicroMenuArt() end

    local hideBackground = CreateDBCheckbox(section, "Hide micro menu background art", "hideMicroMenuBackgroundArt",
        "Hides the background art behind the micro menu buttons.", ApplyMicroMenu)
    hideBackground:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)

    CreateDBCheckbox(section, "Hide micro menu border art", "hideMicroMenuBorderArt",
        "Hides the border art around the micro menu.", ApplyMicroMenu)
        :SetPoint("TOPLEFT", hideBackground, "BOTTOMLEFT", 0, -6)
end

-- ============================================================================
-- Frame tweaks
-- ============================================================================

local function BuildFramePage(page)
    local section, title

    -- Battleground map
    section, title = CreateSection(page, "Battleground Map Scale", "Adjust the battlefield map size (Shift+M).", 130)
    local function ApplyMap() addon:UpdateBattlegroundMap() end

    local mapScale = CreateDBSlider(section, "battlegroundMapScale",
        { label = "Scale (%)", min = 0.5, max = 2.0, step = 0.1, width = 200, scale = 100, apply = ApplyMap },
        "Size of the battlefield map (Shift+M), where 100% is its normal size.")
    mapScale:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -28)

    CreateDBCheckbox(section, "Force map to lowest strata", "battlegroundMapForceLowestStrata",
        "Draws the battlefield map beneath other frames, so it never covers them.", ApplyMap)
        :SetPoint("TOPLEFT", mapScale, "BOTTOMLEFT", 0, -10)

    -- Experience bars
    section, title = CreateSection(page, "Experience Bars", "Adjust strata behavior for XP/reputation/honor tracking bars.", 80)
    CreateDBCheckbox(section, "Force experience bars to highest strata", "experienceBarsForceHighestStrata",
        "Draws the experience, reputation and honor bars above other frames, so nothing covers them.",
        function() addon:UpdateExperienceBarStrata() end)
        :SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)

    -- Raid and party frames
    section, title = CreateSection(page, "Raid & Party Frames", "Keep party and raid frame groups centered as they resize.", 110)
    local function ApplyCentering() addon:UpdateRaidPartyFrameCentering() end

    local centerParty = CreateDBCheckbox(section, "Center party frames", "centerPartyFramesEnabled", false, ApplyCentering)
    centerParty:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    W.AttachHover(centerParty, { right = centerParty.Text, body = "Keeps the party frames centered on their position as members join and leave." })

    CreateDBCheckbox(section, "Center raid frames", "centerRaidFramesEnabled",
        "Keeps the raid frame groups centered as the raid grows and shrinks.", ApplyCentering)
        :SetPoint("TOPLEFT", centerParty, "BOTTOMLEFT", 0, -6)

    local centerDebug = CreateDBCheckbox(section, "Debug logging", "centerFramesDebug", false)
    centerDebug:SetPoint("LEFT", centerParty, "RIGHT", 220, 0)
    W.AttachHover(centerDebug, { left = centerDebug, body = "Prints a message to chat each time the party or raid frames are re-centered, for troubleshooting. Type /guit debug to list where they are now." })

    -- Top center widgets
    section, title = CreateSection(page, "Top Center Widget Offset", "Move the widgets at the top center of the screen downward.", 100)
    local topCenterOffset = CreateDBSlider(section, "topCenterWidgetOffset",
        { label = "Offset", min = 0, max = 100, step = 1, width = 340, apply = function() addon:UpdateTopCenterWidgetOffset() end },
        "Moves the widgets at the top center of the screen, such as battleground scores and zone objectives, down by this many pixels.")
    topCenterOffset:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -28)
end

-- ============================================================================
-- Chat
-- ============================================================================

local function BuildChatPage(page)
    local section, title

    -- Chat entry box
    section, title = CreateSection(page, "Chat Entry Box", "Customize the position and appearance of the chat input box.", 264)
    local entryBoxSection = section
    local function ApplyEditBox() addon:UpdateChatEditBox() end

    local unlock = CreateDBCheckbox(section, "Unlock Chat Entry Box (Hold SHIFT to Drag)", "chatEditBoxUnlock",
        "Lets you move the chat entry box: hold Shift and drag it. Until it has been moved, the game places it as usual.", ApplyEditBox)
    unlock:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)

    local hideBorder = CreateDBCheckbox(section, "Hide Default Borders", "chatEditBoxHideBorder",
        "Hides the default border textures around the chat entry box.", ApplyEditBox)
    hideBorder:SetPoint("TOPLEFT", unlock, "BOTTOMLEFT", 0, -12)

    local width = CreateDBSlider(section, "chatEditBoxWidth",
        { label = "Width", min = 200, max = 1000, step = 10, width = 340, apply = ApplyEditBox },
        "Width of the chat entry box, in pixels. Applies once the box has been moved.")
    width:SetPoint("TOPLEFT", hideBorder, "BOTTOMLEFT", 6, -30)

    local anchorLabel = CreateLabel(section, "Resize Anchor (Determines growth direction):")
    anchorLabel:SetPoint("TOPLEFT", width, "BOTTOMLEFT", 0, -20)

    local anchorDropdown = CreateDBChoiceDropdown(section, 120, {
        { text = "LEFT", value = "LEFT" },
        { text = "CENTER", value = "CENTER" },
        { text = "RIGHT", value = "RIGHT" },
    }, "chatEditBoxAnchor", ApplyEditBox)
    anchorDropdown:SetPoint("TOPLEFT", anchorLabel, "BOTTOMLEFT", 0, -5)
    W.AttachHover(anchorDropdown, { top = anchorLabel, body = "Which part of the chat entry box stays in place when its width changes: Left grows it to the right, Right grows it to the left, and Center grows it both ways." })

    local extendPane = CreateDBCheckbox(section, "Extend Default Chat Pane (fills the space left for the chat entry box)", "extendDefaultChatPane",
        "Stretches the main chat window down over the strip the game keeps free for the chat entry box.",
        function() addon:UpdateChatPaneExtend() end)
    extendPane:SetPoint("TOPLEFT", anchorLabel, "BOTTOMLEFT", -6, -44) -- -6 lines it up with the checkboxes above
    if not addon:IsFeatureSupported("chatPaneExtend") then
        DropLastRow(page, entryBoxSection, extendPane, 34)
    end

    -- Chat frame buttons
    section, title = CreateSection(page, "Chat Frame Buttons", "Hide the minimize button, background and borders on chat frames.", 200)
    local buttonSection = section
    local function ApplyButtons() addon:UpdateChatButtons() end

    local hideButtonFrame = CreateDBCheckbox(section, "Hide Button Background, Border & Minimize", "hideChatButtonFrameBackground",
        "Hides the background and border behind the buttons beside the chat window, and the minimize button.", ApplyButtons)
    hideButtonFrame:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)

    local hideMenu = CreateDBCheckbox(section, "Hide Chat Menu Button", "hideChatFrameMenuButton",
        "Hides the chat menu button beside the chat window.", ApplyButtons)
    hideMenu:SetPoint("TOPLEFT", hideButtonFrame, "BOTTOMLEFT", 0, -4)

    local hideChannel = CreateDBCheckbox(section, "Hide Chat Channel Button", "hideChatFrameChannelButton",
        "Hides the chat channels button beside the chat window.", ApplyButtons)
    hideChannel:SetPoint("TOPLEFT", hideMenu, "BOTTOMLEFT", 0, -4)

    local hideQuickJoin = CreateDBCheckbox(section, "Hide Social Button (Quick Join)", "hideQuickJoinToastButton",
        "Hides the social (Quick Join) button beside the chat window.", ApplyButtons)
    hideQuickJoin:SetPoint("TOPLEFT", hideChannel, "BOTTOMLEFT", 0, -4)

    local buttonsOnRight = CreateDBCheckbox(section, "Move Buttons to Right Side of Chat", "chatButtonsOnRight",
        "Moves the chat window's buttons to its right side.", function() addon:UpdateChatButtonSide() end)
    buttonsOnRight:SetPoint("TOPLEFT", hideQuickJoin, "BOTTOMLEFT", 0, -4)
    if not addon:IsFeatureSupported("chatButtonSide") then
        DropLastRow(page, buttonSection, buttonsOnRight, 30)
    end

    -- Chat tabs
    section, title = CreateSection(page, "Chat Tabs", "Control visibility of the tabs above chat frames.", 110)
    local function ApplyTabs() addon:UpdateChatTabs() end

    local hideTabs = CreateDBCheckbox(section, "Hide Chat Tabs", "hideChatTabs",
        "Hides the tabs above each chat window.", ApplyTabs)
    hideTabs:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)

    local showTabsOnHover = CreateDBCheckbox(section, "Show Chat Tabs on Hover", "showChatTabsOnHover",
        "While chat tabs are hidden, shows them again when you mouse over the chat window. Needs Hide Chat Tabs.", ApplyTabs)
    showTabsOnHover:SetPoint("TOPLEFT", hideTabs, "BOTTOMLEFT", 16, -6)
    DependOn(hideTabs, { showTabsOnHover })

    -- Chat text font, per window
    section, title = CreateSection(page, "Chat Text Font", "Change the typeface and size of the text in each chat window.", 270)
    local selectedWindow = 1
    local RefreshFontControls

    local windowLabel = CreateLabel(section, "Chat Window")
    windowLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -14)

    -- Options are rebuilt each time it opens, so new and renamed windows are listed
    local windowDropdown = W.CreateChoiceDropdown(section, 210,
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
            RefreshFontControls()
        end)
    windowDropdown:SetPoint("TOPLEFT", windowLabel, "BOTTOMLEFT", 0, -2)
    W.AttachHover(windowDropdown, { top = windowLabel, body = "The chat window whose font the settings below change. Each window keeps its own." })

    local fontLabel = CreateLabel(section, "Typeface")
    fontLabel:SetPoint("TOPLEFT", windowLabel, "BOTTOMLEFT", 0, -46)

    local fontDropdown = CreateFontDropdown(section,
        function() return addon:GetChatFontOverride(selectedWindow).font end,
        function(path) addon:SetChatFontOverride(selectedWindow, "font", path) end)
    fontDropdown:SetPoint("TOPLEFT", fontLabel, "BOTTOMLEFT", 0, -2)
    W.AttachHover(fontDropdown, { top = fontLabel, body = "Typeface for the text in the selected chat window." })

    local sizeSlider = W.CreateSlider(section, {
        label = "Font Size", min = 8, max = 32, step = 1, width = 300,
        value = addon:GetChatFontSize(selectedWindow),
        onChange = function(value) addon:SetChatFontOverride(selectedWindow, "size", value) end,
    })
    sizeSlider:SetPoint("TOPLEFT", fontLabel, "BOTTOMLEFT", 0, -62)
    W.AttachHover(sizeSlider, { body = "Size of the text in the selected chat window." })

    -- Shows the selected window's current font and size
    function RefreshFontControls()
        windowDropdown:Refresh()
        fontDropdown:Refresh()
        sizeSlider:SetValue(addon:GetChatFontSize(selectedWindow), true)
    end

    local resetFont = CreateButton(section, "Reset This Window", 160, function()
        addon:ResetChatFont(selectedWindow)
        RefreshFontControls()
    end)
    resetFont:SetPoint("TOPLEFT", sizeSlider, "BOTTOMLEFT", 0, -26)

    section:SetScript("OnShow", RefreshFontControls)
    RefreshFontControls()
end

-- ============================================================================
-- Speed panel
-- ============================================================================

local function BuildSpeedPage(page)
    local section, title
    local function ApplySpeedPanel() addon:UpdateSpeedPanel() end

    section, title = CreateSection(page, "Speed Panel", "Displays your current movement speed.", 185)

    local enabled = CreateDBCheckbox(section, "Enable Speed Panel", "speedPanelEnabled",
        "Shows a small panel with your current movement speed.", ApplySpeedPanel)
    enabled:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)

    local locked = CreateDBCheckbox(section, "Lock Panel Position", "speedPanelLocked",
        "Stops the speed panel from being dragged. Unlock it to move it.", ApplySpeedPanel)
    locked:SetPoint("TOPLEFT", enabled, "BOTTOMLEFT", 0, -12)

    local reset = CreateButton(section, "Reset Position", 120, function()
        addon:ResetSettings({ "speedPanelPosition" })
        ApplySpeedPanel()
    end, "Puts the speed panel back in its starting place, below the middle of the screen.")
    reset:SetPoint("TOPLEFT", locked, "BOTTOMLEFT", 0, -16)

    local info = CreateLabel(section, "Drag the panel to move it when unlocked.")
    info:SetPoint("TOPLEFT", reset, "BOTTOMLEFT", 0, -16)
    info:SetWidth(300)
    info:SetJustifyH("LEFT")

    DependOn(enabled, { locked, reset })

    -- Appearance
    section, title = CreateSection(page, "Appearance", "Font, colors, background and border of the speed panel.", 460)

    -- Dropdown over a list of { key, name } options
    local function CreateOptionDropdown(options, dbKey)
        local choices = {}
        for i, option in ipairs(options) do
            choices[i] = { text = option.name, value = option.key }
        end
        return CreateDBChoiceDropdown(section, 210, choices, dbKey, ApplySpeedPanel)
    end

    local fontLabel = CreateLabel(section, "Typeface")
    fontLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -14)
    local fontDropdown = CreateDBFontDropdown(section, "speedPanelFont", ApplySpeedPanel)
    fontDropdown:SetPoint("TOPLEFT", fontLabel, "BOTTOMLEFT", 0, -2)
    W.AttachHover(fontDropdown, { top = fontLabel, body = "Typeface for the speed panel's text." })

    local outlineLabel = CreateLabel(section, "Outline")
    outlineLabel:SetPoint("TOPLEFT", fontLabel, "BOTTOMLEFT", 0, -46)
    local outlineDropdown = CreateOptionDropdown(addon:GetSpeedPanelOutlineOptions(), "speedPanelFontOutline")
    outlineDropdown:SetPoint("TOPLEFT", outlineLabel, "BOTTOMLEFT", 0, -2)
    W.AttachHover(outlineDropdown, { top = outlineLabel, body = "Outline drawn around the speed panel's text." })

    local sizeSlider = CreateDBSlider(section, "speedPanelFontSize",
        { label = "Font Size", min = 8, max = 40, step = 1, width = 300, apply = ApplySpeedPanel },
        "Size of the speed panel's text.")
    sizeSlider:SetPoint("TOPLEFT", outlineLabel, "BOTTOMLEFT", 0, -62)

    local textColor = CreateColorSwatch(section, "Text Color", "speedPanelTextColor", ApplySpeedPanel)
    textColor:SetPoint("TOPLEFT", sizeSlider, "BOTTOMLEFT", 0, -28)

    local backgroundLabel = CreateLabel(section, "Background")
    backgroundLabel:SetPoint("TOPLEFT", textColor, "BOTTOMLEFT", 0, -18)
    local backgroundDropdown = CreateOptionDropdown(addon:GetSpeedPanelBackgroundOptions(), "speedPanelBackgroundKey")
    backgroundDropdown:SetPoint("TOPLEFT", backgroundLabel, "BOTTOMLEFT", 0, -2)
    W.AttachHover(backgroundDropdown, { top = backgroundLabel, body = "Texture filling the speed panel's background. Its color is set below." })

    local backgroundColor = CreateColorSwatch(section, "Background Color / Opacity", "speedPanelBackgroundColor", ApplySpeedPanel)
    backgroundColor:SetPoint("TOPLEFT", backgroundLabel, "BOTTOMLEFT", 0, -46)

    local borderLabel = CreateLabel(section, "Border")
    borderLabel:SetPoint("TOPLEFT", backgroundColor, "BOTTOMLEFT", 0, -18)
    local borderDropdown = CreateOptionDropdown(addon:GetSpeedPanelBorderOptions(), "speedPanelBorderKey")
    borderDropdown:SetPoint("TOPLEFT", borderLabel, "BOTTOMLEFT", 0, -2)
    W.AttachHover(borderDropdown, { top = borderLabel, body = "Border drawn around the speed panel. Its color is set below." })

    local borderColor = CreateColorSwatch(section, "Border Color (shown when locked)", "speedPanelBorderColor", ApplySpeedPanel)
    borderColor:SetPoint("TOPLEFT", borderLabel, "BOTTOMLEFT", 0, -46)
end

-- ============================================================================
-- Cooldowns
-- ============================================================================

local function BuildCooldownPage(page)
    local section, title = CreateSection(page, "Cooldown Timer at Mouse", "Shows the time remaining beside the cursor when you press a spell that is still on cooldown.", 380, "cooldownAtMouse")
    local function ApplyCooldown() addon:UpdateCooldownAtMouse() end

    local enabled = CreateDBCheckbox(section, "Show Cooldown Timer at Mouse", "cooldownAtMouseEnabled",
        "When you press a spell that's still on cooldown, shows the time left beside your cursor.", ApplyCooldown)
    enabled:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)

    local duration = CreateDBSlider(section, "cooldownAtMouseDuration",
        { label = "Duration (s)", min = 1, max = 10, step = 0.5, width = 200, decimals = 1 },
        "How long the timer stays beside the cursor, in seconds.")
    duration:SetPoint("TOPLEFT", enabled, "BOTTOMLEFT", 0, -28)

    local offset = CreateDBSlider(section, "cooldownAtMouseOffset",
        { label = "Offset Distance", min = 0, max = 300, step = 1, width = 300 },
        "How far from the cursor the timer appears, in pixels.")
    offset:SetPoint("TOPLEFT", duration, "BOTTOMLEFT", 0, -36)

    local angle = CreateDBSlider(section, "cooldownAtMouseAngle",
        { label = "Offset Rotation (0 = above)", min = 0, max = 355, step = 5, width = 300 },
        "Which direction from the cursor the timer appears, in degrees clockwise from straight above: 90 is to the right, 180 below.")
    angle:SetPoint("TOPLEFT", offset, "BOTTOMLEFT", 0, -36)

    local size = CreateDBSlider(section, "cooldownAtMouseFontSize",
        { label = "Font Size", min = 8, max = 72, step = 1, width = 300, apply = ApplyCooldown },
        "Size of the cooldown timer text.")
    size:SetPoint("TOPLEFT", angle, "BOTTOMLEFT", 0, -36)

    local fontLabel = CreateLabel(section, "Typeface")
    fontLabel:SetPoint("TOPLEFT", size, "BOTTOMLEFT", 0, -24)
    local fontDropdown = CreateDBFontDropdown(section, "cooldownAtMouseFont", ApplyCooldown)
    fontDropdown:SetPoint("TOPLEFT", fontLabel, "BOTTOMLEFT", 0, -2)
    W.AttachHover(fontDropdown, { top = fontLabel, body = "Typeface for the cooldown timer." })

    DependOn(enabled, { duration, offset, angle, size, fontDropdown, fontLabel })
end

-- ============================================================================
-- Combat text
-- ============================================================================

-- A section with a slider per damage number setting in `group`, then a reset button. The
-- sliders show the live CVar values, re-read whenever the section is shown, rather than a
-- saved copy (see DamageNumbers.lua).
local function CreateDamageNumberSection(page, group, titleText, descriptionText, featureID)
    local settings = addon:GetDamageNumberSettings(group)
    local section, title = CreateSection(page, titleText, descriptionText, 80 + #settings * 56, featureID)

    local sliders = {}
    local anchor, gap = title, -28
    for _, setting in ipairs(settings) do
        local key = setting.key
        local slider = W.CreateSlider(section, {
            label = setting.label, min = setting.min, max = setting.max, step = setting.step,
            decimals = setting.decimals, width = 300,
            value = addon:GetDamageNumberSetting(key),
            onChange = function(value) addon:SetDamageNumberSetting(key, value) end,
        })
        slider:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, gap)
        W.AttachHover(slider, { body = setting.tooltip })
        sliders[key] = slider
        anchor, gap = slider, -36
    end

    local function Refresh()
        for key, slider in pairs(sliders) do
            slider:SetValue(addon:GetDamageNumberSetting(key), true)
        end
    end

    local reset = CreateButton(section, "Reset to Defaults", 160, function()
        addon:ResetDamageNumberSettings(group)
        Refresh()
    end, "Puts the settings in this section back to the game's defaults.")
    reset:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -26)

    section:SetScript("OnShow", Refresh)
end

local function BuildCombatTextPage(page)
    CreateDamageNumberSection(page, "position", "Damage Number Position", "Move the damage numbers above enemies higher or lower.", "damageNumberPosition")
    CreateDamageNumberSection(page, "spread", "Damage Number Movement", "Control how far damage numbers rise, drift and scatter.", "damageNumberSpread")

    -- Saved in GarageUITweaksDB, unlike the sections above (see SelfCombatText.lua)
    local section, title = CreateSection(page, "Self Combat Text Position", "Move the scrolling text for things that happen to you, such as damage taken and heals received.", 256, "selfCombatText")
    local function ApplySelfCombatText() addon:UpdateSelfCombatText() end

    local offsetX = CreateDBSlider(section, "selfCombatTextOffsetX",
        { label = "Horizontal Offset", min = -1000, max = 1000, step = 5, width = 300, apply = ApplySelfCombatText },
        "Moves your scrolling combat text left (negative) or right (positive).")
    offsetX:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -28)

    local offsetY = CreateDBSlider(section, "selfCombatTextOffsetY",
        { label = "Vertical Offset", min = -1000, max = 1000, step = 5, width = 300, apply = ApplySelfCombatText },
        "Moves your scrolling combat text down (negative) or up (positive).")
    offsetY:SetPoint("TOPLEFT", offsetX, "BOTTOMLEFT", 0, -36)

    local travel = CreateDBSlider(section, "selfCombatTextTravel",
        { label = "Travel Distance (%)", min = 25, max = 400, step = 5, width = 300 },
        "How far your combat text scrolls before it fades, as a percentage of the game's distance. It takes the same time either way, so a longer distance also scrolls faster. Applies to text that starts after the change.")
    travel:SetPoint("TOPLEFT", offsetY, "BOTTOMLEFT", 0, -36)

    local reset = CreateButton(section, "Reset to Defaults", 160, function()
        addon:ResetSettings({ "selfCombatTextOffsetX", "selfCombatTextOffsetY", "selfCombatTextTravel" })
        offsetX:SetValue(addon.db.selfCombatTextOffsetX, true)
        offsetY:SetValue(addon.db.selfCombatTextOffsetY, true)
        travel:SetValue(addon.db.selfCombatTextTravel, true)
        ApplySelfCombatText()
    end, "Puts your scrolling combat text back where the game places it, at the game's travel distance.")
    reset:SetPoint("TOPLEFT", travel, "BOTTOMLEFT", 0, -26)
end

-- ============================================================================
-- Nameplates
-- ============================================================================

local function BuildNameplatePage(page)
    local section, title = CreateSection(page, "Friendly Simplified Names", "Render readable names above simplified friendly player nameplates.", 590)
    local function ApplyNames() addon:UpdateFriendlyNameplates() end

    -- Every control in this section shares the title's left edge
    local enabled = CreateDBCheckbox(section, "Enable Friendly Name Rendering", "nameplateFriendlyNamesEnabled",
        "Draws a readable name above friendly players' simplified nameplates.", ApplyNames)
    enabled:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)

    local showTitle = CreateDBCheckbox(section, "Show Title", "nameplateFriendlyNamesShowTitle",
        "Includes the player's title in their name.", ApplyNames)
    showTitle:SetPoint("TOPLEFT", enabled, "BOTTOMLEFT", 0, -4)

    local showGuild = CreateDBCheckbox(section, "Show Guild Name", "nameplateFriendlyNamesShowGuild",
        "Also shows the player's guild name.", ApplyNames)
    showGuild:SetPoint("TOPLEFT", showTitle, "BOTTOMLEFT", 0, -4)

    local classColor = CreateDBCheckbox(section, "Use Class Colors on Friendly Names", "nameplateUseClassColorForFriendlyPlayerUnitNames",
        "Colors friendly player names by class.", function() addon:UpdateFriendlyClassColor() end)
    classColor:SetPoint("TOPLEFT", showGuild, "BOTTOMLEFT", 0, -4)

    local lastCheckbox = classColor
    if addon:IsFeatureSupported("simplifiedNameplateTypes") then
        local fullInInstances = CreateDBCheckbox(section, "Use Default Friendly Nameplates in Instances", "nameplateFullFriendlyInInstances",
            "Addons can't draw on friendly nameplates in dungeons, raids and scenarios, so simplified plates show no names there. This turns simplified friendly player nameplates off while you are inside one and back on when you leave.",
            function() addon:UpdateInstanceSimplifiedNameplates() end)
        fullInInstances:SetPoint("TOPLEFT", classColor, "BOTTOMLEFT", 0, -4)
        lastCheckbox = fullInInstances
    end

    local scale = CreateDBSlider(section, "nameplateFriendlyScale",
        { label = "Nameplate Scale (%)", min = 0.5, max = 3.0, step = 0.05, width = 220, scale = 100, apply = ApplyNames },
        "Size of friendly nameplates, where 100% is their normal size.")
    scale:SetPoint("TOPLEFT", lastCheckbox, "BOTTOMLEFT", 0, -28)

    local fontLabel = CreateLabel(section, "Font")
    fontLabel:SetPoint("TOPLEFT", scale, "BOTTOMLEFT", 0, -24)
    local fontDropdown = CreateDBFontDropdown(section, "nameplateFriendlyNameFont", ApplyNames)
    fontDropdown:SetPoint("TOPLEFT", fontLabel, "BOTTOMLEFT", 0, -2)
    W.AttachHover(fontDropdown, { top = fontLabel, body = "Typeface for friendly names. Lists fonts from LibSharedMedia and FontMagic too, when they're installed." })

    local color = CreateColorSwatch(section, "Color", "nameplateFriendlyNameColor", ApplyNames)
    color:SetPoint("LEFT", fontDropdown, "RIGHT", 26, 0)

    local outlineLabel = CreateLabel(section, "Outline Type")
    outlineLabel:SetPoint("TOPLEFT", fontLabel, "BOTTOMLEFT", 0, -46)
    local outlineDropdown = CreateDBChoiceDropdown(section, 160, {
        { text = "None", value = "NONE" },
        { text = "Outline", value = "OUTLINE" },
        { text = "Thick Outline", value = "THICKOUTLINE" },
    }, "nameplateFriendlyNameOutline", ApplyNames)
    outlineDropdown:SetPoint("TOPLEFT", outlineLabel, "BOTTOMLEFT", 0, -2)
    W.AttachHover(outlineDropdown, { top = outlineLabel, body = "Outline drawn around friendly names." })

    local size = CreateDBSlider(section, "nameplateFriendlyNameSize",
        { label = "Font Size", min = 8, max = 64, step = 1, width = 220, apply = ApplyNames },
        "Size of friendly names.")
    size:SetPoint("TOPLEFT", outlineLabel, "BOTTOMLEFT", 0, -62)

    local offsetX = CreateDBSlider(section, "nameplateFriendlyNameOffsetX",
        { label = "X Offset", min = -100, max = 100, step = 1, width = 220, apply = ApplyNames },
        "Moves friendly names left or right of the nameplate's center.")
    offsetX:SetPoint("TOPLEFT", size, "BOTTOMLEFT", 0, -30)

    local offsetY = CreateDBSlider(section, "nameplateFriendlyNameOffsetY",
        { label = "Y Offset", min = -100, max = 100, step = 1, width = 220, apply = ApplyNames },
        "Moves friendly names up or down from the nameplate.")
    offsetY:SetPoint("TOPLEFT", offsetX, "BOTTOMLEFT", 0, -30)

    local justifyLabel = CreateLabel(section, "Justification")
    justifyLabel:SetPoint("TOPLEFT", offsetY, "BOTTOMLEFT", 0, -22)
    local justifyDropdown = CreateDBChoiceDropdown(section, 120, {
        { text = "Left", value = "LEFT" },
        { text = "Center", value = "CENTER" },
        { text = "Right", value = "RIGHT" },
    }, "nameplateFriendlyNameJustify", ApplyNames)
    justifyDropdown:SetPoint("TOPLEFT", justifyLabel, "BOTTOMLEFT", 0, -2)
    W.AttachHover(justifyDropdown, { top = justifyLabel, body = "Which edge of the name area friendly names line up against." })
end

-- ============================================================================
-- Background panel
-- ============================================================================

local BACKGROUND_PANEL_POSITION_KEYS = {
    "backgroundPanelWidth", "backgroundPanelHeight", "backgroundPanelX", "backgroundPanelY",
    "backgroundPanelAnchor", "backgroundPanelForceWidth", "backgroundPanelForceHeight",
}

local function BuildBackgroundPage(page)
    local section, title = CreateSection(page, "Background Panel", "Configure the global background panel.", 470)
    local RefreshControls
    local function ApplyPanel() addon:UpdateBackgroundPanel() end
    -- Also refreshes the size sliders, which follow the forced dimensions
    local function ApplyPanelAndControls()
        ApplyPanel()
        RefreshControls()
    end

    local enabled = CreateDBCheckbox(section, "Enable Background Panel", "backgroundPanelEnabled",
        "Shows a colored panel you can size and place anywhere, for example behind other parts of your UI.", ApplyPanel)
    enabled:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)

    local locked = CreateDBCheckbox(section, "Lock Panel Position", "backgroundPanelLocked",
        "Stops the background panel from being dragged or resized.", ApplyPanel)
    locked:SetPoint("TOPLEFT", enabled, "BOTTOMLEFT", 0, -8)

    local forceWidth = CreateDBCheckbox(section, "Force Screen Width", "backgroundPanelForceWidth",
        "Makes the background panel exactly as wide as the screen.", ApplyPanelAndControls)
    forceWidth:SetPoint("TOPLEFT", locked, "BOTTOMLEFT", 0, -8)

    local forceHeight = CreateDBCheckbox(section, "Force Screen Height", "backgroundPanelForceHeight",
        "Makes the background panel exactly as tall as the screen.", ApplyPanelAndControls)
    forceHeight:SetPoint("TOPLEFT", forceWidth, "BOTTOMLEFT", 0, -8)

    local color = CreateColorSwatch(section, "Panel Color / Alpha", "backgroundPanelColor", ApplyPanel)
    color:SetPoint("TOPLEFT", forceHeight, "BOTTOMLEFT", 0, -16)

    local dimensionsLabel = CreateLabel(section, "Dimensions", "GameFontHighlight")
    dimensionsLabel:SetPoint("TOPLEFT", color, "BOTTOMLEFT", 0, -16)

    -- Width and height; the most is the screen's size, set whenever the page opens
    local function CreateDimensionSlider(dbKey, label, anchorTo)
        local slider = W.CreateSlider(section, {
            label = label, min = 16, max = 4096, step = 1, width = 300,
            value = addon.db[dbKey],
            onChange = function(value)
                value = math.max(16, math.floor(value + 0.5))
                if addon.db[dbKey] ~= value then
                    addon.db[dbKey] = value
                    ApplyPanelAndControls()
                end
            end,
        })
        slider:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, -30)
        W.AttachHover(slider, { body = label .. " of the background panel, in pixels, up to the size of the screen. Fixed to the screen's " .. label:lower() .. " while Force Screen " .. label .. " is on." })
        return slider
    end

    local widthSlider = CreateDimensionSlider("backgroundPanelWidth", "Width", dimensionsLabel)
    local heightSlider = CreateDimensionSlider("backgroundPanelHeight", "Height", widthSlider)

    local anchorLabel = CreateLabel(section, "Anchor Point", "GameFontHighlight")
    anchorLabel:SetPoint("TOPLEFT", heightSlider, "BOTTOMLEFT", 0, -24)

    local anchorOptions = {}
    for i, anchor in ipairs({ "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }) do
        anchorOptions[i] = { text = anchor, value = anchor }
    end
    -- Just switches the anchor; X and Y aren't converted, so the panel may jump. Drag it to fix.
    local anchorDropdown = CreateDBChoiceDropdown(section, 120, anchorOptions, "backgroundPanelAnchor", ApplyPanel)
    anchorDropdown:SetPoint("LEFT", anchorLabel, "RIGHT", 10, 0)
    W.AttachHover(anchorDropdown, { top = anchorLabel, body = "The point of the screen the panel's position is measured from. Changing it can make the panel jump; drag it back into place." })

    local reset = CreateButton(section, "Reset Position", 120, function()
        addon:ResetSettings(BACKGROUND_PANEL_POSITION_KEYS)
        ApplyPanelAndControls()
    end, "Puts the panel back in the middle of the screen at its starting size.")
    reset:SetPoint("TOPLEFT", anchorLabel, "BOTTOMLEFT", 0, -30)

    -- Shows the panel's real size (the screen's when forced, the dragged one mid-drag)
    function RefreshControls()
        if not widthSlider:IsVisible() then
            return
        end
        local db = addon.db

        local width, height = addon:GetBackgroundPanelDragSize()
        if not width then
            width, height = addon:GetBackgroundPanelSize()
        end
        width, height = math.floor(width + 0.5), math.floor(height + 0.5)
        local screenWidth, screenHeight = math.floor(GetScreenWidth() + 0.5), math.floor(GetScreenHeight() + 0.5)

        widthSlider:SetMinMaxValues(16, math.max(screenWidth, width))
        widthSlider:SetValue(width, true)
        heightSlider:SetMinMaxValues(16, math.max(screenHeight, height))
        heightSlider:SetValue(height, true)

        widthSlider:SetEnabled(not db.backgroundPanelForceWidth)
        heightSlider:SetEnabled(not db.backgroundPanelForceHeight)

        enabled:SetChecked(db.backgroundPanelEnabled)
        locked:SetChecked(db.backgroundPanelLocked)
        forceWidth:SetChecked(db.backgroundPanelForceWidth)
        forceHeight:SetChecked(db.backgroundPanelForceHeight)
        anchorDropdown:Refresh()
    end

    -- Dragging the panel changes its size and position while this page is open
    addon.RefreshBackgroundPanelSettings = function() RefreshControls() end
    page.frame:SetScript("OnShow", RefreshControls)
end

-- ============================================================================
-- The panel
-- ============================================================================

local PAGES = {
    { id = "general", title = "General Tweaks", description = "Core quality-of-life improvements and shared behavior.", build = BuildGeneralPage },
    { id = "frameadjustments", title = "Frame Tweaks", description = "Adjust frame strata and status tracking positioning.", build = BuildFramePage },
    { id = "chat", title = "Chat Tweaks", description = "Customize chat behavior and chat frame controls.", build = BuildChatPage },
    { id = "speed", title = "Speed Panel Tweaks", description = "Configure movement speed display options.", build = BuildSpeedPage },
    { id = "cooldowns", title = "Cooldown Tweaks", description = "Configure cooldown display options.", build = BuildCooldownPage },
    { id = "combattext", title = "Combat Text Tweaks", description = "Adjust where damage numbers and your own scrolling combat text appear.", build = BuildCombatTextPage },
    { id = "nameplates", title = "Nameplate Tweaks", description = "Configure friendly nameplate appearance.", build = BuildNameplatePage },
    { id = "background", title = "Background Panel Tweaks", description = "Background panel and visual backdrop options.", build = BuildBackgroundPage },
}

function addon:CreateSettingsPanel()
    if self.settingsCategory then
        return
    end

    local panel = CreateFrame("Frame", "GarageUITweaksOptionsPanel", UIParent)

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(PANEL_NAME)

    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetText("Configure your UI tweaks below.")

    local overview = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    overview:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -12)
    overview:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
    overview:SetJustifyH("LEFT")
    overview:SetText("Expand Garage UI Tweaks in the Settings list to open individual tweak pages.")

    local category = Settings.RegisterCanvasLayoutCategory(panel, PANEL_NAME)
    Settings.RegisterAddOnCategory(category)
    self.settingsCategory = category
    self.settingsSubcategories = {}

    -- Pages with nothing this client supports are left out of the list
    for _, info in ipairs(PAGES) do
        local page = CreateSettingsPage(info.id, info.title, info.description)
        info.build(page)
        if page.visibleSections > 0 then
            self.settingsSubcategories[info.id] = Settings.RegisterCanvasLayoutSubcategory(category, page.frame, page.name)
        end
    end
end

function addon:OpenSettings()
    self:CreateSettingsPanel()
    local category = self.settingsSubcategories.general or self.settingsCategory
    Settings.OpenToCategory(category:GetID())
end

local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_LOGIN")
loginFrame:SetScript("OnEvent", function()
    addon:CreateSettingsPanel()
end)
