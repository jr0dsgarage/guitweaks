---@diagnostic disable: undefined-global
-- Garage UI Tweaks - Chat Tweaks
-- The chat entry box's position, width and border; hiding the buttons beside the chat
-- window and moving them to its right side; per-window chat fonts; stretching the main
-- chat window over the entry box's strip; and hiding the chat tabs.
local addonName, addon = ...

function addon:UpdateChatTweaks()
    self:UpdateChatEditBox()
    self:UpdateChatButtons()
    self:UpdateChatButtonSide()
    self:UpdateChatFonts()
    self:UpdateChatPaneExtend()
    self:UpdateChatTabs()
end

-- ============================================================================
-- Chat entry box
-- ============================================================================
-- Left to Blizzard until it has been unlocked and dragged. From then on every window's box
-- sits at the saved spot, measured from the screen's center, at the chosen width. The
-- resize anchor is the part of the box that holds still when the width changes.

local editBoxHooked = false
local bordersHidden = false
local draggingBox

local function ForEachEditBox(func)
    for i = 1, NUM_CHAT_WINDOWS do
        local editBox = _G["ChatFrame" .. i .. "EditBox"]
        if editBox then
            func(editBox)
        end
    end
end

local function SetEditBoxBorderShown(editBox, shown)
    local name = editBox:GetName()
    for _, part in ipairs({ "Left", "Right", "Mid" }) do
        local texture = _G[name .. part]
        if texture then
            texture:SetShown(shown)
        end
    end
end

local function PlaceEditBox(editBox)
    local anchor = addon.db.chatEditBoxAnchor
    editBox:SetMovable(true)
    editBox:SetClampedToScreen(true)
    editBox:SetUserPlaced(true) -- discourages Blizzard from moving it back

    addon:RestoreFramePosition(editBox, "chatEditBoxPosition")
    -- Saved with another resize anchor: measure from the new one, leaving the box where it is
    if addon.db.chatEditBoxPosition.point ~= anchor and addon:AnchorToScreenCenter(editBox, anchor) then
        addon:SaveFramePosition(editBox, "chatEditBoxPosition")
    end
    editBox:SetWidth(addon.db.chatEditBoxWidth)
end

local QueueEditBoxUpdate = addon.NextFrameOnce(function() addon:UpdateChatEditBox() end)

local function OnEditBoxMouseDown(self, button)
    if addon.db.chatEditBoxUnlock and IsShiftKeyDown() and button == "LeftButton" then
        self:SetMovable(true)
        self:SetClampedToScreen(true)
        draggingBox = self
        self:StartMoving()
    end
end

local function OnEditBoxMouseUp(self)
    if draggingBox ~= self then
        return
    end
    self:StopMovingOrSizing()
    draggingBox = nil
    addon:AnchorToScreenCenter(self, addon.db.chatEditBoxAnchor)
    addon:SaveFramePosition(self, "chatEditBoxPosition")
    addon:UpdateChatEditBox()
end

local function HookEditBoxes()
    if editBoxHooked then
        return
    end
    editBoxHooked = true

    ForEachEditBox(function(editBox)
        editBox:HookScript("OnMouseDown", OnEditBoxMouseDown)
        editBox:HookScript("OnMouseUp", OnEditBoxMouseUp)
        -- Blizzard places the box again as it's shown for each window...
        editBox:HookScript("OnShow", QueueEditBoxUpdate)
    end)
    -- ...and when the chat type changes
    if ChatEdit_UpdateHeader then
        hooksecurefunc("ChatEdit_UpdateHeader", QueueEditBoxUpdate)
    end
end

function addon:UpdateChatEditBox()
    HookEditBoxes()

    local hideBorder = self.db.chatEditBoxHideBorder
    local placed = self.db.chatEditBoxPosition ~= nil
    ForEachEditBox(function(editBox)
        if hideBorder or bordersHidden then
            SetEditBoxBorderShown(editBox, not hideBorder)
        end
        if placed and editBox ~= draggingBox then
            PlaceEditBox(editBox)
        end
    end)
    bordersHidden = hideBorder
end

