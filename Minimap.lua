local LD = LootDetails

local LDB = LibStub("LibDataBroker-1.1")
local LibDBIcon = LibStub("LibDBIcon-1.0")

local dataObject = LDB:NewDataObject("LootDetails", {
    type = "data source",
    icon = "Interface\\Icons\\INV_Misc_Bag_07",

    OnClick = function(self, button)
        if button == "RightButton" then
            Settings.OpenToCategory(LD.optionsCategory:GetID())
            return
        end

        -- Left click: context-sensitive on hostile NPC vs. open farming session
        if UnitExists("target") and not UnitIsPlayer("target") and UnitCanAttack("player", "target") then
            local guid = UnitGUID("target")
            -- GUID format: "Creature-0-XXXX-XXXX-XXXX-NPCID-XXXX"
            local npcId = guid and tonumber(guid:match("%-(%d+)%-[^%-]+$"))
            if npcId then
                LootWindow:Show(npcId)
            else
                print("|cff00ccff[LootDetails]|r Could not determine NPC ID from GUID:", tostring(guid))
            end
        elseif LD:GetActiveSession() then
            LD:Fire("SESSION_WINDOW_OPEN")
        else
            LD:StartSession()
        end
    end,

    OnTooltipShow = function(tooltip)
        tooltip:AddLine("LootDetails")
        tooltip:AddLine(" ")

        local status = LD:GetSyncStatus()
        if status.mode == "solo" then
            tooltip:AddLine("|cff00ff00Active Solo|r")
        elseif status.mode == "party_active" then
            tooltip:AddLine("|cff00ff00Active in Party|r")
        else
            if #status.unmatched == 0 then
                tooltip:AddLine("|cffffff00Inactive in Party|r")
            else
                for _, m in ipairs(status.unmatched) do
                    if m.reason == "no_addon" then
                        tooltip:AddLine("|cffff4444Inactive|r — " .. m.name .. " does not have addon")
                    else
                        tooltip:AddLine("|cffff4444Inactive|r — " .. m.name .. " has a different version")
                    end
                end
            end
        end

        tooltip:AddLine(" ")
        tooltip:AddLine("|cffeda55fLeft-click|r (hostile NPC targeted): show NPC stats")
        tooltip:AddLine("|cffeda55fLeft-click|r (no hostile target): start farming session")
        tooltip:AddLine("|cffeda55fRight-click|r: open options")
    end,
})

-- Wait for LD.db to be initialized before registering the icon.
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, name)
    if name ~= "LootDetails" then return end
    self:UnregisterEvent("ADDON_LOADED")
    LibDBIcon:Register("LootDetails", dataObject, LD.db.minimapButton)
end)
