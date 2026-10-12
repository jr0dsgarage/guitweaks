---@diagnostic disable: undefined-global
-- Garage UI Tweaks - Chat Tweaks
local addonName, addon = ...

local hookInstalled = false

-- Recalculate position to match the desired scaling anchor
local function EnforceAnchor(editBox, anchor, save)
    if not anchor then anchor = "CENTER" end
    
    local x = editBox:GetLeft()
    local y = editBox:GetTop()
    local w = editBox:GetWidth()
    local h = editBox:GetHeight()
    
    if not x or not y then return end -- Frame not visible/set yet
    
    editBox:ClearAllPoints()
    
    if anchor == "LEFT" then
        -- Keep Left edge same
        editBox:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
    elseif anchor == "RIGHT" then
        -- Keep Right edge same
        editBox:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", x + w, y)
    else -- CENTER
        -- Keep Center same
        editBox:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x + w/2, y - h/2)
    end
    
    if save then
        addon:SaveFramePosition(editBox, "chatEditBoxPosition")
    end
end

local function UpdateVisuals()
    -- Loop through all chat frames to ensure consistency across tabs
    for i = 1, NUM_CHAT_WINDOWS do
        local editBox = _G["ChatFrame"..i.."EditBox"]
        if editBox then
            -- Skip positioning logic if this specific box is currently being dragged by the user
            if not editBox.isMoving then
                -- Set user placed immediately to discourage Blizzard interference where possible
                editBox:SetUserPlaced(true)

                -- Restore Position first if needed
                addon:RestoreFramePosition(editBox, "chatEditBoxPosition")
                
                -- Apply Border
                local hide = addon.db.chatEditBoxHideBorder
                local texLeft = _G[editBox:GetName().."Left"]
                local texRight = _G[editBox:GetName().."Right"]
                local texMid = _G[editBox:GetName().."Mid"]
                
                if texLeft then texLeft:SetShown(not hide) end
                if texRight then texRight:SetShown(not hide) end
                if texMid then texMid:SetShown(not hide) end
                
                editBox:SetWidth(addon.db.chatEditBoxWidth or 450)
                
                -- When just updating visuals, we might want to ensure the anchor is correct so future width changes scale correctly
                if addon.db.chatEditBoxAnchor then
                    EnforceAnchor(editBox, addon.db.chatEditBoxAnchor, false) 
                end
            end
        end
    end
end

function addon:InitChatTweaks()
    if hookInstalled then 
        UpdateVisuals()
        addon:UpdateChatButtonBackgrounds()
        return 
    end
    
    for i = 1, NUM_CHAT_WINDOWS do
        local editBox = _G["ChatFrame"..i.."EditBox"]
        if editBox then
            -- Enable movement capabilities
            editBox:SetMovable(true)
            editBox:SetClampedToScreen(true)
            
            -- Hook Mouse Events
            editBox:HookScript("OnMouseDown", function(self, button)
                if addon.db.chatEditBoxUnlock and IsShiftKeyDown() and button == "LeftButton" then
                    self:StartMoving()
                    self.isMoving = true
                end
            end)
            
            editBox:HookScript("OnMouseUp", function(self, button)
                if self.isMoving then
                    self:StopMovingOrSizing()
                    self.isMoving = false
                    -- After dragging, the anchor is likely TOPLEFT. Re-enforce our desired scaling anchor
                    if addon.db.chatEditBoxAnchor then
                         EnforceAnchor(self, addon.db.chatEditBoxAnchor, true)
                    else
                         addon:SaveFramePosition(self, "chatEditBoxPosition")
                    end
                    UpdateVisuals()
                end
            end)
            
            -- Hook OnShow to force alignment when switching tabs
            editBox:HookScript("OnShow", function(self)
                -- Defer slightly to override Blizzard's default positioning for the active tab
                C_Timer.After(0.01, function() 
                    if not self.isMoving then
                        -- We specifically target 'self' here to ensure the active one is caught, 
                        -- but UpdateVisuals handles everything anyway.
                        UpdateVisuals() 
                    end
                end)
            end)
        end
    end
    
    -- Hook OnShow for Chat Buttons to ensure they stay hidden if disabled
    if ChatFrameMenuButton then
        ChatFrameMenuButton:HookScript("OnShow", function(self)
            if addon.db.hideChatFrameMenuButton then
                self:Hide()
            end
        end)
    end
    
    if ChatFrameChannelButton then
        ChatFrameChannelButton:HookScript("OnShow", function(self)
            if addon.db.hideChatFrameChannelButton then
                self:Hide()
            end
        end)
    end

    -- Temporary whisper/conversation windows create new tabs on the fly
    if FCF_OpenTemporaryWindow then
        hooksecurefunc("FCF_OpenTemporaryWindow", function()
            addon:UpdateChatTabs()
        end)
    end

    hookInstalled = true
    UpdateVisuals()
    addon:UpdateChatButtonBackgrounds()
