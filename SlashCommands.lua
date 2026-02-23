local LD = LootDetails

local function copperToString(copper)
    if copper == 0 then return "0c" end
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    local parts = {}
    if g > 0 then table.insert(parts, g .. "g") end
    if s > 0 then table.insert(parts, s .. "s") end
    if c > 0 then table.insert(parts, c .. "c") end
    return table.concat(parts, " ")
end

-- Returns a formatted string of per-quantity chances, e.g. "1x: 60%  2x: 40%".
-- Returns nil if there is only ever a single quantity.
local function qtyChanceString(drop)
    if not drop.stacks then return nil end
    local qtys = {}
    for qty in pairs(drop.stacks) do
        table.insert(qtys, qty)
    end
    table.sort(qtys)
    local parts = {}
    for _, qty in ipairs(qtys) do
        local pct = drop.stacks[qty] / drop.count * 100
        table.insert(parts, qty .. "x: " .. string.format("%.0f%%", pct))
    end
    return table.concat(parts, "  ")
end

local function getMobEntry(npcID)
    if not LD.db then return nil end
    -- Try numeric key first, then string key for backwards compatibility
    return LD.db.mobLoot[npcID] or LD.db.mobLoot[tostring(npcID)]
end

local function cmdList()
    if not LD.db then
        print("|cff00ccff[LootDetails]|r DB not loaded.")
        return
    end
    local count = 0
    for k, v in pairs(LD.db.mobLoot) do
        print(string.format("  NPC %s (key type: %s) — %d kills", tostring(k), type(k), v.kills or 0))
        count = count + 1
    end
    if count == 0 then
        print("|cff00ccff[LootDetails]|r No NPC data recorded.")
    end
end

local function cmdDump(args)
    local npcID = tonumber(args)
    if not npcID then
        print("|cff00ccff[LootDetails]|r Usage: /ld dump <npc id>")
        return
    end

    local entry = getMobEntry(npcID)
    if not entry then
        print("|cff00ccff[LootDetails]|r No data for NPC #" .. npcID)
        return
    end

    local kills = entry.kills
    local avgGold = kills > 0 and math.floor((entry.totalGold or 0) / kills) or 0
    print(string.format("|cff00ccff[LootDetails]|r NPC #%d — %d kills | Avg Gold: %s",
        npcID, kills, copperToString(avgGold)))

    -- Sort drops from highest drop rate to lowest
    local sorted = {}
    for itemID, drop in pairs(entry.drops) do
        table.insert(sorted, { itemID = itemID, drop = drop })
    end
    table.sort(sorted, function(a, b)
        return a.drop.count > b.drop.count
    end)

    for _, row in ipairs(sorted) do
        local drop     = row.drop
        local dropRate = drop.count / kills * 100
        local link     = select(2, GetItemInfo(row.itemID)) or ("|cffffffff#" .. row.itemID .. "|r")
        local chances  = qtyChanceString(drop)

        if chances then
            print(string.format("  %s  |cffaaaaaa%.1f%% drop  (%s)|r", link, dropRate, chances))
        else
            print(string.format("  %s  |cffaaaaaa%.1f%% drop|r", link, dropRate))
        end
    end

    if #sorted == 0 then
        print("  |cffaaaaaa(no item drops recorded)|r")
    end
end

local handlers = {
    dump = cmdDump,
    list = cmdList,
}

SLASH_LOOTDETAILS1 = "/ld"
SlashCmdList["LOOTDETAILS"] = function(msg)
    local cmd, args = msg:match("^(%S+)%s*(.*)")
    if not cmd then
        print("|cff00ccff[LootDetails]|r Commands: dump, list")
        return
    end
    local handler = handlers[cmd:lower()]
    if handler then
        handler(args)
    else
        print("|cff00ccff[LootDetails]|r Unknown command: " .. cmd .. ". Commands: dump, list")
    end
end
