local LD = LootDetails

local RECENT_KILL_TTL = 15 * 60  -- 15 minutes in seconds

-- Returns npcID (number) if guid is a creature, else nil.
-- Classic GUID format: "Creature-0-realmID-instanceID-zoneUID-npcID-spawnUID"
local function creatureNPCID(guid)
    if not guid then return nil end
    local guidType, _, _, _, _, npcID = strsplit("-", guid)
    if guidType ~= "Creature" then return nil end
    return tonumber(npcID)
end

-- Removes entries from recentlyKilled that are older than RECENT_KILL_TTL.
local function pruneRecentKills()
    local cutoff = time() - RECENT_KILL_TTL
    local tbl = LD.db.recentlyKilled
    for guid, ts in pairs(tbl) do
        if ts < cutoff then
            tbl[guid] = nil
        end
    end
end

local function collectItems()
    local items = {}
    for slot = 1, GetNumLootItems() do
        if GetLootSlotType(slot) == LOOT_SLOT_ITEM then
            local name, texture, quantity, quality = GetLootSlotInfo(slot)
            local link = GetLootSlotLink(slot)
            if link then
                table.insert(items, {
                    itemID   = tonumber(link:match("item:(%d+)")),
                    itemLink = link,
                    name     = name,
                    quantity = quantity or 1,
                    quality  = quality,
                    texture  = texture,
                })
            end
        end
    end
    return items
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("LOOT_OPENED")

frame:SetScript("OnEvent", function(self, event)
    if event ~= "LOOT_OPENED" then return end
    if not LD.db then return end

    local guid = GetLootSourceInfo(1)
    local npcID = creatureNPCID(guid)
    if not npcID then return end

    pruneRecentKills()

    if LD.db.recentlyKilled[guid] then
        LD:Log("skipping duplicate loot for guid", guid)
        return
    end
    LD.db.recentlyKilled[guid] = time()

    local items = collectItems()
    LD:Log("KILL_LOOTED npcID=" .. npcID .. " (" .. #items .. " items)")
    for _, item in ipairs(items) do
        LD:Log("  " .. item.itemLink .. " x" .. item.quantity)
    end

    LD:Fire("KILL_LOOTED", {
        guid      = guid,
        npcID     = npcID,
        items     = items,
        timestamp = time(),
    })
end)
