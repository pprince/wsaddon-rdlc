----------------------------------------------------------------------------------------------
-- RollingDiceLootCouncil - Psyphil <Catharsis>
-- Last update: 25/03/2015


local tStats = {
	[Unit.CodeEnumProperties.Strength]                   = {label = "Brutality",     short = "B"},
	[Unit.CodeEnumProperties.Dexterity]                  = {label = "Finesse",       short = "F"},
	[Unit.CodeEnumProperties.Technology]                 = {label = "Tech",          short = "T"},
	[Unit.CodeEnumProperties.Magic]                      = {label = "Moxie",         short = "M"},
	[Unit.CodeEnumProperties.Wisdom]                     = {label = "Insight",       short = "F"},
	[Unit.CodeEnumProperties.Stamina]                    = {label = "Grit",          short = "G"},
	[Unit.CodeEnumProperties.AssaultPower]               = {label = "Assault Power", short = "AP"},
	[Unit.CodeEnumProperties.SupportPower]               = {label = "Support Power", short = "SP"},
	[Unit.CodeEnumProperties.Rating_CritChanceIncrease]  = {label = "Crit",          short = "CHR"},
	[Unit.CodeEnumProperties.RatingCritSeverityIncrease] = {label = "Crit Severity", short = "CSR"},
	[Unit.CodeEnumProperties.Rating_AvoidReduce]         = {label = "Strikethrough", short = "SR"},
	[Unit.CodeEnumProperties.Armor]                      = {label = "Armor",         short = "A"},
	[Unit.CodeEnumProperties.ShieldCapacityMax]          = {label = "Shield",        short = "S"},
	[Unit.CodeEnumProperties.Rating_AvoidIncrease]       = {label = "Deflect",       short = "DR"},
	[Unit.CodeEnumProperties.Rating_CritChanceDecrease]  = {label = "Deflect Crit",  short = "DCR"},
	[Unit.CodeEnumProperties.PvPOffensiveRating]         = {label = "PvP Power",     short = " PvP PR"},
	[Unit.CodeEnumProperties.PvPDefensiveRating]         = {label = "PvP Defense",   short = " PvP DR"},
	[Unit.CodeEnumProperties.ManaPerFiveSeconds]         = {label = "Focus Regen",   short = "FR"},
	[Unit.CodeEnumProperties.BaseHealth]                 = {label = "Base Health",   short = "BH"},
}

local tItemQualities = {
	[Item.CodeEnumItemQuality.Inferior]  = {label = "Inferior",  color = "ItemQuality_Inferior"},
	[Item.CodeEnumItemQuality.Average]   = {label = "Average",   color = "ItemQuality_Average"},
	[Item.CodeEnumItemQuality.Good]      = {label = "Good",      color = "ItemQuality_Good"},
	[Item.CodeEnumItemQuality.Excellent] = {label = "Excellent", color = "ItemQuality_Excellent"},
	[Item.CodeEnumItemQuality.Superb]    = {label = "Superb",    color = "ItemQuality_Superb"},
	[Item.CodeEnumItemQuality.Legendary] = {label = "Legendary", color = "ItemQuality_Legendary"},
	[Item.CodeEnumItemQuality.Artifact]  = {label = "Artifact",  color = "ItemQuality_Artifact"},
}
local tClassFromId = {
	"Warrior",
	"Engineer",
	"Esper",
	"Medic",
	"Stalker",
	"",
	"Spellslinger" 
}

--local [ChatSystemLib.ChatChannel_Party] = { Channel = "ChannelParty" }
local allChannels = ChatSystemLib.GetChannels()
local activeChannel = ChatSystemLib.ChatChannel_Party
local bCurrDistributing = false
local currItem = ""
local tLooters = ""
local tItemList = ""

-----------------------------------------------------------------------------------------------
-- Init

RollingDiceLootCouncil = {
	name = "RollingDiceLootCouncil",
	version = "0.9.5",

	nMaxItems = 80000,        -- FIXME: tune these
	nMaxDisplayedItems = 500, -- 
	nScanPerTick = 300,       --- probably needs something like
	nShowPerTick = 2000,      --- nShowPerTick/fShowInterval > nScanPerTick/fScanInterval
	fScanInterval = 1/20,     --- to ensure we display items faster than we scan them
	fShowInterval = 1/4,      --- so we don't hit 100% with more than nMaxDisplayedItems waiting to be drawn
 	
	tCategoryFilters = {},
	tSlotFilters = {},
	tStatFilters = {},
	tQualityFilters = {},
	tPriceFilters = {},
	nILvlMin = nil,
	nILvlMax = nil,
	
	tItems = {},
	nScanIndex = 1,
	nShowIndex = 1,
} 

