---@diagnostic disable: undefined-global
-- Garage UI Tweaks - Prey Percentage
-- While hunting prey outdoors, writes the encounter bar's value on it as a percentage.
--
-- The bar is the child of UIWidgetPowerBarContainerFrame whose state art is a "prey" atlas.
-- Its value comes from the first of these that gives one: the info the widget was last
-- set up with, its status bar, info tables on the widget, text on the widget, and the
-- widget APIs.
local addonName, addon = ...

-- Matched by name, so this only works on English clients
local HUNT_BUFF_NAME = "On the Hunt"

-- Events that can build or show the widget; Blizzard finishes a moment later
local DELAYED_EVENTS = {
    ENCOUNTER_START = true, UPDATE_ALL_UI_WIDGETS = true, PLAYER_ENTERING_WORLD = true, ZONE_CHANGED_NEW_AREA = true,
}

local label, labelParent
local currentWidget, currentWidgetID
local widgetInfo -- copy of the info a prey widget was last set up with
local setupHooked = false
local vizGetters -- C_UIWidgetManager's Get...WidgetVisualizationInfo functions
local eventFrame = CreateFrame("Frame")

-- ============================================================================
-- Reading a percentage
-- ============================================================================

local function ClampPercent(value)
    return math.max(0, math.min(100, value))
end

-- A percent field may hold a fraction (0-1) or a percentage
local function PercentFromField(value)
    if value >= 0 and value <= 1 then
        value = value * 100
    end
    return ClampPercent(value)
end

-- "45%" or "9/20"
local function PercentFromText(text)
    if type(text) ~= "string" then
        return nil
    end

    local percent = tonumber(text:match("(%d+)%s*%%"))
    if percent then
        return ClampPercent(percent)
    end

    local current, maxValue = text:match("(%d+)%s*/%s*(%d+)")
    current, maxValue = tonumber(current), tonumber(maxValue)
    if current and maxValue and maxValue > 0 and current <= maxValue then
        return ClampPercent(current / maxValue * 100)
    end
    return nil
end

-- A widget's progress state, from 0 (none) to 3 (complete)
local function PercentFromState(state)
    state = tonumber(state)
    if not state then
        return nil
    end
    if state <= 0 then
        return 0
    elseif state == 1 then
        return 33
    elseif state == 2 then
        return 66
    elseif state >= 3 then
        return 100
    end
    return nil
end

-- Searches an info table and the tables inside it for a percent field, a percentage in
-- text, or a current/max pair of fields
local function ScanInfo(info)
    local visited = {}

    local function Scan(tbl, depth)
        if depth > 4 or visited[tbl] then
            return nil
        end
        visited[tbl] = true

        local currentValues, maxValues = {}, {}
        for key, value in pairs(tbl) do
            if type(value) == "number" then
                local keyText = tostring(key):lower()
                if keyText:find("percent", 1, true) then
                    return PercentFromField(value)
                end
                if value >= 0 then
                    if keyText:find("current", 1, true) or keyText:find("value", 1, true) or keyText:find("progress", 1, true)
                        or keyText:find("fulfilled", 1, true) or keyText:find("completed", 1, true) then
                        table.insert(currentValues, value)
                    end
                    if keyText:find("max", 1, true) or keyText:find("total", 1, true) or keyText:find("required", 1, true) then
                        table.insert(maxValues, value)
                    end
                end
            elseif type(value) == "string" then
                local percent = PercentFromText(value)
                if percent then
                    return percent
                end
            elseif type(value) == "table" then
                local percent = Scan(value, depth + 1)
                if percent then
                    return percent
                end
            end
        end

        for _, current in ipairs(currentValues) do
            for _, maxValue in ipairs(maxValues) do
                if maxValue > 0 and current <= maxValue then
                    return ClampPercent(current / maxValue * 100)
                end
            end
        end
        return nil
    end

    return Scan(info, 0)
end

local PERCENT_FIELDS = { "progressPercentage", "progressPercent", "fillPercentage", "percentage", "percent", "progress", "progressValue" }
local VALUE_FIELDS = { "barValue", "value", "currentValue" }
local MAX_FIELDS = { "barMax", "maxValue", "totalValue", "total", "max" }