end

function addon:UpdateChatButtonBackgrounds()
    for i = 1, NUM_CHAT_WINDOWS do
        -- Hide the background texture
        local background = _G["ChatFrame" .. i .. "ButtonFrameBackground"]
        if background then
            if addon.db.hideChatButtonFrameBackground then
                background:Hide()
            else
                background:Show()
            end
        end
        
        -- Hide the border textures (Top, Bottom, Left, Right, Middle if exists)
        -- Assuming standard naming convention for some frames or backdrop
        local btnFrame = _G["ChatFrame" .. i .. "ButtonFrame"]
        if btnFrame then
            local textures = {
                _G[btnFrame:GetName() .. "Top"],
                _G[btnFrame:GetName() .. "Bottom"],
                _G[btnFrame:GetName() .. "Left"],
                _G[btnFrame:GetName() .. "Right"],
                _G[btnFrame:GetName() .. "Middle"], 
                _G[btnFrame:GetName() .. "TopLeft"],
                _G[btnFrame:GetName() .. "TopRight"],
                _G[btnFrame:GetName() .. "BottomLeft"],
                _G[btnFrame:GetName() .. "BottomRight"],
                _G[btnFrame:GetName() .. "TopTexture"],
                _G[btnFrame:GetName() .. "BottomTexture"],
                _G[btnFrame:GetName() .. "LeftTexture"],
                _G[btnFrame:GetName() .. "RightTexture"],
                _G[btnFrame:GetName() .. "MiddleTexture"], 
                _G[btnFrame:GetName() .. "TopLeftTexture"],
                _G[btnFrame:GetName() .. "TopRightTexture"],
                _G[btnFrame:GetName() .. "BottomLeftTexture"],
                _G[btnFrame:GetName() .. "BottomRightTexture"],
            }
            
            for _, tex in pairs(textures) do
                if addon.db.hideChatButtonFrameBackground then
                    tex:Hide()
                else
                    tex:Show()
                end
            end
            
            -- If it uses Backdrops
            if btnFrame.GetBackdrop and btnFrame:GetBackdrop() then
                 if addon.db.hideChatButtonFrameBackground then
                     btnFrame:SetBackdropBorderColor(0,0,0,0)
                     btnFrame:SetBackdropColor(0,0,0,0)
                 else
                     -- Can't easily restore original without storing it, but usually standard
                     btnFrame:SetBackdropBorderColor(1,1,1,1)
                     btnFrame:SetBackdropColor(0,0,0,0.5) 
                 end
            end
        end

        -- Hide the minimize button
        local minimize = _G["ChatFrame" .. i .. "ButtonFrameMinimizeButton"]
        if minimize then
            if addon.db.hideChatButtonFrameBackground then
                minimize:Hide()
            else
                minimize:Show()
            end
        end
    end
    
    -- Main Chat Frame Buttons
    if ChatFrameMenuButton then
        if addon.db.hideChatFrameMenuButton then
            ChatFrameMenuButton:Hide()
        else
            ChatFrameMenuButton:Show()
        end
    end
    
    if ChatFrameChannelButton then
        if addon.db.hideChatFrameChannelButton then
            ChatFrameChannelButton:Hide()
        else
            ChatFrameChannelButton:Show()
        end
    end

    -- Quick Join / Social Toast Button (The "Social" button often found near chat)
    if QuickJoinToastButton then
        if addon.db.hideQuickJoinToastButton then
            QuickJoinToastButton:Hide()
        else
            QuickJoinToastButton:Show()
        end
    end

    addon:UpdateChatButtonSide()
    addon:UpdateChatFonts()
    addon:UpdateChatPaneExtend()
    addon:UpdateChatTabs()
