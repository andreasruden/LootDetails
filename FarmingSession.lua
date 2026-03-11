local LD = LootDetails

-- LE_ITEM_CLASS_* globals are not available in Classic Era.
local ITEM_CLASS_CONSUMABLE  = 0
local ITEM_CLASS_CONTAINER   = 1
local ITEM_CLASS_WEAPON      = 2
local ITEM_CLASS_GEM         = 3
local ITEM_CLASS_ARMOR       = 4
local ITEM_CLASS_TRADEGOODS  = 7
local ITEM_CLASS_RECIPE      = 9

local MARKETABLE_CLASSES = {
    [ITEM_CLASS_CONSUMABLE]  = true,
    [ITEM_CLASS_CONTAINER]   = true,
    [ITEM_CLASS_GEM]         = true,
    [ITEM_CLASS_TRADEGOODS]  = true,
    [ITEM_CLASS_RECIPE]      = true,
}

-- { sessionId, itemID, quantity, itemLink, quality } for items whose info wasn't in cache yet
local pending = {}

-- sellPrice and classID are the pre-fetched results from GetItemInfo(item.itemID).
local function classifyItem(item, sellPrice, classID)
    if item.quality == 0 then return "vendor" end

    local opts = LD.db.options

    if classID == ITEM_CLASS_WEAPON or classID == ITEM_CLASS_ARMOR then
        local minRarity = opts.equipmentMinRarity or 2
        local mult      = opts.equipmentMarketMultiplier or 2.0
        if item.quality >= minRarity then
            local mv = LD:GetMarketValue(item.itemLink)
            if mv and (sellPrice or 0) > 0 and mv >= sellPrice * mult then
                return "market"
            end
        end
        return "vendor"
    end

    if MARKETABLE_CLASSES[classID] then
        local mult = opts.tradegoodsMarketMultiplier or 1.5
        local mv   = LD:GetMarketValue(item.itemLink)
        if mv and (sellPrice or 0) > 0 and mv >= sellPrice * mult then
            return "market"
        end
    end

    return "vendor"
end

local queryFrame = CreateFrame("Frame")
queryFrame:SetScript("OnEvent", function(self, event, itemID, success)
    if not success then return end

    local remaining = {}
    for _, entry in ipairs(pending) do
        if entry.itemID == itemID then
            local session = LD.db.sessions[entry.sessionId]
            if session then
                local _, _, _, _, _, _, _, _, _, _, sellPrice, classID = GetItemInfo(itemID)
                sellPrice = sellPrice or 0
                local pseudoItem = { quality = entry.quality, itemLink = entry.itemLink, itemID = entry.itemID }
                local classification = classifyItem(pseudoItem, sellPrice, classID)
                if classification == "market" then
                    local mv = LD:GetMarketValue(entry.itemLink)
                    if mv then
                        session.economyValue = session.economyValue + mv * entry.quantity
                    else
                        session.vendorValue = session.vendorValue + sellPrice * entry.quantity
                    end
                else
                    session.vendorValue = session.vendorValue + sellPrice * entry.quantity
                end
            end
        else
            remaining[#remaining + 1] = entry
        end
    end

    pending = remaining
    if #pending == 0 then
        self:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
    end
end)

local function activeSession()
    local id = LD.db.currentSessionId
    if id == -1 then return nil end
    return LD.db.sessions[id]
end

function LD:StartSession()
    if activeSession() then
        print("|cff00ccff[LootDetails]|r A farming session is already active.")
        return
    end

    local id = time()
    LD.db.sessions[id] = {
        startTime       = id,
        kills           = {},
        rawGold         = 0,
        vendorValue     = 0,
        economyValue    = 0,
        paused          = false,
        pausedAt        = nil,
        totalPausedTime = 0,
    }
    LD.db.currentSessionId = id
    LD:Log("Farming session started.")
    LD:Fire("SESSION_STARTED")
end

local function applyItemsToSession(session, sessionId, lootData)
    local vendorValue = 0
    local economyValue = 0
    for _, item in ipairs(lootData.items) do
        local _, _, _, _, _, _, _, _, _, _, sellPrice, classID = GetItemInfo(item.itemID)
        if classID then
            local classification = classifyItem(item, sellPrice or 0, classID)
            if classification == "market" then
                local mv = LD:GetMarketValue(item.itemLink)
                if mv then
                    economyValue = economyValue + mv * item.quantity
                else
                    vendorValue = vendorValue + (sellPrice or 0) * item.quantity
                end
            else
                vendorValue = vendorValue + (sellPrice or 0) * item.quantity
            end
        else
            -- GetItemInfo already triggered a server query; apply value when it arrives
            pending[#pending + 1] = {
                sessionId = sessionId,
                itemID    = item.itemID,
                quantity  = item.quantity,
                itemLink  = item.itemLink,
                quality   = item.quality,
            }
            queryFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
        end
    end
    session.vendorValue  = session.vendorValue + vendorValue
    session.economyValue = session.economyValue + economyValue
end

LD:On("KILL_LOOTED", function(lootData)
    local session = activeSession()
    if not session or session.paused then return end

    local sessionId = LD.db.currentSessionId
    local items = {}
    for _, item in ipairs(lootData.items) do
        items[#items + 1] = { itemID = item.itemID, quantity = item.quantity, itemLink = item.itemLink }
    end

    session.rawGold = session.rawGold + lootData.gold
    applyItemsToSession(session, sessionId, lootData)

    table.insert(session.kills, {
        timestamp = time(),
        npcID     = lootData.npcID,
        guid      = lootData.guid,
        gold      = lootData.gold,
        items     = items,
    })
end)

LD:On("KILL_LOOT_ADDENDUM", function(lootData)
    local session = activeSession()
    if not session or session.paused then return end

    -- Find the existing kill entry for this guid and append late loot to it
    local killEntry
    for _, k in ipairs(session.kills) do
        if k.guid == lootData.guid then
            killEntry = k
            break
        end
    end
    if not killEntry then return end

    local sessionId = LD.db.currentSessionId
    for _, item in ipairs(lootData.items) do
        killEntry.items[#killEntry.items + 1] = { itemID = item.itemID, quantity = item.quantity, itemLink = item.itemLink }
    end
    killEntry.gold = killEntry.gold + lootData.gold
    session.rawGold = session.rawGold + lootData.gold
    applyItemsToSession(session, sessionId, lootData)
end)

function LD:GetActiveSession()
    return activeSession()
end

function LD:PauseSession()
    local session = activeSession()
    if not session or session.paused then return end
    session.paused   = true
    session.pausedAt = time()
    LD:Fire("SESSION_PAUSED")
end

function LD:ResumeSession()
    local session = activeSession()
    if not session or not session.paused then return end
    session.totalPausedTime = session.totalPausedTime + (time() - session.pausedAt)
    session.paused   = false
    session.pausedAt = nil
    LD:Fire("SESSION_RESUMED")
end

function LD:EndSession()
    local session = activeSession()
    if not session then return end

    local id = LD.db.currentSessionId
    LD.db.currentSessionId = -1

    local hasGold = (session.rawGold or 0) + (session.vendorValue or 0) + (session.economyValue or 0) > 0
    if not hasGold then
        LD.db.sessions[id] = nil
    end

    LD:Log("Farming session ended.")
    LD:Fire("SESSION_ENDED")
end
