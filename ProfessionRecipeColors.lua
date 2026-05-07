---@diagnostic disable: undefined-global
-- Garage UI Tweaks - Profession Recipe Quality Colors
local addonName, addon = ...

local DEBUG_ENABLED = false
local DEBUG_LAST_UPDATE = 0  -- Track last debug output time to reduce spam

local function Debug(msg)
    if DEBUG_ENABLED then
        print("|cff00ff00[PROF_RECIPE_DEBUG]|r " .. tostring(msg))
    end
end

local function DebugThrottled(msg)
    if DEBUG_ENABLED then
        local now = GetTime()
        if now - DEBUG_LAST_UPDATE >= 1.0 then
            Debug(msg)
            DEBUG_LAST_UPDATE = now
        end
    end
end

local function GetQualityColor(quality)
    if quality == nil then
        return nil
    end

    if GetItemQualityColor then
        local r, g, b = GetItemQualityColor(quality)
        if r and g and b then
            return r, g, b
        end
    end

    local fallback = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if fallback then
        return fallback.r, fallback.g, fallback.b
    end

    return nil
end

local function GetQualityFromItemID(itemID)
    if not itemID then
        return nil
    end

    local _, _, quality = GetItemInfo(itemID)
    return quality
end

local function GetQualityFromItemLink(itemLink)
    if not itemLink or itemLink == "" then
        return nil
    end

    local _, _, quality = GetItemInfo(itemLink)
    return quality
end

local function GetRecipeOutputQuality(recipeID)
    if not recipeID or not C_TradeSkillUI then
        return nil
    end

    local recipeInfo = C_TradeSkillUI.GetRecipeInfo and C_TradeSkillUI.GetRecipeInfo(recipeID)

    if recipeInfo then
        if type(recipeInfo.quality) == "number" then
            return recipeInfo.quality
        end

        if recipeInfo.craftedItemID then
            local quality = GetQualityFromItemID(recipeInfo.craftedItemID)
            if quality ~= nil then
                return quality
            end
        end

        if recipeInfo.hyperlink then
            local quality = GetQualityFromItemLink(recipeInfo.hyperlink)
            if quality ~= nil then
                return quality
            end
        end
    end

    local schematic = C_TradeSkillUI.GetRecipeSchematic and C_TradeSkillUI.GetRecipeSchematic(recipeID, false)
    if not schematic then
        return nil
    end

    if schematic.outputItemID then
        local quality = GetQualityFromItemID(schematic.outputItemID)
        if quality ~= nil then
            return quality
        end
    end

    if schematic.outputItemHyperlink then
        local quality = GetQualityFromItemLink(schematic.outputItemHyperlink)
        if quality ~= nil then
            return quality
        end
    end

    return nil
end

local function GetRecipeRecipeIDByIndex(recipeIndex)
    if not C_TradeSkillUI or not C_TradeSkillUI.GetRecipeIndexInfo then
        return nil
    end

    local recipeInfo = C_TradeSkillUI.GetRecipeIndexInfo(recipeIndex)
    if recipeInfo and recipeInfo.recipeID then
        return recipeInfo.recipeID
    end

    return nil
end

local function ResolveRecipeButtonData(buttonFrame)
    if not buttonFrame then
        return nil, nil
    end

    local labelFrame = buttonFrame.Label
    if not (labelFrame and labelFrame.SetTextColor) then
        return nil, nil
    end

    local recipeID = buttonFrame.recipeID
    if recipeID then
        return labelFrame, recipeID
    end

    if not buttonFrame.GetElementData then
        return labelFrame, nil
    end

    local elementData = buttonFrame:GetElementData()
    if not elementData then
        return labelFrame, nil
    end

    local actualData = elementData.GetData and elementData:GetData() or nil
    if not actualData or type(actualData) ~= "table" then
        return labelFrame, nil
    end

    local recipeInfo = actualData.recipeInfo
    if type(recipeInfo) == "table" then
        if recipeInfo.recipeID then
            recipeID = recipeInfo.recipeID
        elseif recipeInfo.ID then
            recipeID = recipeInfo.ID
        end
    end

    if not recipeID and actualData.index then
        recipeID = GetRecipeRecipeIDByIndex(actualData.index)
    end

    return labelFrame, recipeID
