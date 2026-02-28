local LD = LootDetails

local WIN_WIDTH, WIN_HEIGHT = 270, 196
local CONTENT_TOP = -32   -- y offset below frame top where content rows begin
local ROW_HEIGHT  = 20
local PAD_X       = 12

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

local function formatTime(secs)
    return string.format("%d:%02d:%02d", math.floor(secs / 3600), math.floor(secs % 3600 / 60), secs % 60)
end

local function getElapsedSeconds(session)
    local elapsed = time() - session.startTime - (session.totalPausedTime or 0)
    if session.paused and session.pausedAt then
        elapsed = elapsed - (time() - session.pausedAt)
    end
    return math.max(elapsed, 0)
end

local function calcGPH(session, elapsed)
    if elapsed == 0 then return nil end
    local total = (session.rawGold or 0) + (session.vendorValue or 0) + (session.economyValue or 0)
    return math.floor(total * 3600 / elapsed)
end

-------------------------------------------------------------------------------
-- Window
-------------------------------------------------------------------------------

local win = CreateFrame("Frame", "LootDetailsFarmingWindow", UIParent, "BasicFrameTemplateWithInset")
win:SetSize(WIN_WIDTH, WIN_HEIGHT)
win:SetMovable(true)
win:EnableMouse(true)
win:RegisterForDrag("LeftButton")
win:SetScript("OnDragStart", win.StartMoving)
win:SetFrameStrata("MEDIUM")
win:Hide()

local titleText = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
titleText:SetPoint("TOPLEFT", win, "TOPLEFT", 8, -6)
titleText:SetPoint("TOPRIGHT", win, "TOPRIGHT", -32, -6)
titleText:SetJustifyH("LEFT")
titleText:SetText("Farming Session")

win:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    LD.db.farmingWindowPos = { x = self:GetLeft(), y = self:GetTop() - UIParent:GetHeight() }
end)

-------------------------------------------------------------------------------
-- Stat rows
-------------------------------------------------------------------------------

local rowDefs = { "Time", "Raw Gold", "Vendor Value", "Economy Value", "Total", "GPH" }
local valFields = {}

for i, labelText in ipairs(rowDefs) do
    local yOff = CONTENT_TOP - (i - 1) * ROW_HEIGHT

    local lbl = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint("TOPLEFT", win, "TOPLEFT", PAD_X, yOff)
    lbl:SetText(labelText .. ":")
    lbl:SetJustifyH("LEFT")

    local val = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    val:SetPoint("TOPRIGHT", win, "TOPRIGHT", -PAD_X, yOff)
    val:SetJustifyH("RIGHT")

    valFields[i] = val
end

local valTime    = valFields[1]
local valRaw     = valFields[2]
local valVendor  = valFields[3]
local valEconomy = valFields[4]
local valTotal   = valFields[5]
local valGPH     = valFields[6]

-------------------------------------------------------------------------------
-- Buttons
-------------------------------------------------------------------------------

local pauseBtn = CreateFrame("Button", nil, win, "GameMenuButtonTemplate")
pauseBtn:SetSize(105, 22)
pauseBtn:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", PAD_X, 10)
pauseBtn:SetText("Pause")
pauseBtn:SetScript("OnClick", function()
    local session = LD:GetActiveSession()
    if session and session.paused then
        LD:ResumeSession()
    else
        LD:PauseSession()
    end
end)

local endBtn = CreateFrame("Button", nil, win, "GameMenuButtonTemplate")
endBtn:SetSize(105, 22)
endBtn:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -PAD_X, 10)
endBtn:SetText("End Session")
endBtn:SetScript("OnClick", function()
    LD:EndSession()
end)

-------------------------------------------------------------------------------
-- Update logic
-------------------------------------------------------------------------------

local function updatePauseButton()
    local session = LD:GetActiveSession()
    if session and session.paused then
        pauseBtn:SetText("Resume")
    else
        pauseBtn:SetText("Pause")
    end
end

local function update()
    local session = LD:GetActiveSession()
    if not session then return end

    local elapsed = getElapsedSeconds(session)
    valTime:SetText(formatTime(elapsed))
    valRaw:SetText(copperToString(session.rawGold or 0))
    valVendor:SetText(copperToString(session.vendorValue or 0))
    valEconomy:SetText(copperToString(session.economyValue or 0))

    local total = (session.rawGold or 0) + (session.vendorValue or 0) + (session.economyValue or 0)
    valTotal:SetText(copperToString(total))

    local gph = calcGPH(session, elapsed)
    valGPH:SetText(gph and (copperToString(gph) .. "/hr") or "--")
end

-------------------------------------------------------------------------------
-- Show / hide lifecycle
-------------------------------------------------------------------------------

local posInitialized = false
local ticker

win:SetScript("OnShow", function(self)
    if not posInitialized then
        posInitialized = true
        local pos = LD.db and LD.db.farmingWindowPos
        self:ClearAllPoints()
        if pos then
            self:SetPoint("TOPLEFT", UIParent, "TOPLEFT", pos.x, pos.y)
        else
            self:SetPoint("CENTER")
        end
    end
    updatePauseButton()
    ticker = C_Timer.NewTicker(1, update)
    update()
end)

win:SetScript("OnHide", function()
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
end)

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

LD:On("SESSION_STARTED",     function() win:Show() end)
LD:On("SESSION_WINDOW_OPEN", function() win:Show() end)
LD:On("SESSION_PAUSED",  updatePauseButton)
LD:On("SESSION_RESUMED", updatePauseButton)
LD:On("SESSION_ENDED",   function() win:Hide() end)

local autoOpenDone = false
local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
loginFrame:SetScript("OnEvent", function()
    if autoOpenDone then return end
    autoOpenDone = true
    if LD.db.currentSessionId ~= -1 then
        win:Show()
    end
end)
