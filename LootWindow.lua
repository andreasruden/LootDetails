local LD = LootDetails

local WIN_WIDTH, WIN_HEIGHT = 580, 400
local ROW_HEIGHT, ICON_SIZE = 28, 24
local HEADER_H, COL_HEADER_H = 64, 22

-- Column X positions (left edge of each column within scrollChild)
local COL_ICON   = 4
local COL_NAME   = 34
local COL_CHANCE = 360
local COL_QTY    = 420

-------------------------------------------------------------------------------
-- Utility functions (local copies; SlashCommands.lua versions are file-local)
-------------------------------------------------------------------------------

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

-- Returns a compact per-quantity chance string, e.g. "1x: 60%  2x: 40%".
-- Returns nil when there is only ever a single quantity dropped.
local function qtyChanceString(drop)
    if not drop.stacks then return nil end
    local qtys = {}
    for qty in pairs(drop.stacks) do
        table.insert(qtys, qty)
    end
    if #qtys <= 1 then return nil end
    table.sort(qtys)
    local parts = {}
    for _, qty in ipairs(qtys) do
        local pct = drop.stacks[qty] / drop.count * 100
        table.insert(parts, qty .. "x: " .. string.format("%.0f%%", pct))
    end
    return table.concat(parts, "  ")
end

-- Returns the numeric NPC ID stored in mobLoot, trying both key types.
local function getMobEntry(npcID)
    if not LD.db then return nil end
    return LD.db.mobLoot[npcID] or LD.db.mobLoot[tostring(npcID)]
end

-- Maps item quality index to the standard Blizzard color table.
local QUALITY_COLORS = {
    [0] = { r=0.62, g=0.62, b=0.62 }, -- Poor (grey)
    [1] = { r=1,    g=1,    b=1    }, -- Common (white)
    [2] = { r=0.12, g=1,    b=0    }, -- Uncommon (green)
    [3] = { r=0,    g=0.44, b=0.87 }, -- Rare (blue)
    [4] = { r=0.64, g=0.21, b=0.93 }, -- Epic (purple)
    [5] = { r=1,    g=0.50, b=0    }, -- Legendary (orange)
}

local function qualityColor(quality)
    return QUALITY_COLORS[quality] or QUALITY_COLORS[1]
end

-------------------------------------------------------------------------------
-- Window creation (done once, reused)
-------------------------------------------------------------------------------

local win = CreateFrame("Frame", "LootDetailsWindow", UIParent, "BasicFrameTemplateWithInset")
win:SetSize(WIN_WIDTH, WIN_HEIGHT)
win:SetPoint("CENTER")
win:SetMovable(true)
win:EnableMouse(true)
win:RegisterForDrag("LeftButton")
win:SetScript("OnDragStart", win.StartMoving)
win:SetScript("OnDragStop", win.StopMovingOrSizing)
win:SetFrameStrata("DIALOG")
win:Hide()

-- Title / stats text (inside the BasicFrameTemplate title bar area)
win.titleText = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
win.titleText:SetPoint("TOPLEFT", win, "TOPLEFT", 8, -6)
win.titleText:SetPoint("TOPRIGHT", win, "TOPRIGHT", -32, -6)
win.titleText:SetJustifyH("LEFT")

win.statsText = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
win.statsText:SetPoint("TOPLEFT", win.titleText, "BOTTOMLEFT", 0, -4)
win.statsText:SetJustifyH("LEFT")

-- Column header row
local colHeaderFrame = CreateFrame("Frame", nil, win)
colHeaderFrame:SetPoint("TOPLEFT",  win, "TOPLEFT",  8,  -(HEADER_H))
colHeaderFrame:SetPoint("TOPRIGHT", win, "TOPRIGHT", -4, -(HEADER_H))
colHeaderFrame:SetHeight(COL_HEADER_H)

local function makeColLabel(parent, text, xOffset, anchor)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("LEFT", parent, "LEFT", xOffset, 0)
    fs:SetText(text)
    fs:SetTextColor(0.8, 0.8, 0.8)
    return fs
end

makeColLabel(colHeaderFrame, "Item",   COL_NAME,   "LEFT")
makeColLabel(colHeaderFrame, "Chance", COL_CHANCE, "LEFT")
makeColLabel(colHeaderFrame, "Qty",    COL_QTY,    "LEFT")

-- 1px divider beneath the column header
local divider = win:CreateTexture(nil, "ARTWORK")
divider:SetColorTexture(0.4, 0.4, 0.4, 0.8)
divider:SetHeight(1)
divider:SetPoint("TOPLEFT",  colHeaderFrame, "BOTTOMLEFT",  0, -1)
divider:SetPoint("TOPRIGHT", colHeaderFrame, "BOTTOMRIGHT", 0, -1)

-- Scroll frame
local scrollFrame = CreateFrame("ScrollFrame", "LootDetailsScrollFrame", win, "UIPanelScrollFrameTemplate")
local scrollTop = HEADER_H + COL_HEADER_H + 6
scrollFrame:SetPoint("TOPLEFT",     win, "TOPLEFT",     8,  -scrollTop)
scrollFrame:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -26, 8)

local scrollChild = CreateFrame("Frame", "LootDetailsScrollChild", scrollFrame)
scrollChild:SetWidth(WIN_WIDTH - 36)
scrollChild:SetHeight(1) -- dynamically resized
scrollFrame:SetScrollChild(scrollChild)

-------------------------------------------------------------------------------
-- Row pool
-------------------------------------------------------------------------------

local rows = {} -- reused row frames

