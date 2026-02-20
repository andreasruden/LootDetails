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

function LD:Log(...)
    if not self.debug then return end
    print("|cff888888[LD]|r", ...)
end

local defaults = {
    currentSessionId = -1,
    sessions         = {},
    totalLoot        = {},
    recentlyKilled   = {},   -- [guid] = timestamp; pruned after 15 min
    options          = {
        fastAutoLoot = true,
    },
}

local frame = CreateFrame("Frame")

frame:RegisterEvent("ADDON_LOADED")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name ~= "LootDetails" then return end

        -- Initialize saved variables with defaults
        if not LootDetailsDB then
            LootDetailsDB = CopyTable(defaults)
        end

        LD.db = LootDetailsDB

        print("|cff00ccff[LootDetails]|r Loaded.")
    end
end)