end

-- Extend Default Chat Pane
-- Blizzard leaves a strip under the main chat frame for the chat entry box. Once the
-- entry box has been moved elsewhere, this stretches the frame down over that strip.
--
-- Edit Mode owns this frame: it re-applies its saved position and its saved height at
-- different moments, so nudging the frame from wherever it currently is drifts. The
-- target is always computed from Edit Mode's saved values instead, which makes applying
-- it any number of times give the same result.
local EXTEND_EDIT_BOX_GAP = 2 -- pixels between the chat frame and its entry box
local extendHooked = false
local extendPending = false
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

local function IsEditModeActive()
    return EditModeManagerFrame.IsEditModeActive and EditModeManagerFrame:IsEditModeActive()
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
    if addon.db.extendDefaultChatPane and not IsEditModeActive() then
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
local function QueueChatPaneExtend()
    if extendPending then
        return
    end
    extendPending = true
    C_Timer.After(0, function()
        extendPending = false
        ApplyChatPaneExtend()
    end)
end

function addon:UpdateChatPaneExtend()
    if not self:IsFeatureSupported("chatPaneExtend") then
        return
    end
    self.db.chatPaneExtend = nil -- bookkeeping from the first version of this option

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

-- Chat Button Side
-- Blizzard picks the side from the chat frame's screen position and anchors the
-- menu, channel and social buttons to that button frame, so forcing its side moves them all.
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

    if addon.db.chatButtonsOnRight then
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

-- Chat Text Font
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
    if not override then
        return
    end

    -- Only an explicit false is a failure; SetFont returns nothing on success here
    if chatFrame:SetFont(override.font or file, override.size or size, flags) == false then
        chatFrame:SetFont(chatFontOriginals[id], override.size or size, flags)
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
    local chatFrame = _G["ChatFrame" .. id]
    local _, size = chatFrame:GetFont()
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

-- Chat Tabs
local hookedTabs = {}
local tabsRevealed = false -- true while hover temporarily shows hidden tabs
local TAB_STRIP_HEIGHT = 30 -- how far above a chat frame counts as the tab area
local HOVER_POLL_INTERVAL = 0.1

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

local hoverWatcher = CreateFrame("Frame")
hoverWatcher:Hide()
local hoverElapsed = 0
hoverWatcher:SetScript("OnUpdate", function(_, elapsed)
    hoverElapsed = hoverElapsed + elapsed
    if hoverElapsed < HOVER_POLL_INTERVAL then return end
    hoverElapsed = 0

    local over = IsMouseOverChatArea()
    if over ~= tabsRevealed then
        tabsRevealed = over
        addon:UpdateChatTabs()
    end
end)

function addon:UpdateChatTabs()
    local hoverEnabled = addon.db.hideChatTabs and addon.db.showChatTabsOnHover
    hoverWatcher:SetShown(hoverEnabled)
    if not hoverEnabled then
        tabsRevealed = false
    end

    local hide = TabsShouldHide()
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

-- Listener for UI updates that might reset the anchor
hooksecurefunc("ChatEdit_UpdateHeader", function(editBox)
    if addon.db.chatEditBoxPosition then
        -- This blizzard function resets anchors. We need to re-apply ours.
        -- But we must be careful not to create infinite loops or fight it too hard during transient states.
        -- Using a ticker or just re-applying simply usually works.
        C_Timer.After(0.01, function() UpdateVisuals() end)
    end
end)

function addon:SetChatEditBoxUnlock(enabled)
    if enabled then self:InitChatTweaks() end
end

function addon:UpdateChatEditBox()
    if not hookInstalled then self:InitChatTweaks() else UpdateVisuals() end
end