function RollingDiceLootCouncil:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("RollingDiceLootCouncil.xml")
    self.wndMain = Apollo.LoadForm(self.xmlDoc, "RollingDiceLootCouncil", nil, self)

	self.wndItemList = self.wndMain:FindChild("ItemList")
	self.wndLeftSide = self.wndMain:FindChild("ToolTipContainer")
	self.HeaderNav = self.wndMain:FindChild("HeaderNav")
	self.wndStatusBar = self.wndMain:FindChild("StatusBar")
	self.btnDistribution = self.wndMain:FindChild("StartDistributionBtn")

	Apollo.RegisterSlashCommand("lootcouncil", "OnSlashCommand", self)
	Apollo.RegisterSlashCommand("lc", "OnSlashCommand", self)
	Apollo.RegisterSlashCommand("lctest", "OnTestCommand", self)
	
	Apollo.RegisterEventHandler("ChatMessage", 					"OnChatMessage", self)
	Apollo.RegisterEventHandler("MasterLootUpdate",				"OnMasterLootUpdate", self)
	
	--self.ICComm = ICCommLib.JoinChannel("LootCouncil", "OnICCommMessageReceived", self)
	
	tItemList = {}
end

-----------------------------------------------------------------------------------------------
-- OnMasterLootUpdate
-----------------------------------------------------------------------------------------------
function RollingDiceLootCouncil:OnMasterLootUpdate()
--tMasterLoot contains the keys tLooters, itemDrop, nLootId, bIsMaster
	--tLooters: table with keys 1,2,3,etc contains Units viable for loot (in range)
	--itemDrop: contains Item that dropped
	--nLootId: individual item ID
	--bIsMaster}: true/false if you are masterlooter

	local tMasterLoot = GameLib.GetMasterLoot() 
	
	tLooters = {}
	tItemList = {}
	
	for i, value in pairs(tMasterLoot) do
	
		table.insert(tItemList, self:GetItemData(tMasterLoot[i]["itemDrop"]))
		
		for n, value in pairs(tMasterLoot[i]["tLooters"]) do
			table.insert(tLooters, tMasterLoot[i]["tLooters"][n])
		end
	end
	
	if table.getn(tItemList) == 0 then
		self.wndMain:FindChild("ItemCheckBtn"):SetText("No items found")
	elseif table.getn(tItemList) == 1 then
		self.wndMain:FindChild("ItemCheckBtn"):SetText(table.getn(tItemList) .. " item found")
	else
		self.wndMain:FindChild("ItemCheckBtn"):SetText(table.getn(tItemList) .. " items found")
	end
	
	self:CheckRaidAssist()
end

function RollingDiceLootCouncil:OnTestCommand()
	tItemList = {}
	for i = 69886, 69891 do
		local item = Item.GetDataFromId(i)
		table.insert(tItemList, self:GetItemData(item))
	end
end

-----------------------------------------------------------------------------------------------
-- UI Calls
-----------------------------------------------------------------------------------------------

--create ui
function RollingDiceLootCouncil:ShowItemTooltip(item)

	self.wndLeftSide:DestroyChildren()
	if item then
		Tooltip.GetItemTooltipForm(self, self.wndLeftSide, item, {bPermanent = true, wndParent = self.wndLeftSide, bNotEquipped = true})
	end	
end

function RollingDiceLootCouncil:PopulateGearBtn(item)
	local btnUserGear = self.wndMain:FindChild("UserGearBtn")
	local item = self:GetItemData(item)
	itemEquipped = 0
	
	if item then
		local equipped = GameLib.GetPlayerUnit():GetEquippedItems()
		if not equipped then return end
		
		for _, iteminfo in pairs(equipped) do
			if item.eSlot == iteminfo:GetInventoryId() then
				local itemGear = self:GetItemData(iteminfo)
				btnUserGear:SetData(itemGear)
				btnUserGear:FindChild("ItemGearIcon"):GetWindowSubclass():SetItem(itemGear.item)
				itemEquipped = 1
			end
		end
	end
	if itemEquipped == 0 then
		btnUserGear:SetData({})
		btnUserGear:FindChild("ItemGearIcon"):GetWindowSubclass():SetItem("")
	end
end