end

function addon:ApplyProfessionRecipeColorToButton(buttonFrame, forceReset)
    local labelFrame, recipeID = ResolveRecipeButtonData(buttonFrame)
    if not labelFrame then
        return
    end

    local enabled = self.db and self.db.professionRecipeQualityColorEnabled
    if not enabled then
        if forceReset then
            labelFrame:SetTextColor(1, 1, 1)
        end
        return
    end

    if not recipeID then
        return
    end

    local quality = GetRecipeOutputQuality(recipeID)
    local r, g, b = GetQualityColor(quality)
    if r and g and b then
        labelFrame.GUITApplyingQualityColor = true
        labelFrame:SetTextColor(r, g, b)
        labelFrame.GUITApplyingQualityColor = nil
    end
end

function addon:HookProfessionRecipeLabel(labelFrame, buttonFrame)
    if not labelFrame or labelFrame.GUITProfessionRecipeLabelHooked then
        return
    end

    labelFrame.GUITProfessionRecipeLabelHooked = true
    labelFrame.GUITProfessionRecipeButton = buttonFrame

    local function ReapplyQualityColor(self)
        if self.GUITApplyingQualityColor then
            return
        end

        local ownerButton = self.GUITProfessionRecipeButton
        if ownerButton then
            addon:ApplyProfessionRecipeColorToButton(ownerButton)
        end
    end

    local function TryHookMethod(target, methodName, handler)
        if not (target and handler) then
            return
        end

        local ok = pcall(hooksecurefunc, target, methodName, handler)
        return ok
    end

    TryHookMethod(labelFrame, "SetTextColor", ReapplyQualityColor)
    TryHookMethod(labelFrame, "SetText", ReapplyQualityColor)
    TryHookMethod(labelFrame, "SetFormattedText", ReapplyQualityColor)
end

function addon:HookProfessionRecipeButton(buttonFrame)
    if not buttonFrame or buttonFrame.GUITProfessionRecipeColorHooked then
        return
    end

    buttonFrame.GUITProfessionRecipeColorHooked = true

    local labelFrame = buttonFrame.Label
    if labelFrame then
        self:HookProfessionRecipeLabel(labelFrame, buttonFrame)
    end

    if buttonFrame.HookScript then
        buttonFrame:HookScript("OnShow", function(self)
            addon:ApplyProfessionRecipeColorToButton(self)
        end)
        buttonFrame:HookScript("OnEnter", function(self)
            addon:ApplyProfessionRecipeColorToButton(self)
        end)
        buttonFrame:HookScript("OnLeave", function(self)
            addon:ApplyProfessionRecipeColorToButton(self)
        end)
    end

    local candidateMethods = {
        "Init",
        "Update",
        "Refresh",
        "SetData",
        "SetDataBinding",
        "SetElementData",
        "SetNode",
    }

    for _, methodName in ipairs(candidateMethods) do
        pcall(hooksecurefunc, buttonFrame, methodName, function(self)
            addon:ApplyProfessionRecipeColorToButton(self)
        end)
    end
end

local function EnumerateDescendants(rootFrame, callback, visited)
    if not rootFrame or not callback then
        return
    end

    visited = visited or {}
    if visited[rootFrame] then
        return
    end
    visited[rootFrame] = true

    callback(rootFrame)

    if rootFrame.GetNumChildren and rootFrame.GetChildren then
        for index = 1, rootFrame:GetNumChildren() do
            local child = select(index, rootFrame:GetChildren())
            if child then
                EnumerateDescendants(child, callback, visited)
            end
        end
    end
end

