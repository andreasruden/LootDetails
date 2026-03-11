local LD = LootDetails

local QUEUE_TTL = 10
local myVersion           -- string, set on ADDON_LOADED
local memberVersions = {} -- [name] = version string
local syncActive = false
local wasInGroup = false
local queue = {}          -- [guid] = { npcID, gold, items, timestamp, gen }

local function allMembersMatch()
    local count = GetNumGroupMembers()
    if count <= 1 then return false end
    for i = 1, count - 1 do
        local name = UnitName("party" .. i)
        if not name or memberVersions[name] ~= myVersion then return false end
    end
    return true
end

local function updateSyncActive()
    local prev = syncActive
    syncActive = LD.disabledReason == "party" and allMembersMatch()
    if syncActive ~= prev then
        LD:Log("Sync: syncActive =", syncActive)
    end
end

local function serializeLoot(loot)
    local parts = { "LOOT", loot.guid, loot.npcID, loot.gold }
    for _, item in ipairs(loot.items) do
        parts[#parts + 1] = item.itemID .. ":" .. item.quantity .. ":" .. item.quality
    end
    return table.concat(parts, "|")
end

local function deserializeLoot(msg)
    local fields = { strsplit("|", msg) }
    if fields[1] ~= "LOOT" then return nil end
    local guid, npcID, gold = fields[2], tonumber(fields[3]), tonumber(fields[4])
    if not guid or not npcID or not gold then return nil end
    local items = {}
    for i = 5, #fields do
        local id, qty, qual = strsplit(":", fields[i])
        local itemID = tonumber(id)
        if itemID then
            items[#items + 1] = { itemID = itemID, quantity = tonumber(qty), quality = tonumber(qual), itemLink = "item:" .. itemID }
        end
    end
    return { guid = guid, npcID = npcID, gold = gold, items = items, timestamp = time() }
end

local function scheduleExpiry(guid)
    local entry = queue[guid]
    if not entry then return end
    local gen = entry.gen
    LD:Log("Sync: timer scheduled for guid=" .. guid .. " gen=" .. gen)
    C_Timer.After(QUEUE_TTL, function()
        local e = queue[guid]
        if not e or e.gen ~= gen then
            LD:Log("Sync: timer expired (stale) guid=" .. guid .. " gen=" .. gen)
            return
        end
        queue[guid] = nil
        LD:Log("Sync: firing KILL_LOOTED for guid=" .. guid .. " npcID=" .. e.npcID .. " (" .. #e.items .. " items, " .. e.gold .. " copper)")
        LD:Fire("KILL_LOOTED", { guid = guid, npcID = e.npcID, items = e.items, gold = e.gold, timestamp = e.timestamp })
    end)
end

local function mergeIntoQueue(loot)
    local guid = loot.guid
    local entry = queue[guid]
    if entry then
        LD:Log("Sync: merging into existing queue entry guid=" .. guid .. " (+" .. loot.gold .. " copper, +" .. #loot.items .. " item types)")
        entry.gold = entry.gold + loot.gold
        local byID = {}
        for _, item in ipairs(entry.items) do byID[item.itemID] = item end
        for _, item in ipairs(loot.items) do
            if byID[item.itemID] then
                byID[item.itemID].quantity = byID[item.itemID].quantity + item.quantity
            else
                entry.items[#entry.items + 1] = item
                byID[item.itemID] = item
            end
        end
        entry.gen = entry.gen + 1
        scheduleExpiry(guid)
    else
        LD:Log("Sync: queuing new entry guid=" .. guid .. " npcID=" .. loot.npcID .. " (" .. #loot.items .. " items, " .. loot.gold .. " copper)")
        queue[guid] = { npcID = loot.npcID, gold = loot.gold, items = loot.items, timestamp = loot.timestamp, gen = 1 }
        scheduleExpiry(guid)
    end
end

-- Returns status info for display. Called by Minimap.lua tooltip.
function LD:GetSyncStatus()
    if not IsInGroup() then
        return { mode = "solo" }
    end
    if syncActive then
        return { mode = "party_active" }
    end
    -- Build list of unmatched members with reason
    local unmatched = {}
    for i = 1, GetNumGroupMembers() - 1 do
        local name = UnitName("party" .. i)
        if name then
            if not memberVersions[name] then
                unmatched[#unmatched + 1] = { name = name, reason = "no_addon" }
            elseif memberVersions[name] ~= myVersion then
                unmatched[#unmatched + 1] = { name = name, reason = "version_mismatch" }
            end
        end
    end
    return { mode = "party_inactive", unmatched = unmatched }
end

LD:On("KILL_LOOT_SHARED", function(loot)
    if not syncActive then
        LD:Log("Sync: ignoring KILL_LOOT_SHARED (syncActive=false)")
        return
    end
    mergeIntoQueue(loot)
    C_ChatInfo.SendAddonMessage("LootDetails", serializeLoot(loot), "PARTY")
    LD:Log("Sync: broadcast loot npcID=" .. loot.npcID .. " to party")
end)

local function clearState()
    LD:Log("Sync: clearing state (left group)")
    memberVersions = {}
    queue = {}
    syncActive = false
end

local function sendHi()
    if LD.disabledReason ~= "party" then return end
    memberVersions = {}
    syncActive = false
    LD:Log("Sync: sending Hi " .. myVersion)
    C_ChatInfo.SendAddonMessage("LootDetails", "Hi " .. myVersion, "PARTY")
end

local syncFrame = CreateFrame("Frame")
syncFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
syncFrame:RegisterEvent("CHAT_MSG_ADDON")
syncFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "GROUP_ROSTER_UPDATE" then
        if not IsInGroup() then
            if wasInGroup then clearState() end
            wasInGroup = false
            return
        end
        -- Prune departed members
        local current = {}
        for i = 1, GetNumGroupMembers() - 1 do
            local name = UnitName("party" .. i)
            if name then current[name] = true end
        end
        for name in pairs(memberVersions) do
            if not current[name] then
                LD:Log("Sync: " .. name .. " left, removing from memberVersions")
                memberVersions[name] = nil
            end
        end
        if not wasInGroup then
            sendHi()
        end
        wasInGroup = true
        updateSyncActive()

    elseif event == "CHAT_MSG_ADDON" then
        local prefix, msg, _, sender = ...
        if prefix ~= "LootDetails" then return end
        if LD.disabledReason ~= "party" then return end
        local name = Ambiguate(sender, "short")
        if name == Ambiguate(UnitName("player"), "short") then return end  -- skip self-echo

        if msg:sub(1, 3) == "Hi " then
            local ver = msg:sub(4)
            memberVersions[name] = ver
            LD:Log("Sync: got Hi from " .. name .. " v" .. ver .. ", replying Hello")
            C_ChatInfo.SendAddonMessage("LootDetails", "Hello " .. myVersion, "PARTY")
            updateSyncActive()
        elseif msg:sub(1, 6) == "Hello " then
            local ver = msg:sub(7)
            local isNew = not memberVersions[name]
            memberVersions[name] = ver
            LD:Log("Sync: got Hello from " .. name .. " v" .. ver)
            if isNew then
                -- They may have missed our Hi; reply so they learn our version
                LD:Log("Sync: replying Hello to unsolicited Hello from " .. name)
                C_ChatInfo.SendAddonMessage("LootDetails", "Hello " .. myVersion, "PARTY")
            end
            updateSyncActive()
        elseif msg:sub(1, 5) == "LOOT|" then
            if not syncActive then return end
            local loot = deserializeLoot(msg)
            if loot then
                LD:Log("Sync: received loot from " .. name .. " npcID=" .. loot.npcID .. " (" .. #loot.items .. " items, " .. loot.gold .. " copper)")
                mergeIntoQueue(loot)
            else
                LD:Log("Sync: failed to deserialize LOOT message from " .. name)
            end
        end
    end
end)

local versionFrame = CreateFrame("Frame")
versionFrame:RegisterEvent("ADDON_LOADED")
versionFrame:SetScript("OnEvent", function(self, event, name)
    if name ~= "LootDetails" then return end
    myVersion = C_AddOns.GetAddOnMetadata("LootDetails", "Version") or "unknown"
    C_ChatInfo.RegisterAddonMessagePrefix("LootDetails")
    LD:Log("Sync: initialized, version=" .. myVersion)
    self:UnregisterEvent("ADDON_LOADED")
    if IsInGroup() then
        wasInGroup = true
        sendHi()
    end
end)