-- ============================================================================
-- Chat frame buttons
-- ============================================================================
-- Each option hides its buttons and keeps them hidden. Turning it off shows again only
-- what was showing when it was hidden, so Blizzard's own hiding (the minimize button of a
-- docked window, say) is left alone.

-- Parts of each window's button frame ("ChatFrame1ButtonFrame" .. part) the frame option hides
local BUTTON_FRAME_PARTS = {
    "Background", "MinimizeButton",
    "Top", "Bottom", "Left", "Right", "Middle", "TopLeft", "TopRight", "BottomLeft", "BottomRight",
    "TopTexture", "BottomTexture", "LeftTexture", "RightTexture", "MiddleTexture",
    "TopLeftTexture", "TopRightTexture", "BottomLeftTexture", "BottomRightTexture",
}

local wasShown = {} -- [region] = whether it was showing when an option hid it
local backdropColors = {} -- [button frame] = its backdrop colors, while the frame option clears them
local buttonsHooked = false

local function SetHiddenByOption(region, hide)
    if not region then
        return
    end
    if hide then
        if wasShown[region] == nil then
            wasShown[region] = region:IsShown()
        end
        region:Hide()
    elseif wasShown[region] ~= nil then
        region:SetShown(wasShown[region])
        wasShown[region] = nil
    end
end

local function SetBackdropCleared(frame, clear)
    if not (frame and frame.GetBackdrop and frame:GetBackdrop()) then
        return
    end
    if clear then
        backdropColors[frame] = backdropColors[frame] or { { frame:GetBackdropColor() }, { frame:GetBackdropBorderColor() } }
        frame:SetBackdropColor(0, 0, 0, 0)
        frame:SetBackdropBorderColor(0, 0, 0, 0)
    elseif backdropColors[frame] then
        frame:SetBackdropColor(unpack(backdropColors[frame][1]))
        frame:SetBackdropBorderColor(unpack(backdropColors[frame][2]))
        backdropColors[frame] = nil
    end
end

-- Blizzard shows these buttons again on its own; hide them straight back while the option is on
local function KeepHidden(button, dbKey)
    if button then
        button:HookScript("OnShow", function(self)
            if addon.db[dbKey] then
                wasShown[self] = true
                self:Hide()
            end
        end)
    end
end

function addon:UpdateChatButtons()
    if not buttonsHooked then
        KeepHidden(ChatFrameMenuButton, "hideChatFrameMenuButton")
        KeepHidden(ChatFrameChannelButton, "hideChatFrameChannelButton")
        KeepHidden(QuickJoinToastButton, "hideQuickJoinToastButton")
        buttonsHooked = true
    end

    local hideFrame = self.db.hideChatButtonFrameBackground
    for i = 1, NUM_CHAT_WINDOWS do
        local prefix = "ChatFrame" .. i .. "ButtonFrame"
        for _, part in ipairs(BUTTON_FRAME_PARTS) do
            SetHiddenByOption(_G[prefix .. part], hideFrame)
        end
        SetBackdropCleared(_G[prefix], hideFrame)
    end

    SetHiddenByOption(ChatFrameMenuButton, self.db.hideChatFrameMenuButton)
    SetHiddenByOption(ChatFrameChannelButton, self.db.hideChatFrameChannelButton)
    SetHiddenByOption(QuickJoinToastButton, self.db.hideQuickJoinToastButton)
end

-- ============================================================================
-- Extend the main chat window over the entry box's strip
-- ============================================================================
-- Blizzard leaves a strip under the main chat frame for the chat entry box. Once the entry
-- box has been moved elsewhere, this stretches the frame down over that strip.
--
-- Edit Mode owns this frame: it re-applies its saved position and its saved height at
-- different moments, so nudging the frame from wherever it currently is drifts. The
-- target is always computed from Edit Mode's saved values instead, which makes applying
-- it any number of times give the same result.
local EXTEND_EDIT_BOX_GAP = 2 -- pixels between the chat frame and its entry box
local extendHooked = false
local extendAmount = 0 -- how far the frame is currently stretched; 0 when it isn't

-- Edit Mode keeps the frame clamped a strip's height above the bottom of the screen (the
-- strip belongs to the entry box), which shoves an extended frame back up. While extended,
-- the bottom clamp is relaxed by the same amount so the frame may sit in that strip.
local blizzardClampInsets -- the insets Blizzard last asked for: { left, right, top, bottom }
local clampAdjusting = false

