local LD = LootDetails

local CALLER_ID = "LootDetails"
local STALE_THRESHOLD_DAYS = 7

local function isAuctionatorAvailable()
    return C_AddOns.IsAddOnLoaded("Auctionator")
        and Auctionator
        and Auctionator.API
        and Auctionator.API.v1 ~= nil
end

-- Returns price in coppers and a staleness flag.
-- price:   number (coppers) or nil if unknown
-- isStale: true if data is older than STALE_THRESHOLD_DAYS, nil if price is nil
function LD:GetMarketValue(itemLink)
    if not isAuctionatorAvailable() or type(itemLink) ~= "string" then
        return nil
    end

    local price = Auctionator.API.v1.GetAuctionPriceByItemLink(CALLER_ID, itemLink)
    if price == nil then
        return nil
    end

    -- GetAuctionAgeByItemLink returns days (number) or nil if >21 days or no data.
    -- Either case is treated as stale.
    local age = Auctionator.API.v1.GetAuctionAgeByItemLink(CALLER_ID, itemLink)
    local isStale = (age == nil) or (age > STALE_THRESHOLD_DAYS)

    return price, isStale
end
