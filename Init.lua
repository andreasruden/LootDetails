LootDetails = {}
local LD = LootDetails

local defaults = {
    currentSessionId = -1,
    sessions = {},
    totalLoot = {},
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