local function GetProfessionRecipeSearchRoots()
    local roots = {}
    local seen = {}

    local function AddRoot(frame)
        if frame and not seen[frame] then
            seen[frame] = true
            roots[#roots + 1] = frame
        end
    end

    local professionsFrame = _G["ProfessionsFrame"]
    if not professionsFrame then
        return roots
    end

    AddRoot(professionsFrame.CraftingPage and professionsFrame.CraftingPage.RecipeList)

    local ordersPage = professionsFrame.OrdersPage
    if ordersPage then
        AddRoot(ordersPage)
        AddRoot(ordersPage.RecipeList)
        AddRoot(ordersPage.BrowseFrame)
        AddRoot(ordersPage.BrowseFrame and ordersPage.BrowseFrame.RecipeList)
    end

    return roots
end

local function GetProfessionRecipeScrollBoxes()
    local scrollBoxes = {}
    local seen = {}

    for _, root in ipairs(GetProfessionRecipeSearchRoots()) do
        EnumerateDescendants(root, function(frame)
            local scrollBox = frame.ScrollBox
            if scrollBox and not seen[scrollBox] then
                seen[scrollBox] = true
                scrollBoxes[#scrollBoxes + 1] = {
                    owner = frame,
                    scrollBox = scrollBox,
                }
            end
        end)
    end

    return scrollBoxes
end

function addon:HookProfessionRecipeListEvents()
    self.professionRecipeListHookedFrames = self.professionRecipeListHookedFrames or {}

    local function TryHookScript(frame, scriptName, handler)
        if not (frame and frame.HookScript and handler) then
            return false
        end

        local hasScript = false
        if frame.HasScript then
            local ok, result = pcall(frame.HasScript, frame, scriptName)
            hasScript = ok and result and true or false
        end

        if not hasScript then
            return false
        end

        local ok = pcall(frame.HookScript, frame, scriptName, handler)
        return ok
    end

    local function QueueRefresh()
        addon:QueueProfessionRecipeColorRefresh(0)
        addon:QueueProfessionRecipeColorRefresh(0.02)
    end

    local hooked = false
    for _, entry in ipairs(GetProfessionRecipeScrollBoxes()) do
        local scrollBox = entry.scrollBox
        if not self.professionRecipeListHookedFrames[scrollBox] then
            self.professionRecipeListHookedFrames[scrollBox] = true

            local owner = entry.owner
            local scrollBar = scrollBox.ScrollBar or (owner and owner.ScrollBar)
            if TryHookScript(scrollBar, "OnValueChanged", QueueRefresh) then
                hooked = true
            end

            if TryHookScript(scrollBox, "OnMouseWheel", QueueRefresh) then
                hooked = true
            end

            local scrollTarget = scrollBox.ScrollTarget
            if TryHookScript(scrollTarget, "OnMouseWheel", QueueRefresh) then
                hooked = true
            end
        end
    end

    self.professionRecipeListEventsHooked = self.professionRecipeListEventsHooked or hooked
end

local function GetRecipeButtons()
    local buttons = {}
    local seenButtons = {}

    local professionsFrame = _G["ProfessionsFrame"]
    if not professionsFrame or not professionsFrame:IsShown() then
        Debug("ProfessionsFrame not found or not shown")
        return buttons
    end

    local scrollBoxes = GetProfessionRecipeScrollBoxes()
    if #scrollBoxes == 0 then
        Debug("No recipe scroll boxes found")
        return buttons
    end

    for _, entry in ipairs(scrollBoxes) do
        local scrollTarget = entry.scrollBox and entry.scrollBox.ScrollTarget
        if scrollTarget then
            EnumerateDescendants(scrollTarget, function(buttonFrame)
                if seenButtons[buttonFrame] then
                    return
                end

                local labelFrame, recipeID = ResolveRecipeButtonData(buttonFrame)
                if labelFrame then
                    seenButtons[buttonFrame] = true
                    addon:HookProfessionRecipeButton(buttonFrame)
                    if recipeID then
                        if DEBUG_ENABLED and #buttons < 6 then
                            Debug("Found recipe button with recipeID=" .. tostring(recipeID))
                        end
                        buttons[#buttons + 1] = {
                            frame = buttonFrame,
                            labelFrame = labelFrame,
                            recipeID = recipeID,
                        }
                    end
                end
            end)
        end
    end

    Debug("Total recipe buttons collected: " .. #buttons)
    return buttons
end

function addon:UpdateProfessionRecipeListColors()
    local enabled = self.db and self.db.professionRecipeQualityColorEnabled
    DebugThrottled("UpdateProfessionRecipeListColors called, enabled=" .. tostring(enabled))

    local buttons = GetRecipeButtons()
    DebugThrottled("Processing " .. #buttons .. " recipe buttons")

    for idx, button in ipairs(buttons) do
        if idx <= 5 and enabled and button.recipeID then
            local quality = GetRecipeOutputQuality(button.recipeID)
            local r, g, b = GetQualityColor(quality)
            if r and g and b then
                Debug("  Button " .. idx .. " (recipeID=" .. button.recipeID .. "): quality=" .. tostring(quality) .. " -> RGB(" .. string.format("%.2f", r) .. ", " .. string.format("%.2f", g) .. ", " .. string.format("%.2f", b) .. ")")
            else
                Debug("  Button " .. idx .. " (recipeID=" .. button.recipeID .. "): quality=" .. tostring(quality) .. " -> color not ready (keeping current)")
            end
        end

        self:ApplyProfessionRecipeColorToButton(button.frame, not enabled)
    end
end

function addon:QueueProfessionRecipeColorRefresh(delay)
    if not (self.db and self.db.professionRecipeQualityColorEnabled) then
        return
    end

    C_Timer.After(delay or 0, function()
        addon:HookProfessionRecipeListEvents()
        addon:UpdateProfessionRecipeListColors()
    end)
end

function addon:SetProfessionRecipeQualityColorEnabled(enabled)
    self.db.professionRecipeQualityColorEnabled = enabled and true or false

    -- Kill legacy ticker if it exists from an older version/session.
    if self.professionRecipeColorTicker then
        self.professionRecipeColorTicker:Cancel()
        self.professionRecipeColorTicker = nil
    end

    if self.db.professionRecipeQualityColorEnabled then
        -- One immediate pass and one short delayed pass to catch rows that initialize a frame later.
        self:QueueProfessionRecipeColorRefresh(0)
        self:QueueProfessionRecipeColorRefresh(0.05)
    else
        self:UpdateProfessionRecipeListColors()
    end
end

function addon:InitProfessionRecipeQualityColors()
    if self.professionRecipeColorFrame then
        return
    end

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("TRADE_SKILL_SHOW")
    frame:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
    frame:RegisterEvent("TRADE_SKILL_CLOSE")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:SetScript("OnEvent", function(_, event)
        if event == "TRADE_SKILL_CLOSE" then
            addon:UpdateProfessionRecipeListColors()
            return
        end

        addon:QueueProfessionRecipeColorRefresh(0)
        addon:QueueProfessionRecipeColorRefresh(0.05)
    end)

    self.professionRecipeColorFrame = frame

    self:QueueProfessionRecipeColorRefresh(0)
    self:QueueProfessionRecipeColorRefresh(0.05)
end

function addon:SetProfessionRecipeDebug(enabled)
    DEBUG_ENABLED = enabled and true or false
    print("|cff00ff00[Garage UI Tweaks]|r Profession recipe debug: " .. (DEBUG_ENABLED and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
    if DEBUG_ENABLED then
        self:UpdateProfessionRecipeListColors()
    end
end

_G.GarageUITweaksProfRecipeDebug = function(val)
    if addon and addon.SetProfessionRecipeDebug then
        addon:SetProfessionRecipeDebug(val == "on" or val == true or val == 1)
    end
end