function RollingDiceLootCouncil:OnOpenDropdown( wndHandler, wndControl, eMouseButton )

	wndDropdown = self.wndMain:FindChild("ItemDropDown")
	local wndDropdownList = wndDropdown:FindChild("ListDropDown")
	local EmptyLabel = wndDropdown:FindChild("EmptyLabel")
	
	EmptyLabel:Show(false)
	wndDropdown:Show(true)
	wndDropdownList:DestroyChildren()
	
	if not tItemList then
		EmptyLabel:Show(true)
		return
	end
	
	for i, v in pairs(tItemList) do
		local wndItem = Apollo.LoadForm(self.xmlDoc, "DropDownItem", wndDropdownList, self)
		wndItem:SetData(tItemList[i])
		wndItem:FindChild("ItemDropIcon"):GetWindowSubclass():SetItem(tItemList[i].item)
		
		local wndItemLabel = wndItem:FindChild("Label")
		wndItemLabel:SetText(tItemList[i].strName)
		wndItemLabel:SetTextColor(tItemQualities[tItemList[i].eQuality].color)
	end
	
	wndDropdownList:ArrangeChildrenVert()
end

function RollingDiceLootCouncil:ListItem(tSegment, sender)
	-- List Item
	local item = self:GetItemData(tSegment.uItem)
	local wndItem = Apollo.LoadForm(self.xmlDoc, "Item", self.wndItemList, self)
	local wndItemText = wndItem:FindChild("ItemText")
	
	wndItem:SetData(item)
	wndItem:FindChild("ItemIcon"):GetWindowSubclass():SetItem(item.item)
	wndItemText:SetText(item.strName .. "\n" 
						.. item.item:GetItemTypeName() 
						.. " - iLvl : "
						.. item.nEffectiveLevel
    		            .. "\n" .. self.StatsString(item)) 
						
	wndItemText:SetTextColor(tItemQualities[item.eQuality].color)
	
	--List character
	local wndChar = wndItem:FindChild("CharacterName")
	local wndClass = wndItem:FindChild("ClassIcon")
	
	wndChar:SetText(sender)

	if tLooters ~= "" then
		for i, value in pairs(tLooters) do
			if sender == tLooters[i]:GetName() then
				local strClass = tLooters[i]:GetClassId()
				if strClass == 1 then
					strClass = "Warrior"
				elseif strClass == 2 then
					strClass = "Engineer"
				elseif strClass == 3 then
					strClass = "Esper"
				elseif strClass == 4 then
					strClass = "Medic"
				elseif strClass == 5 then
					strClass = "Stalker"
				elseif strClass == 7 then
					strClass = "Spellslinger"
				end
				
				wndClass:SetSprite("Icon_Windows_UI_CRB_" .. strClass)
			end
		end
	else
		wndClass:SetSprite("")
	end
	
	self.wndItemList:ArrangeChildrenVert()
end

--buttons
function RollingDiceLootCouncil:OnItemCheck( wndHandler, wndControl, eMouseButton )

	self.wndMain:FindChild("ItemCheckBtn"):SetCheck(false)
	currItem = wndControl:GetData().item
	self:ShowItemTooltip(currItem)
	self:PopulateGearBtn(currItem)
	wndDropdown:Show(false)
end

function RollingDiceLootCouncil:OnItemClick(wndHandler, wndControl, eMouseButton)
	if eMouseButton == GameLib.CodeEnumInputMouse.Right then
		Event_FireGenericEvent("ItemLink", wndControl:GetData().item)
	end
end

function RollingDiceLootCouncil:OnClose()
	self.wndMain:Close()
end

--Mouse
function RollingDiceLootCouncil:OnItemMouseEnter(wndHandler, wndControl, x, y)
	if wndControl:GetData() then
		Tooltip.GetItemTooltipForm(self, wndControl, wndControl:GetData().item, {})
	end
end


-- Init
function RollingDiceLootCouncil:OnSlashCommand() 
	self:OnMasterLootUpdate()
	self.wndMain:Invoke()
end

Apollo.RegisterAddon(RollingDiceLootCouncil)

---------------------------------------------------------------------------------------------------
-- RollingDiceLootCouncil Functions
---------------------------------------------------------------------------------------------------

function RollingDiceLootCouncil:CheckRaidAssist()
	local groupMember = GroupLib.GetGroupMember(1)
	if groupMember and (groupMember.bIsLeader or groupMember.bMainTank or groupMember.bMainAssist or groupMember.bRaidAssistant) then
		self.wndStatusBar:Show(false)
		self.HeaderNav:Show(true)
	elseif groupMember then
		self.wndStatusBar:Show(true)
		self.HeaderNav:Show(false)	
	else
		self.wndStatusBar:Show(false)
		self.HeaderNav:Show(true)	
	end
