local LD = LootDetails

-- { sessionId, itemID, quantity } for items whose sell price wasn't in cache yet
local pending = {}

local queryFrame = CreateFrame("Frame")
queryFrame:SetScript("OnEvent", function(self, event, itemID, success)
    if not success then return end

    local remaining = {}
    for _, entry in ipairs(pending) do
        if entry.itemID == itemID then
            local session = LD.db.sessions[entry.sessionId]
            if session then
                local sellPrice = select(11, GetItemInfo(itemID)) or 0
                session.vendorValue = session.vendorValue + sellPrice * entry.quantity
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

LD:On("KILL_LOOTED", function(lootData)
    local session = activeSession()
    if not session or session.paused then return end

    local sessionId = LD.db.currentSessionId
    local items = {}
    local vendorValue = 0
    for _, item in ipairs(lootData.items) do
        items[#items + 1] = { itemID = item.itemID, quantity = item.quantity, itemLink = item.itemLink }
        local sellPrice = select(11, GetItemInfo(item.itemID))
        if sellPrice then
            vendorValue = vendorValue + sellPrice * item.quantity
        else
            -- GetItemInfo already triggered a server query; apply sell price when it arrives
            pending[#pending + 1] = { sessionId = sessionId, itemID = item.itemID, quantity = item.quantity }
            queryFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
        end
    end

    session.rawGold     = session.rawGold + lootData.gold
    session.vendorValue = session.vendorValue + vendorValue

    table.insert(session.kills, {
        timestamp = time(),
        npcID     = lootData.npcID,
        guid      = lootData.guid,
        gold      = lootData.gold,
        items     = items,
    })
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