local function ApplyChatPaneClamp(chatFrame)
    if not blizzardClampInsets then
        return
    end

    local left, right, top, bottom = unpack(blizzardClampInsets)
    clampAdjusting = true
    chatFrame:SetClampRectInsets(left, right, top, bottom + extendAmount)
    clampAdjusting = false
end

local function GetEditBoxStripHeight(chatFrame)
    local editBox = chatFrame.editBox or _G[chatFrame:GetName() .. "EditBox"]
    local height = editBox and editBox:GetHeight() or 0
    if height <= 0 then
        height = 32
    end
    return height + EXTEND_EDIT_BOX_GAP
end

-- The height Edit Mode has saved for the frame, read the same way Blizzard reads it
local function GetEditModeChatHeight(chatFrame)
    local hundreds = Enum.EditModeChatFrameSetting.HeightHundreds
    local tensAndOnes = Enum.EditModeChatFrameSetting.HeightTensAndOnes
    if not chatFrame:HasSetting(hundreds) or not chatFrame:HasSetting(tensAndOnes) then
        return nil
    end
    return math.floor(chatFrame:GetSettingValue(hundreds, true) * 100 + chatFrame:GetSettingValue(tensAndOnes, true))
end

local function ApplyChatPaneExtend()
    local chatFrame = ChatFrame1
    local anchor = chatFrame and chatFrame.systemInfo and chatFrame.systemInfo.anchorInfo
    if not anchor or not anchor.point then
        return -- Edit Mode hasn't laid the frame out yet
    end

    local baseHeight = GetEditModeChatHeight(chatFrame)
    if not baseHeight or baseHeight <= 0 then
        return
    end

    -- Not while Edit Mode is open: it saves whatever size the frame has when you edit it
    local amount = 0
    if addon.db.extendDefaultChatPane and not addon:IsEditModeActive() then
        amount = GetEditBoxStripHeight(chatFrame)
    end
    if amount == 0 and extendAmount == 0 then
        return -- never stretched this session; leave Blizzard's frame alone
    end
    extendAmount = amount
    ApplyChatPaneClamp(chatFrame) -- before moving, or the move is clamped away

    -- Keep the top edge where Edit Mode put it and move only the bottom edge
    local scale = chatFrame:GetScale()
    local x, y = anchor.offsetX / scale, anchor.offsetY / scale
    if anchor.point:find("BOTTOM") then
        y = y - amount
    elseif not anchor.point:find("TOP") then
        y = y - amount / 2
    end

    chatFrame:ClearAllPoints()
    chatFrame:SetPoint(anchor.point, anchor.relativeTo, anchor.relativePoint, x, y)
    chatFrame:SetHeight(baseHeight + amount)
end

-- Edit Mode applies position and size in separate steps; run once they have all finished
local QueueChatPaneExtend = addon.NextFrameOnce(ApplyChatPaneExtend)

function addon:UpdateChatPaneExtend()
    if not self:IsFeatureSupported("chatPaneExtend") then
        return
    end

    if not extendHooked then
        extendHooked = true
        local chatFrame = ChatFrame1

        blizzardClampInsets = { chatFrame:GetClampRectInsets() }
        hooksecurefunc(chatFrame, "SetClampRectInsets", function(frame, left, right, top, bottom)
            if clampAdjusting then
                return
            end
            blizzardClampInsets = { left or 0, right or 0, top or 0, bottom or 0 }
            ApplyChatPaneClamp(frame)
        end)

        -- Every time Edit Mode lays the frame out again (login, zoning, layout changes)
        hooksecurefunc(chatFrame, "UpdateSystem", QueueChatPaneExtend)
        hooksecurefunc(chatFrame, "UpdateSystemSettingHeight", QueueChatPaneExtend)
        -- Back to Blizzard's own size while Edit Mode is open, stretched again when it closes
        hooksecurefunc(EditModeManagerFrame, "EnterEditMode", ApplyChatPaneExtend)
        hooksecurefunc(EditModeManagerFrame, "ExitEditMode", QueueChatPaneExtend)

        local eventFrame = CreateFrame("Frame")
        eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        eventFrame:SetScript("OnEvent", QueueChatPaneExtend)
    end

    ApplyChatPaneExtend()