-- From a widget info table: its known fields first, then a scan of everything in it
local function PercentFromInfo(info, tooltipText)
    if type(info) == "table" then
        for _, field in ipairs(PERCENT_FIELDS) do
            if type(info[field]) == "number" then
                return PercentFromField(info[field])
            end
        end

        for _, valueField in ipairs(VALUE_FIELDS) do
            local current = info[valueField]
            if type(current) == "number" then
                for _, maxField in ipairs(MAX_FIELDS) do
                    local maxValue = info[maxField]
                    if type(maxValue) == "number" and maxValue > 0 then
                        return ClampPercent(current / maxValue * 100)
                    end
                end
            end
        end

        local scanned = ScanInfo(info)
        if scanned then
            return scanned
        end
    end

    local fromTooltip = PercentFromText(tooltipText)
    if fromTooltip then
        return fromTooltip
    end

    if type(info) == "table" then
        return PercentFromState(info.progressState or info.state)
    end
    return nil
end

local INFO_KEYS = { "widgetInfo", "WidgetInfo", "data", "Data", "info", "Info", "progressInfo", "ProgressInfo", "barInfo", "BarInfo" }

-- From info tables Blizzard keeps on the widget frame
local function PercentFromWidgetFields(widget)
    for _, key in ipairs(INFO_KEYS) do
        local info = widget[key]
        if info ~= nil then
            local percent = PercentFromInfo(info, type(info) == "table" and info.tooltip or nil)
            if percent then
                return percent
            end
        end
    end
    return nil
end

-- From the text of any font string on the widget or its children
local function PercentFromRegions(frame, depth)
    if not frame or depth > 5 then
        return nil
    end

    for _, region in ipairs({ frame:GetRegions() }) do
        if region:IsObjectType("FontString") then
            local percent = PercentFromText(region:GetText())
            if percent then
                return percent
            end
        end
    end

    for _, child in ipairs({ frame:GetChildren() }) do
        local percent = PercentFromRegions(child, depth + 1)
        if percent then
            return percent
        end
    end
    return nil
end

local function GetVizGetters()
    if vizGetters then
        return vizGetters
    end

    vizGetters = {}
    for key, func in pairs(C_UIWidgetManager) do
        if type(key) == "string" and type(func) == "function" and key:find("^Get") and key:find("WidgetVisualizationInfo") then
            table.insert(vizGetters, { name = key, func = func })
        end
    end
    table.sort(vizGetters, function(a, b) return a.name < b.name end)
    return vizGetters
end

-- From the widget APIs: the status bar one first, then every other kind
local function PercentFromWidgetAPIs(widgetID)
    local info = C_UIWidgetManager.GetStatusBarWidgetVisualizationInfo(widgetID)
    local percent = info and PercentFromInfo(info, info.tooltip)
    if percent then
        return percent
    end

    for _, getter in ipairs(GetVizGetters()) do
        local ok, result = pcall(getter.func, widgetID)
        if ok and result ~= nil then
            percent = PercentFromInfo(result, type(result) == "table" and result.tooltip or nil)
            if percent then
                return percent
            end
        end
    end
    return nil
end

local STATUS_BAR_KEYS = { "Bar", "statusBar", "StatusBar", "progressBar", "ProgressBar" }

local function FindStatusBar(frame, depth)
    if not frame or depth > 4 then
        return nil
    end
    if frame:IsObjectType("StatusBar") then
        return frame
    end

    for _, key in ipairs(STATUS_BAR_KEYS) do
        local candidate = frame[key]
        if type(candidate) == "table" and candidate.IsObjectType and candidate:IsObjectType("StatusBar") then
            return candidate
        end
    end

    for _, child in ipairs({ frame:GetChildren() }) do
        local found = FindStatusBar(child, depth + 1)
        if found then
            return found
        end
    end
    return nil
end

local function PercentFromStatusBar(widget)
    local statusBar = FindStatusBar(widget, 0)
    if not statusBar then
        return nil
    end
    local value = statusBar:GetValue()
    local minValue, maxValue = statusBar:GetMinMaxValues()
    if maxValue and maxValue > minValue then
        return (value - minValue) / (maxValue - minValue) * 100
    end
    return nil
end

local function GetWidgetID(widget)
    for _, key in ipairs({ "widgetID", "WidgetID", "widgetId", "id" }) do
        if type(widget[key]) == "number" then
            return widget[key]
        end
    end

    if widget.GetWidgetID then
        local ok, id = pcall(widget.GetWidgetID, widget)
        if ok and type(id) == "number" then
            return id
        end
    end

    local parent = widget:GetParent()
    if parent then
        for _, key in ipairs({ "widgetID", "WidgetID", "widgetId" }) do
            if type(parent[key]) == "number" then
                return parent[key]
            end
        end
    end
    return nil
