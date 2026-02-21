LootDetails = {}
local LD = LootDetails

-- Lightweight callback system for inter-module communication.
local callbacks = {}

function LD:On(event, fn)
    if not callbacks[event] then
        callbacks[event] = {}
    end
    table.insert(callbacks[event], fn)
end

function LD:Fire(event, ...)
    if not callbacks[event] then return end
    for _, fn in ipairs(callbacks[event]) do
        fn(...)
    end
end

LD.debug = true
LD.enabled = true

function LD:Log(...)
    if not self.debug then return end
    print("|cff888888[LD]|r", ...)
end

local defaults = {
    currentSessionId = -1,
    sessions         = {},
    mobLoot          = {},
    recentlyKilled   = {},   -- [guid] = timestamp; pruned after 15 min
    options          = {
        fastAutoLoot = true,
    },
}

local function updateEnabledState()
    local inParty = IsInGroup()
    local enabled = not inParty
    if enabled == LD.enabled then return end
    LD.enabled = enabled
    if inParty then
        LD:Log("disabled (in party)")
    else
        LD:Log("enabled (solo)")
    end
end

local frame = CreateFrame("Frame")

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name ~= "LootDetails" then return end

        -- Initialize saved variables with defaults
        if not LootDetailsDB then
            LootDetailsDB = CopyTable(defaults)
        end

        LD.db = LootDetailsDB

        updateEnabledState()
        print("|cff00ccff[LootDetails]|r Loaded.")
    elseif event == "GROUP_ROSTER_UPDATE" then
        updateEnabledState()
    end
end)
