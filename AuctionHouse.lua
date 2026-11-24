---@diagnostic disable: undefined-global
-- Garage UI Tweaks - Auction House Width
-- Widens the auction house window so every tab below it fits under it. Addons such as
-- Auctionator and TradeSkillMaster add their tabs (through LibAHTab) to the right of
-- Blizzard's, and with enough of them the row runs past the window's right edge.
--
-- Blizzard_AuctionHouseUI loads on demand, and the addon tabs are created when the auction
-- house first opens, so the width is measured each time the window is shown, and again
-- shortly after, once the other addons have added their tabs.
local addonName, addon = ...

local RIGHT_PADDING = 8 -- space left between the last tab and the window's right edge
local REMEASURE_DELAYS = { 0, 0.2, 1 }

local baseWidth -- the window's own width, captured before it is first widened
local hooked = false

-- How far right the tabs hanging below the window reach, in the window's coordinates.
-- Looks at the window's children and grandchildren, since LibAHTab parents its tabs to a
-- holder frame inside the window.
local function GetTabsRight(frame)
    local bottom = frame:GetBottom()
    if not bottom then
        return nil
    end
    local frameScale = frame:GetEffectiveScale()
    local right

    local function Consider(region)
        if not (region:IsShown() and region:IsObjectType("Button")) then
            return
        end
        local top, regionRight = region:GetTop(), region:GetRight()
        if not (top and regionRight) then
            return
        end
        local ratio = region:GetEffectiveScale() / frameScale
        -- A tab starts at (or a few pixels above) the window's bottom edge and hangs below it
        if top * ratio <= bottom + 6 and region:GetBottom() * ratio < bottom then
            right = math.max(right or 0, regionRight * ratio)
        end
    end

    for _, child in ipairs({ frame:GetChildren() }) do
        Consider(child)
        for _, grandchild in ipairs({ child:GetChildren() }) do
            Consider(grandchild)
        end
    end
    return right
end

local function ApplyWidth()
    local frame = AuctionHouseFrame
    if not frame then
        return
    end

    if not addon.db.auctionHouseFitTabs then
        if baseWidth then
            frame:SetWidth(baseWidth)
            baseWidth = nil
        end
        return
    end

    baseWidth = baseWidth or frame:GetWidth()

    local left = frame:GetLeft()
    local tabsRight = GetTabsRight(frame)
    if not (left and tabsRight) then
        return
    end

    local needed = math.ceil(tabsRight - left + RIGHT_PADDING)
    local width = math.max(baseWidth, needed)
    if math.abs(frame:GetWidth() - width) >= 1 then
        frame:SetWidth(width)
    end
end

local function ScheduleApply()
    for _, delay in ipairs(REMEASURE_DELAYS) do
        C_Timer.After(delay, function()
            if AuctionHouseFrame and AuctionHouseFrame:IsShown() then
                ApplyWidth()
            end
        end)
    end
end

local function HookAuctionHouse()
    if hooked or not AuctionHouseFrame then
        return
    end
    hooked = true
    AuctionHouseFrame:HookScript("OnShow", function()
        if addon.db.auctionHouseFitTabs then
            ScheduleApply()
        end
    end)
end

function addon:UpdateAuctionHouseWidth()
    if not AuctionHouseFrame then
        return -- not loaded yet: the ADDON_LOADED handler below picks it up
    end
    if self.db.auctionHouseFitTabs then
        HookAuctionHouse()
        if AuctionHouseFrame:IsShown() then
            ScheduleApply()
        end
    else
        ApplyWidth() -- puts the window back to its own width
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, _, loadedAddon)
    if loadedAddon == "Blizzard_AuctionHouseUI" then
        self:UnregisterEvent("ADDON_LOADED")
        if addon.db then
            addon:UpdateAuctionHouseWidth()
        end
    end
end)