end

-- ============================================================================
-- Chat buttons on the right
-- ============================================================================
-- Blizzard picks the side from the chat frame's screen position and anchors the menu,
-- channel and social buttons to that button frame, so forcing its side moves them all.
local buttonSideHooked = false
local buttonSideForced = false

function addon:UpdateChatButtonSide()
    if not self:IsFeatureSupported("chatButtonSide") then
        return
    end

    if not buttonSideHooked then
        buttonSideHooked = true
        -- Blizzard re-evaluates the side on login, docking and dragging; put it back
        hooksecurefunc("FCF_SetButtonSide", function(chatFrame, buttonSide)
            if addon.db.chatButtonsOnRight and buttonSide ~= "right" then
                FCF_SetButtonSide(chatFrame, "right")
            end
        end)
    end

    if self.db.chatButtonsOnRight then
        buttonSideForced = true
        for _, frameName in ipairs(CHAT_FRAMES or {}) do
            local chatFrame = _G[frameName]
            if chatFrame and chatFrame.buttonFrame then
                FCF_SetButtonSide(chatFrame, "right")
            end
        end
    elseif buttonSideForced then
        buttonSideForced = false
        for _, frameName in ipairs(CHAT_FRAMES or {}) do
            local chatFrame = _G[frameName]
            if chatFrame and chatFrame.buttonFrame then
                FCF_UpdateButtonSide(chatFrame)
            end
        end
    end
end

-- ============================================================================
-- Chat text font
-- ============================================================================
-- Per-window typeface and size overrides, stored in db.chatFonts[windowID] = { font, size }.
local chatFontHooked = false
local chatFontOriginals = {} -- [windowID] = font file the window had before we touched it

local function ApplyChatFont(id)
    local chatFrame = _G["ChatFrame" .. id]
    if not chatFrame then
        return
    end

    local file, size, flags = chatFrame:GetFont()
    chatFontOriginals[id] = chatFontOriginals[id] or file

    local override = addon.db.chatFonts[id]
    if override then
        addon.SetFontOrFallback(chatFrame, override.font or file, override.size or size, flags, chatFontOriginals[id])
    end
end

function addon:UpdateChatFonts()
    if not chatFontHooked then
        chatFontHooked = true
        -- Blizzard re-applies its own font when a window is set up or its size is changed
        hooksecurefunc("FloatingChatFrame_Update", function(id)
            ApplyChatFont(id)
        end)
        hooksecurefunc("FCF_SetChatWindowFontSize", function(_, chatFrame)
            local id = (chatFrame or FCF_GetCurrentChatFrame()):GetID()
            ApplyChatFont(id)
        end)
    end

    for i = 1, NUM_CHAT_WINDOWS do
        ApplyChatFont(i)
    end
end

-- The windows currently in use (shown or docked as a tab)
function addon:GetChatWindowIDs()
    local ids = {}
    for i = 1, NUM_CHAT_WINDOWS do
        local _, _, _, _, _, _, shown, _, docked = GetChatWindowInfo(i)
        if i == 1 or shown or docked then
            table.insert(ids, i)
        end
    end
    return ids
end

function addon:GetChatWindowName(id)
    local name = GetChatWindowInfo(id)
    if not name or name == "" then
        name = "Chat " .. id
    end
    return name
end

function addon:GetChatFontOverride(id)
    return self.db.chatFonts[id] or {}
end

function addon:GetChatFontSize(id)
    local _, size = _G["ChatFrame" .. id]:GetFont()
    return math.floor((size or 14) + 0.5)
end

function addon:SetChatFontOverride(id, key, value)
    self.db.chatFonts[id] = self.db.chatFonts[id] or {}
    self.db.chatFonts[id][key] = value
    ApplyChatFont(id)
end

-- Back to the window's own typeface and the size chosen in Blizzard's chat menu
function addon:ResetChatFont(id)
    self.db.chatFonts[id] = nil

    local chatFrame = _G["ChatFrame" .. id]
    local file, size, flags = chatFrame:GetFont()
    local _, blizzardSize = GetChatWindowInfo(id)
    if not blizzardSize or blizzardSize <= 0 then
        blizzardSize = size
    end
    chatFrame:SetFont(chatFontOriginals[id] or file, blizzardSize, flags)
