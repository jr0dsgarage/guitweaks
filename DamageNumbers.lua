---@diagnostic disable: undefined-global
-- Garage UI Tweaks - Damage Number Placement
-- The game engine draws the damage numbers above enemies and places them using CVars.
-- These settings read and write those CVars directly. The game saves them itself, so
-- nothing is copied into GarageUITweaksDB, and a value changed elsewhere (another addon,
-- a /run command) is shown as it is rather than overwritten at login.
local addonName, addon = ...

-- cvar: the name without the "_v2" suffix some clients add; the suffixed name is tried first.
-- fallback: the client's default, used when C_CVar.GetCVarDefault is missing.
-- The rest describes the setting's slider.
local GROUPS = {
    position = {
        { key = "screenY", cvar = "WorldTextScreenY", fallback = 0,
          label = "Normal Hit Height", min = -0.1, max = 0.5, step = 0.005, decimals = 3,
          tooltip = "Raises where normal damage numbers start, measured on the screen, so the gap above the target stays the same at any distance." },
        { key = "critScreenY", cvar = "WorldTextCritScreenY", fallback = 0,
          label = "Critical Hit Height", min = -0.1, max = 0.5, step = 0.005, decimals = 3,
          tooltip = "Raises where critical hit numbers start, measured on the screen." },
        { key = "nonRandomZ", cvar = "WorldTextNonRandomZ", fallback = 2,
          label = "Height Above Target", min = 0, max = 10, step = 0.1, decimals = 1,
          tooltip = "Base height of damage numbers above the target, measured in the game world, so the gap shrinks as the target gets farther away." },
    },
    spread = {
        { key = "randomZMin", cvar = "WorldTextRandomZMin", fallback = 0.8,
          label = "Random Extra Height (Min)", min = 0, max = 5, step = 0.1, decimals = 1,
          tooltip = "Each number starts a random amount above the base height. This is the smallest amount." },
        { key = "randomZMax", cvar = "WorldTextRandomZMax", fallback = 1.5,
          label = "Random Extra Height (Max)", min = 0, max = 5, step = 0.1, decimals = 1,
          tooltip = "The largest random amount a number starts above the base height." },
        { key = "randomXY", cvar = "WorldTextRandomXY", fallback = 0,
          label = "Sideways Scatter", min = 0, max = 5, step = 0.1, decimals = 1,
          tooltip = "How far numbers are scattered to the sides of the target." },
        { key = "startPosRandomness", cvar = "WorldTextStartPosRandomness", fallback = 1,
          label = "Scatter Amount", min = 0, max = 3, step = 0.05, decimals = 2,
          tooltip = "Multiplies all random scatter. At 0, every number starts at the same spot." },
        { key = "directionalScale", cvar = "floatingCombatTextCombatDamageDirectionalScale", fallback = 0,
          label = "Directional Spray", min = 0, max = 3, step = 0.05, decimals = 2,
          tooltip = "Numbers drift away from you, in the direction you hit from. At 0, they rise straight up." },
        { key = "directionalOffset", cvar = "floatingCombatTextCombatDamageDirectionalOffset", fallback = 1,
          label = "Directional Start Offset", min = 0, max = 5, step = 0.1, decimals = 1,
          tooltip = "How far from the target directional numbers start. Only applies when Directional Spray is above 0." },
    },
}

local SETTINGS = {}
for _, group in pairs(GROUPS) do
    for _, setting in ipairs(group) do
        SETTINGS[setting.key] = setting
    end
end

local function ReadCVar(name)
    if not (C_CVar and C_CVar.GetCVar) then
        return nil
    end
    local ok, value = pcall(C_CVar.GetCVar, name)
    return ok and value or nil
end

-- Actual CVar name per key, or false when this client has neither name
local resolved = {}

local function GetCVarName(key)
    if resolved[key] == nil then
        local base = SETTINGS[key].cvar
        resolved[key] = (ReadCVar(base .. "_v2") and base .. "_v2") or (ReadCVar(base) and base) or false
    end
    return resolved[key] or nil
end

-- The settings in a group ("position" or "spread"), in display order
function addon:GetDamageNumberSettings(group)
    return GROUPS[group]
end

-- True when this client has the CVar behind every setting in the group
function addon:HasDamageNumberSettings(group)
    for _, setting in ipairs(GROUPS[group]) do
        if not GetCVarName(setting.key) then
            return false
        end
    end
    return true
end

function addon:GetDamageNumberDefault(key)
    local name = GetCVarName(key)
    if name and C_CVar.GetCVarDefault then
        local ok, value = pcall(C_CVar.GetCVarDefault, name)
        if ok and tonumber(value) then
            return tonumber(value)
        end
    end
    return SETTINGS[key].fallback
end

function addon:GetDamageNumberSetting(key)
    local name = GetCVarName(key)
    return (name and tonumber(ReadCVar(name))) or self:GetDamageNumberDefault(key)
end

function addon:SetDamageNumberSetting(key, value)
    local name = GetCVarName(key)
    if name then
        pcall(C_CVar.SetCVar, name, tostring(value))
    end
end

function addon:ResetDamageNumberSettings(group)
    for _, setting in ipairs(GROUPS[group]) do
        self:SetDamageNumberSetting(setting.key, self:GetDamageNumberDefault(setting.key))
    end
end
