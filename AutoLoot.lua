local LD = LootDetails

local lootTicker = nil
local isAutoLooting = false
local hasFailure = false

-- Hidden frame used as LootFrame's parent to suppress it (inherits hidden state).
-- Matches SpeedyAutoLoot's _frame approach.
local frame = CreateFrame("Frame")
frame:Hide()

local function cancelTicker()
    if lootTicker then
        lootTicker:Cancel()
        lootTicker = nil
    end
end

local function lootFrameIsNative()
    return LootFrame and LootFrame:IsEventRegistered("LOOT_OPENED")
end

local function showLootFrame(reason)
    LD:Log("showLootFrame:", reason, "native=", lootFrameIsNative(), "parent=", LootFrame and LootFrame:GetParent() and LootFrame:GetParent():GetName())
    if lootFrameIsNative() then LootFrame:SetParent(UIParent) end
end

local function hideLootFrame(reason)
    LD:Log("hideLootFrame:", reason, "native=", lootFrameIsNative(), "parent=", LootFrame and LootFrame:GetParent() and LootFrame:GetParent():GetName())
    if lootFrameIsNative() then LootFrame:SetParent(frame) end
end

-- Pre-hide LootFrame after load so the first autoloot session is already suppressed.
C_Timer.After(0, function() hideLootFrame("startup") end)

-- Checks whether `quantity` of the item referenced by `itemLink` can fit in the player's bags.
-- Returns true for non-item slots (currency, money) when itemLink is nil.
local function itemFitsInBags(itemLink, quantity)
    if not itemLink then return true end

    local itemName, _, _, _, _, _, _, stackCount = C_Item.GetItemInfo(itemLink)
    if not itemName then return true end -- item info not cached yet; optimistic

    local itemFamily = C_Item.GetItemFamily(itemLink) or 0

    -- Classic keys (itemFamily == 256) can go in the keyring
    if itemFamily == 256 then
        local freeSlots = C_Container.GetContainerNumFreeSlots(Enum.BagIndex.Keyring)
        if freeSlots and freeSlots > 0 then return true end
    end

    -- If the item stacks, check whether an existing partial stack has room
    if stackCount and stackCount > 1 then
        local owned = C_Item.GetItemCount(itemLink, false, false)
        local spaceInStack = (stackCount - owned) % stackCount
        if spaceInStack >= quantity then return true end
    end

    -- Walk each bag looking for a compatible free slot
    for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
        local freeSlots, bagFamily = C_Container.GetContainerNumFreeSlots(bag)
        if freeSlots and freeSlots > 0 then
            if bagFamily == 0 or bit.band(itemFamily, bagFamily) > 0 then
                return true
            end
        end
    end

    return false
end

frame:RegisterEvent("LOOT_CLOSED")
frame:RegisterEvent("UI_ERROR_MESSAGE")
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "LOOT_CLOSED" then
        LD:Log("LOOT_CLOSED isAutoLooting=", isAutoLooting, "hasFailure=", hasFailure)
        cancelTicker()
        hideLootFrame("LOOT_CLOSED")
        isAutoLooting = false
        hasFailure = false
    elseif event == "UI_ERROR_MESSAGE" then
        -- Classic may pass 1 or 2 args; message is the second when 2 are present
        local arg1, arg2 = ...
        local message = arg2 or arg1
        if isAutoLooting and (message == ERR_INV_FULL or message == ERR_ITEM_MAX_COUNT) then
            showLootFrame("UI_ERROR_MESSAGE: " .. tostring(message))
        end
    end
end)

LD:On("LOOT_SCANNED", function(autoLoot)
    LD:Log("LOOT_SCANNED autoLoot=", autoLoot, "fastAutoLoot=", LD.db and LD.db.options.fastAutoLoot, "parent=", LootFrame and LootFrame:GetParent() and LootFrame:GetParent():GetName())
    if not autoLoot or not LD.db or not LD.db.options.fastAutoLoot then
        showLootFrame("LOOT_SCANNED no-autoloot")
        return
    end

    isAutoLooting = true
    hasFailure = false

    cancelTicker()
    local slot = GetNumLootItems()
    LD:Log("starting ticker slots=", slot)
    lootTicker = C_Timer.NewTicker(0.033, function()
        if slot >= 1 then
            local slotType = GetLootSlotType(slot)
            if slotType == Enum.LootSlotType.Item then
                -- Anniversary (modern client): name, texture, quantity, currencyID, quality, locked
                local _, _, quantity, _, _, locked = GetLootSlotInfo(slot)
                local itemLink = GetLootSlotLink(slot)
                if not locked and itemFitsInBags(itemLink, quantity) then
                    LootSlot(slot)
                else
                    LD:Log("slot", slot, "skipped locked=", locked, "link=", itemLink)
                    hasFailure = true
                end
            else
                LootSlot(slot) -- money / currency: always loot
            end
            slot = slot - 1
        else
            LD:Log("ticker done hasFailure=", hasFailure)
            if hasFailure then showLootFrame("ticker done with failure") end
            cancelTicker()
        end
    end, slot + 1)
end)
