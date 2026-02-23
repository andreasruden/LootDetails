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

panel.OnCommit = function() end
panel.OnDefault = function() end
panel.OnRefresh = function()
    if not LD.db then return end
    fastLootCB:SetChecked(LD.db.options.fastAutoLoot)
    debugCB:SetChecked(LD.db.options.debug or false)
end

panel:SetScript("OnShow", function()
    if not LD.db then return end
    fastLootCB:SetChecked(LD.db.options.fastAutoLoot)
    debugCB:SetChecked(LD.db.options.debug or false)
end)

local category = Settings.RegisterCanvasLayoutCategory(panel, "Loot Details")
Settings.RegisterAddOnCategory(category)
LD.optionsCategory = category
