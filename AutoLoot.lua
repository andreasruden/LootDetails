local LD = LootDetails

LD:On("LOOT_SCANNED", function(autoLoot)
    if not autoLoot then return end
    if not LD.db or not LD.db.options.fastAutoLoot then return end
    if not LD.enabled then return end

    for slot = 1, GetNumLootItems() do
        LootSlot(slot)
    end
end)
