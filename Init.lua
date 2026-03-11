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

LD.debug = false
LD.disabledReason = nil  -- nil = active; string = why disabled (e.g. "party", "SpeedyAutoLoot")

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
        fastAutoLoot                = true,
        debug                       = false,
        equipmentMinRarity          = 2,    -- 0=gray,1=white,2=green,3=blue,4=purple,5=orange
        equipmentMarketMultiplier   = 2.0,  -- market must be >= N × vendor price
        tradegoodsMarketMultiplier  = 1.5,  -- same, for consumables/gems/tradeskill/recipes
    },
    minimapButton    = {},
    farmingWindowPos = nil,   -- { x, y } TOPLEFT screen coords; nil = center
}

local function updateEnabledState()
    -- Don't overwrite a conflict-based disable reason with party state
    if LD.disabledReason and LD.disabledReason ~= "party" then return end
    local reason = IsInGroup() and "party" or nil
    if reason == LD.disabledReason then return end
    LD.disabledReason = reason
    if reason then
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
        LD.debug = LD.db.options.debug or false

        updateEnabledState()
        print("|cff00ccff[LootDetails]|r Loaded.")
    elseif event == "GROUP_ROSTER_UPDATE" then
        updateEnabledState()
    end
end)
