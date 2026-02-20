local LD = LootDetails

local lootTicker = nil

local function cancelTicker()
    if lootTicker then
        lootTicker:Cancel()
        lootTicker = nil
    end
end

local function startLooting()
    cancelTicker()
    local numSlots = GetNumLootItems()
    if numSlots == 0 then return end

    local slot = numSlots
    lootTicker = C_Timer.NewTicker(0.033, function()
        if slot >= 1 then
            local _, _, _, lootLocked = GetLootSlotInfo(slot)
            if not lootLocked then
                LootSlot(slot)
            end
            slot = slot - 1
        else
            cancelTicker()
        end
    end, numSlots + 1)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("LOOT_OPENED")
frame:RegisterEvent("LOOT_CLOSED")

frame:SetScript("OnEvent", function(self, event, autoLoot)
    if event == "LOOT_OPENED" then
        if not autoLoot then return end
        if not LD.db or not LD.db.options.fastAutoLoot then return end
        -- Defer to next tick so Tracker.lua's LOOT_OPENED handler finishes scanning first
        C_Timer.After(0, startLooting)
    elseif event == "LOOT_CLOSED" then
        cancelTicker()
    end
end)
