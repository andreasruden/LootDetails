local LD = LootDetails

LD:On("KILL_LOOTED", function(lootData)
    local mobLoot = LD.db.mobLoot
    local npcID = lootData.npcID

    if not mobLoot[npcID] then
        mobLoot[npcID] = { kills = 0, drops = {} }
    end

    local entry = mobLoot[npcID]
    entry.kills = entry.kills + 1

    local drops = entry.drops
    for _, item in ipairs(lootData.items) do
        local id  = item.itemID
        local qty = item.quantity

        if not drops[id] then
            drops[id] = { count = 0, stacks = nil }
        end

        local drop = drops[id]
        drop.count = drop.count + 1

        if qty > 1 then
            if not drop.stacks then
                -- Retroactively assign all prior observations as qty=1
                drop.stacks = { [1] = drop.count - 1, [qty] = 1 }
            else
                drop.stacks[qty] = (drop.stacks[qty] or 0) + 1
            end
        elseif drop.stacks then
            drop.stacks[1] = (drop.stacks[1] or 0) + 1
        end
    end
end)