end

-- ============================================================================
-- Chat tabs
-- ============================================================================
local hookedTabs = {}
local tabsHooked = false
local tabsHidden = false -- true while we're keeping the tabs hidden
local tabsRevealed = false -- true while hover temporarily shows hidden tabs
local TAB_STRIP_HEIGHT = 30 -- how far above a chat frame counts as the tab area
local HOVER_POLL_INTERVAL = 0.1
local HOVER_HIDE_DELAY = 1 -- seconds the tabs stay after the mouse leaves

local function TabsShouldHide()
    return addon.db.hideChatTabs and not tabsRevealed
end

local function IsMouseOverChatArea()
    for _, frameName in ipairs(CHAT_FRAMES or {}) do
        local chatFrame = _G[frameName]
        if chatFrame and chatFrame:IsShown() and chatFrame:IsMouseOver(TAB_STRIP_HEIGHT, 0, 0, 0) then
            return true
        end
        local tab = _G[frameName .. "Tab"]
        if tab and tab:IsShown() and tab:IsMouseOver() then
            return true
        end
    end
    return false
end

-- A tab's right-click menu closes with its tab, so an open menu holds the tabs in place
local function IsContextMenuOpen()
    if Menu and Menu.GetManager then
        local manager = Menu.GetManager()
        if manager and manager.GetOpenMenu and manager:GetOpenMenu() then
            return true
        end
    end
    return DropDownList1 ~= nil and DropDownList1:IsShown()
end

local hoverWatcher = CreateFrame("Frame")
hoverWatcher:Hide()
local hoverElapsed = 0
local hoverLastOver = 0
hoverWatcher:SetScript("OnUpdate", function(_, elapsed)
    hoverElapsed = hoverElapsed + elapsed
    if hoverElapsed < HOVER_POLL_INTERVAL then return end
    hoverElapsed = 0

    local now = GetTime()
    local over = IsMouseOverChatArea()
    if over or (tabsRevealed and IsContextMenuOpen()) then
        hoverLastOver = now
        over = true
    elseif tabsRevealed and now - hoverLastOver < HOVER_HIDE_DELAY then
        -- Linger briefly so the mouse can leave and come back
        over = true
    end

    if over ~= tabsRevealed then
        tabsRevealed = over
        addon:UpdateChatTabs()
    end
end)

function addon:UpdateChatTabs()
    -- Temporary whisper/conversation windows create new tabs on the fly
    if not tabsHooked and FCF_OpenTemporaryWindow then
        hooksecurefunc("FCF_OpenTemporaryWindow", function()
            addon:UpdateChatTabs()
        end)
        tabsHooked = true
    end

    local hoverEnabled = self.db.hideChatTabs and self.db.showChatTabsOnHover
    hoverWatcher:SetShown(hoverEnabled)
    if not hoverEnabled then
        tabsRevealed = false
    end

    local hide = TabsShouldHide()
    if not hide and not tabsHidden then
        return -- not hidden, or already shown again: leave Blizzard's tabs alone
    end
    tabsHidden = hide

    for _, frameName in ipairs(CHAT_FRAMES or {}) do
        local tab = _G[frameName .. "Tab"]
        local chatFrame = _G[frameName]
        if tab then
            -- Blizzard re-shows tabs on dock updates / fades; keep them hidden while enabled
            if not hookedTabs[tab] then
                tab:HookScript("OnShow", function(self)
                    if TabsShouldHide() then
                        self:Hide()
                    end
                end)
                hookedTabs[tab] = true
            end

            if hide then
                tab:Hide()
            elseif chatFrame and (chatFrame:IsShown() or chatFrame.isDocked) then
                -- Only restore tabs Blizzard would normally be showing
                tab:Show()
            end
        end
    end

    if GeneralDockManagerOverflowButton and hide then
        GeneralDockManagerOverflowButton:Hide()
    elseif not hide and FCF_DockUpdate then
        FCF_DockUpdate()
    end
end
