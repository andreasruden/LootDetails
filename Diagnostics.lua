local LD = LootDetails

local function leatrixFasterLootEnabled()
    return C_AddOns.IsAddOnLoaded("Leatrix_Plus")
        and LeaPlusDB
        and LeaPlusDB["FasterLooting"] == "On"
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")

frame:SetScript("OnEvent", function(self, event)
    if C_AddOns.IsAddOnLoaded("SpeedyAutoLoot") then
        LD.disabledReason = "SpeedyAutoLoot"
        print("|cffff4444[LootDetails]|r Disabled: SpeedyAutoLoot is loaded. Uninstall one to avoid conflicts.")
    elseif leatrixFasterLootEnabled() then
        LD.disabledReason = "LeatrixPlus"
        print("|cffff4444[LootDetails]|r Disabled: Leatrix Plus 'Faster Looting' is on. Disable it or our AutoLoot to avoid conflicts.")
    end
end)
