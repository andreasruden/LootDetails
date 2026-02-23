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

-- Returns the source GUID for the current loot window.
-- Falls back to UnitGUID("target") for empty corpses (no loot slots available).
local function getSourceGUID()
    if GetNumLootItems() > 0 then
        return GetLootSourceInfo(1)
    end
    local guid = UnitGUID("target")
    if creatureNPCID(guid) then
        return guid
    end
    return nil
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

-- Parses a WoW money string (e.g. "7 Silver\n14 Copper") into copper.
-- Uses WoW's locale format strings so it works across languages.
local function moneyStringToCopper(s)
    if not s then return 0 end
    local copper = 0
    local function extract(fmt, multiplier)
        local pattern = fmt:gsub("%%d", "(%%d+)")
        local n = s:match(pattern)
        if n then copper = copper + tonumber(n) * multiplier end
    end
    extract(GOLD_AMOUNT,   10000)
    extract(SILVER_AMOUNT, 100)
    extract(COPPER_AMOUNT, 1)
    return copper
end

local function collectGold()
    local copper = 0
    for slot = 1, GetNumLootItems() do
        if GetLootSlotType(slot) == LOOT_SLOT_MONEY then
            local _, moneyString = GetLootSlotInfo(slot)
            copper = copper + moneyStringToCopper(moneyString)
        end
    end
    return copper
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("LOOT_READY")

frame:SetScript("OnEvent", function(self, event, autoLoot)
    if LD.db and LD.enabled then
        local guid = getSourceGUID()
        local npcID = creatureNPCID(guid)
        if npcID then
            pruneRecentKills()
            if LD.db.recentlyKilled[guid] then
                LD:Log("skipping duplicate loot for guid", guid)
            else
                LD.db.recentlyKilled[guid] = time()
                local items = collectItems()
                local gold = collectGold()
                LD:Log("KILL_LOOTED npcID=" .. npcID .. " (" .. #items .. " items, " .. gold .. " copper)")
                for _, item in ipairs(items) do
                    LD:Log("  " .. item.itemLink .. " x" .. item.quantity)
                end
                LD:Fire("KILL_LOOTED", {
                    guid      = guid,
                    npcID     = npcID,
                    items     = items,
                    gold      = gold,
                    timestamp = time(),
                })
            end
        end
    end

    LD:Fire("LOOT_SCANNED", autoLoot)
end)