end

local function GetPreyPercent(widget)
    local percent = widgetInfo and PercentFromInfo(widgetInfo, widgetInfo.tooltip)
        or PercentFromStatusBar(widget)
        or PercentFromWidgetFields(widget)
        or PercentFromRegions(widget, 0)

    if not percent then
        local widgetID = GetWidgetID(widget) or currentWidgetID
        if widgetID then
            percent = PercentFromWidgetAPIs(widgetID)
        end
    end

    return percent and math.floor(ClampPercent(percent) + 0.5)
end

-- ============================================================================
-- The widget and the label
-- ============================================================================

local function CaptureWidgetInfo(widget, info)
    currentWidget = widget
    widgetInfo = nil
    if type(info) == "table" then
        -- A shallow copy keeps the nested tables reachable after Blizzard reuses the original
        widgetInfo = {}
        for key, value in pairs(info) do
            widgetInfo[key] = value
        end
    end
end

-- Keeps a copy of the info each prey widget is set up with. Hooks the widget template's
-- mixin, or failing that the widget itself.
local function HookWidgetSetup(widget)
    if setupHooked then
        return
    end

    local mixin = UIWidgetTemplatePreyHuntProgressMixin
    if mixin and type(mixin.Setup) == "function" then
        hooksecurefunc(mixin, "Setup", CaptureWidgetInfo)
        setupHooked = true
    elseif widget and type(widget.Setup) == "function" then
        hooksecurefunc(widget, "Setup", CaptureWidgetInfo)
        setupHooked = true
    end
end

local function FindPreyWidget()
    local container = UIWidgetPowerBarContainerFrame
    if not container or not container:IsShown() then
        return nil
    end

    for _, child in ipairs({ container:GetChildren() }) do
        local atlas = child.StateTexture and child.StateTexture:GetAtlas()
        if atlas and atlas:lower():find("prey") then
            if currentWidget ~= child then
                currentWidget = child
                currentWidgetID = GetWidgetID(child)
            end
            return child
        end
    end

    currentWidget = nil
    return nil
end

-- The label is parented to the widget; a recycled widget frame gets a new one
local function GetLabel(widget)
    if labelParent ~= widget then
        if label then
            label:Hide()
        end
        label = widget:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        label:SetTextColor(1, 1, 1, 1)
        label:SetShadowOffset(1, -1)
        label:SetShadowColor(0, 0, 0, 1)
        labelParent = widget
    end
    return label
end

local function HideLabel()
    if label then
        label:Hide()
    end
end

local function HasHuntBuff()
    return C_UnitAuras.GetAuraDataBySpellName("player", HUNT_BUFF_NAME) ~= nil
end

local function Refresh()
    if not addon.db.encounterBarPreyPercentEnabled then
        HideLabel()
        return
    end

    if not HasHuntBuff() then
        HideLabel()
        widgetInfo = nil
        return
    end

    local widget = FindPreyWidget()
    if not widget or not widget:IsShown() then
        HideLabel()
        return
    end
    HookWidgetSetup(widget)

    local percent = GetPreyPercent(widget)
    local text = GetLabel(widget)
    if not percent then
        text:Hide()
        return
    end

    text:SetText(percent .. "%")
    text:ClearAllPoints()
    text:SetPoint("CENTER", widget, "CENTER", 0, -text:GetStringHeight() / 2)
    text:Show()
end

eventFrame:SetScript("OnEvent", function(_, event)
    if DELAYED_EVENTS[event] then
        C_Timer.After(0.1, Refresh)
    elseif event == "ENCOUNTER_END" then
        HideLabel()
        widgetInfo = nil
    else -- UPDATE_UI_WIDGET, UNIT_AURA
        Refresh()
    end
end)

function addon:UpdatePreyPercent()
    if not self:IsFeatureSupported("preyPercent") then
        return
    end

    if self.db.encounterBarPreyPercentEnabled then
        HookWidgetSetup()
        for event in pairs(DELAYED_EVENTS) do
            eventFrame:RegisterEvent(event)
        end
        eventFrame:RegisterEvent("ENCOUNTER_END")
        eventFrame:RegisterEvent("UPDATE_UI_WIDGET")
        eventFrame:RegisterUnitEvent("UNIT_AURA", "player")
    else
        eventFrame:UnregisterAllEvents()
    end
    Refresh()
end