end

function RollingDiceLootCouncil:OnStartDistribution( wndHandler, wndControl, eMouseButton)
	if currItem ~= "" then
	
		allChannels[activeChannel]:Send( "==============================="						)
		allChannels[activeChannel]:Send( "== Distributing " .. currItem:GetChatLinkString()		)
		allChannels[activeChannel]:Send( "== Link your current gear piece or write \"pass\""	)
		--allChannels[activeChannel]:Send( "==============================="						)

	else
		self.btnDistribution:SetCheck(false)
	end
end

function RollingDiceLootCouncil:OnStopDistribution( wndHandler, wndControl, eMouseButton, external )
	if bCurrDistributing then
		allChannels[activeChannel]:Send( "== Distribution ended")
	end
end

function RollingDiceLootCouncil:LinkItem( wndHandler, wndControl, eMouseButton )
	if itemEquipped == 1 and bCurrDistributing then
		allChannels[activeChannel]:Send( wndControl:GetData().item:GetChatLinkString() )
	end
end

-----------------------------------------------------------------------------------------------
-- RollingDiceLootCouncil Chat Functions
-----------------------------------------------------------------------------------------------
function RollingDiceLootCouncil:OnChatMessage(channelCurrent, tMessage)

	if channelCurrent and channelCurrent:GetType() == activeChannel then
		for i, tSegment in ipairs( tMessage.arMessageSegments ) do
			if bCurrDistributing and tSegment.uItem ~= nil then -- item link
			
				if bBeingDistributed then
					self:ShowItemTooltip(tSegment.uItem)
					self:PopulateGearBtn(tSegment.uItem)
					bBeingDistributed = false
				else
					self:ListItem(tSegment, tMessage.strSender)
				end	
				
			elseif tSegment.strText == "== Distributing " then -- starting distribution
			
				self.btnDistribution:SetText("Stop distribution (Started by: " .. tMessage.strSender ..")")
				self.wndStatusBar:SetText("Current Distribution By: " .. tMessage.strSender)
				self.btnDistribution:SetCheck(true)
				bCurrDistributing = true	
				bBeingDistributed = true
				self.wndItemList:DestroyChildren()
				
			elseif tSegment.strText == "== Distribution ended" then -- ending distribution
			
				self.wndLeftSide:DestroyChildren()

				self.btnDistribution:SetText("Start New Distribution")
				self.wndStatusBar:SetText("No Distribution Active")
				self.btnDistribution:SetCheck(false)
				currItem = ""
				self:PopulateGearBtn()
				bCurrDistributing = false

			end
		end
	end
end


function RollingDiceLootCouncil:GetItemData(item)
	--local item = Item.GetDataFromId(id)
	if item then
		local tItemInfo = item:GetDetailedInfo().tPrimary
		
		tItemInfo.item = item
		tItemInfo.eSlot = item:GetSlot()
		tItemInfo.tStats = {}

                -- Determine item slot, even on tokens:
                local isToken, tokenSlot
                _, _, isToken, tokenSlot = string.find(item:GetItemTypeName(), "^(Token) %- .+ %- (%a+)$")
                if isToken and tItemQualities[item:GetItemQuality()].label == "Legendary" then
                    if      tokenSlot == "Chest"    then tItemInfo.eSlot = 0
                    elseif  tokenSlot == "Legs"     then tItemInfo.eSlot = 1
                    elseif  tokenSlot == "Head"     then tItemInfo.eSlot = 2
                    elseif  tokenSlot == "Shoulder" then tItemInfo.eSlot = 3
                    elseif  tokenSlot == "Feet"     then tItemInfo.eSlot = 4
                    elseif  tokenSlot == "Hands"    then tItemInfo.eSlot = 5
                    else
                    end
                end
		
		for i=1,#(tItemInfo.arInnateProperties or {}) do
			local stat = tItemInfo.arInnateProperties[i]
			tItemInfo.tStats[stat.eProperty] = stat.nValue
		end
		
		for i=1,#(tItemInfo.arBudgetBasedProperties or {}) do
			local stat = tItemInfo.arBudgetBasedProperties[i]
			tItemInfo.tStats[stat.eProperty] = stat.nValue
		end
		
		return tItemInfo 
	end
end

function RollingDiceLootCouncil.StatsString(item)
	local tStrStats = {}
	
	for stat,value in pairs(item.tStats) do
		table.insert(tStrStats, string.format("%.0f", value)..(tStats[stat] and tStats[stat].short or "?"))
	end
	
 	return table.concat(tStrStats," | ")
end

