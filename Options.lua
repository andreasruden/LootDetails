local LD = LootDetails

local panel = CreateFrame("Frame")
panel.name = "Loot Details"

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("Loot Details")

local fastLootCB = CreateFrame("CheckButton", "LootDetailsFastAutoLootCB", panel, "ChatConfigCheckButtonTemplate")
fastLootCB:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -16)
fastLootCB.Text:SetText("Fast Auto Loot")
fastLootCB:SetScript("OnClick", function(self)
    if LD.db then
        LD.db.options.fastAutoLoot = self:GetChecked()
    end
end)

local debugCB = CreateFrame("CheckButton", "LootDetailsDebugCB", panel, "ChatConfigCheckButtonTemplate")
debugCB:SetPoint("TOPLEFT", fastLootCB, "BOTTOMLEFT", 0, -8)
debugCB.Text:SetText("Debug Logging")
debugCB:SetScript("OnClick", function(self)
    local checked = self:GetChecked()
    LD.debug = checked
    if LD.db then
        LD.db.options.debug = checked
    end
end)

-------------------------------------------------------------------------------
-- Market value classification
-------------------------------------------------------------------------------

local classifyHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
classifyHeader:SetPoint("TOPLEFT", debugCB, "BOTTOMLEFT", 0, -20)
classifyHeader:SetText("Market Value Classification")

local RARITY_NAMES = { [0]="Poor", [1]="Common", [2]="Uncommon", [3]="Rare", [4]="Epic", [5]="Legendary" }

-- OptionsSliderTemplate's backdrop doesn't render in the modern engine without
-- BackdropTemplate mixin. Add the track texture manually instead.
local function styleSlider(slider)
    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetTexture("Interface\\Buttons\\UI-SliderBar-Background")
    track:SetHorizTile(true)
    track:SetHeight(8)
    track:SetPoint("LEFT", slider, "LEFT", 8, 0)
    track:SetPoint("RIGHT", slider, "RIGHT", -8, 0)
end

local raritySlider = CreateFrame("Slider", "LootDetailsRaritySlider", panel, "OptionsSliderTemplate")
raritySlider:SetPoint("TOPLEFT", classifyHeader, "BOTTOMLEFT", 6, -16)
raritySlider:SetMinMaxValues(0, 5)
raritySlider:SetValueStep(1)
raritySlider.Low:SetText("Poor")
raritySlider.High:SetText("Legendary")
raritySlider:SetScript("OnValueChanged", function(self, value)
    value = math.floor(value + 0.5)
    self.Text:SetText("Equipment Min Rarity: " .. (RARITY_NAMES[value] or value))
    if LD.db then LD.db.options.equipmentMinRarity = value end
end)
styleSlider(raritySlider)

local equipMultSlider = CreateFrame("Slider", "LootDetailsEquipMultSlider", panel, "OptionsSliderTemplate")
equipMultSlider:SetPoint("TOPLEFT", raritySlider, "BOTTOMLEFT", 0, -24)
equipMultSlider:SetMinMaxValues(1.0, 5.0)
equipMultSlider:SetValueStep(0.5)
equipMultSlider.Low:SetText("1.0x")
equipMultSlider.High:SetText("5.0x")
equipMultSlider:SetScript("OnValueChanged", function(self, value)
    self.Text:SetText(string.format("Equipment Market Multiplier: %.1fx", value))
    if LD.db then LD.db.options.equipmentMarketMultiplier = value end
end)
styleSlider(equipMultSlider)

local tradeMultSlider = CreateFrame("Slider", "LootDetailsTradegoodsMultSlider", panel, "OptionsSliderTemplate")
tradeMultSlider:SetPoint("TOPLEFT", equipMultSlider, "BOTTOMLEFT", 0, -24)
tradeMultSlider:SetMinMaxValues(1.0, 5.0)
tradeMultSlider:SetValueStep(0.5)
tradeMultSlider.Low:SetText("1.0x")
tradeMultSlider.High:SetText("5.0x")
tradeMultSlider:SetScript("OnValueChanged", function(self, value)
    self.Text:SetText(string.format("Tradegoods Market Multiplier: %.1fx", value))
    if LD.db then LD.db.options.tradegoodsMarketMultiplier = value end
end)
styleSlider(tradeMultSlider)

local function refreshSliders()
    if not LD.db then return end
    local opts = LD.db.options
    local rarity = opts.equipmentMinRarity or 2
    raritySlider:SetValue(rarity)
    raritySlider.Text:SetText("Equipment Min Rarity: " .. (RARITY_NAMES[rarity] or rarity))
    local em = opts.equipmentMarketMultiplier or 2.0
    equipMultSlider:SetValue(em)
    equipMultSlider.Text:SetText(string.format("Equipment Market Multiplier: %.1fx", em))
    local tm = opts.tradegoodsMarketMultiplier or 1.5
    tradeMultSlider:SetValue(tm)
    tradeMultSlider.Text:SetText(string.format("Tradegoods Market Multiplier: %.1fx", tm))
end

-------------------------------------------------------------------------------

panel.OnCommit = function() end
panel.OnDefault = function() end
panel.OnRefresh = function()
    if not LD.db then return end
    fastLootCB:SetChecked(LD.db.options.fastAutoLoot)
    debugCB:SetChecked(LD.db.options.debug or false)
    refreshSliders()
end

panel:SetScript("OnShow", function()
    if not LD.db then return end
    fastLootCB:SetChecked(LD.db.options.fastAutoLoot)
    debugCB:SetChecked(LD.db.options.debug or false)
    refreshSliders()
end)

local category = Settings.RegisterCanvasLayoutCategory(panel, "Loot Details")
Settings.RegisterAddOnCategory(category)
LD.optionsCategory = category