local function getRow(index)
    if not rows[index] then
        local row = CreateFrame("Frame", nil, scrollChild)
        row:SetHeight(ROW_HEIGHT)

        -- Alternating background
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()

        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(ICON_SIZE, ICON_SIZE)
        row.icon:SetPoint("LEFT", row, "LEFT", COL_ICON, 0)

        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.name:SetPoint("LEFT",  row, "LEFT", COL_NAME,   0)
        row.name:SetPoint("RIGHT", row, "LEFT", COL_CHANCE - 6, 0)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)

        row.chance = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.chance:SetPoint("LEFT", row, "LEFT", COL_CHANCE, 0)
        row.chance:SetWidth(54)
        row.chance:SetJustifyH("LEFT")

        row.qty = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.qty:SetPoint("LEFT", row, "LEFT", COL_QTY, 0)
        row.qty:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        row.qty:SetJustifyH("LEFT")
        row.qty:SetWordWrap(false)

        row:EnableMouse(true)
        rows[index] = row
    end
    return rows[index]
end

-------------------------------------------------------------------------------
-- Populate helpers
-------------------------------------------------------------------------------

-- Pending state for item-cache retries
local pendingNpcID   = nil
local pendingNpcName = nil

local retryFrame = CreateFrame("Frame")
retryFrame:Hide()

local function populateWindow(npcID, npcName)
    local entry = getMobEntry(npcID)

    if not entry or not entry.kills or entry.kills == 0 then
        win.titleText:SetText(npcName)
        win.statsText:SetText("|cffaaaaaa(no data recorded for this NPC)|r")
        -- Hide all rows
        for _, row in ipairs(rows) do row:Hide() end
        scrollChild:SetHeight(1)
        return
    end

    local kills   = entry.kills
    local avgGold = math.floor((entry.totalGold or 0) / kills)
    win.titleText:SetText(npcName)
    win.statsText:SetText(string.format("%d kills  |  Avg gold: %s", kills, copperToString(avgGold)))

    -- Build sorted drop list
    local sorted = {}
    for itemID, drop in pairs(entry.drops or {}) do
        table.insert(sorted, { itemID = tonumber(itemID) or itemID, drop = drop })
    end
    table.sort(sorted, function(a, b)
        return a.drop.count > b.drop.count
    end)

    -- Check whether all item data is loaded; request missing ones
    local allLoaded = true
    for _, row in ipairs(sorted) do
        local name, link, quality = GetItemInfo(row.itemID)
        if not name then
            C_Item.RequestLoadItemDataByID(row.itemID)
            allLoaded = false
        end
        row.cachedName    = name
        row.cachedLink    = link
        row.cachedQuality = quality
    end

    -- If items are still loading, register for retry
    if not allLoaded then
        pendingNpcID   = npcID
        pendingNpcName = npcName
        retryFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    else
        retryFrame:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
        pendingNpcID   = nil
        pendingNpcName = nil
    end

    -- Lay out rows
    local rowCount = #sorted
    scrollChild:SetHeight(math.max(rowCount * ROW_HEIGHT, 1))

    -- Hide surplus rows from a previous call
    for i = rowCount + 1, #rows do
        rows[i]:Hide()
    end

    for i, data in ipairs(sorted) do
        local row  = getRow(i)
        local drop = data.drop

        row:SetPoint("TOPLEFT",  scrollChild, "TOPLEFT",  0, -(i - 1) * ROW_HEIGHT)
        row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, -(i - 1) * ROW_HEIGHT)

        -- Alternating row tint
        if i % 2 == 0 then
            row.bg:SetColorTexture(1, 1, 1, 0.05)
        else
            row.bg:SetColorTexture(0, 0, 0, 0)
        end

        -- Icon
        local texture = data.cachedName and select(10, GetItemInfo(data.itemID))
        if texture then
            row.icon:SetTexture(texture)
            row.icon:Show()
        else
            row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            row.icon:Show()
        end

        -- Name (quality-colored)
        local displayName
        if data.cachedLink then
            displayName = data.cachedLink
        elseif data.cachedName then
            local col = qualityColor(data.cachedQuality)
            displayName = string.format("|cff%02x%02x%02x%s|r",
                col.r * 255, col.g * 255, col.b * 255, data.cachedName)
        else
            displayName = "|cffaaaaaa#" .. tostring(data.itemID) .. "|r"
        end
        row.name:SetText(displayName)

        -- Chance
        local pct = drop.count / kills * 100
        row.chance:SetText(string.format("%.1f%%", pct))

        -- Qty
        local qtyStr = qtyChanceString(drop)
        row.qty:SetText(qtyStr or "")

        -- Tooltip on hover
        row.itemLink = data.cachedLink
        row:SetScript("OnEnter", function(self)
            if self.itemLink then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(self.itemLink)
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        -- Ctrl-click to link in chat
        row:SetScript("OnMouseUp", function(self, btn)
            if btn == "LeftButton" and self.itemLink and IsModifiedClick("CHATLINK") then
                ChatEdit_InsertLink(self.itemLink)
            end
        end)

        row:Show()
    end
end

retryFrame:SetScript("OnEvent", function(self, event, itemID)
    if pendingNpcID then
        populateWindow(pendingNpcID, pendingNpcName)
    end
end)

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

LootWindow = {}

function LootWindow:Show(npcID)
    -- Resolve NPC name from live target if possible
    local npcName
    local targetGuid = UnitExists("target") and UnitGUID("target")
    local targetNpcId = targetGuid and tonumber(targetGuid:match("%-(%d+)%-[^%-]+$"))
    if targetNpcId == npcID then
        npcName = UnitName("target") or ("NPC #" .. npcID)
    else
        npcName = "NPC #" .. npcID
    end

    populateWindow(npcID, npcName)
    win:Show()
end

function LootWindow:Hide()
    pendingNpcID   = nil
    pendingNpcName = nil
    retryFrame:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
    win:Hide()
end
