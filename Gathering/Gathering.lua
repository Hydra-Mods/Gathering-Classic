local format = format
local date = date
local pairs = pairs
local select = select
local tonumber = tonumber
local match = string.match
local strsplit = strsplit
local GetItemInfo = GetItemInfo
local RarityColor = ITEM_QUALITY_COLORS
local LootMessage = (LOOT_ITEM_SELF:gsub("%%.*", ""))
local LootMatch = "([^|]+)|cff(%x+)|H([^|]+)|h%[([^%]]+)%]|h|r[^%d]*(%d*)"
local Font = "Interface\\Addons\\Gathering\\PTSans.ttf"

-- Header
local Gathering = CreateFrame("Frame", "Gathering Header", UIParent)
Gathering:SetSize(140, 28)
Gathering:SetPoint("TOP", UIParent, 0, -100)
Gathering:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = {left = 4, right = 4, top = 4, bottom = 4}})
Gathering:SetBackdropColor(0, 0, 0, 1)
Gathering:EnableMouse(true)
Gathering:SetMovable(true)
Gathering:SetUserPlaced(true)
Gathering:SetClampedToScreen(true)
Gathering:RegisterForDrag("LeftButton")
Gathering:SetScript("OnDragStart", Gathering.StartMoving)
Gathering:SetScript("OnDragStop", Gathering.StopMovingOrSizing)

-- Tett
Gathering.Text = Gathering:CreateFontString(nil, "OVERLAY")
Gathering.Text:SetPoint("CENTER", Gathering, 0, 0)
Gathering.Text:SetJustifyH("CENTER")
Gathering.Text:SetFont(Font, 14)
Gathering.Text:SetText("Gathering")

-- Tooltip
Gathering.Tooltip = CreateFrame("GameTooltip", "GatheringTooltip", UIParent, "GameTooltipTemplate")

-- Data
Gathering.Gathered = {}
Gathering.TotalGathered = 0
Gathering.NumTypes = 0
Gathering.Elapsed = 0
Gathering.Seconds = 0
Gathering.SecondsPerItem = {}

-- Tools
function Gathering:UpdateFont()
	for i = 1, self.Tooltip:GetNumRegions() do
		local Region = select(i, self.Tooltip:GetRegions())
		
		if (Region:GetObjectType() == "FontString" and not Region.Handled) then
			Region:SetFont(Font, 12)
			Region:SetShadowColor(0, 0, 0)
			Region:SetShadowOffset(1.25, -1.25)
			Region.Handled = true
		end
	end
end

function Gathering:OnUpdate(ela)
	self.Elapsed = self.Elapsed + ela
	
	if (self.Elapsed >= 1) then
		self.Seconds = self.Seconds + 1
		
		for key in pairs(self.SecondsPerItem) do
			self.SecondsPerItem[key] = self.SecondsPerItem[key] + 1
		end
		
		self.Text:SetText(date("!%X", self.Seconds))
		
		if self.MouseIsOver then
			self:OnLeave()
			self:OnEnter()
		end
		
		self.Elapsed = 0
	end
end

function Gathering:StartTimer()
	if (not strfind(self.Text:GetText(), "%d")) then
		self.Text:SetText("0:00:00")
	end
	
	self:SetScript("OnUpdate", self.OnUpdate)
	self.Text:SetTextColor(0.1, 0.9, 0.1)
end

function Gathering:PauseTimer()
	self:SetScript("OnUpdate", nil)
	self.Text:SetTextColor(0.9, 0.9, 0.1)
end

function Gathering:ToggleTimer()
	if (not self:GetScript("OnUpdate")) then
		self:StartTimer()
	else
		self:PauseTimer()
	end
end

function Gathering:Reset()
	self:SetScript("OnUpdate", nil)
	
	wipe(self.Gathered)
	
	self.NumTypes = 0
	self.TotalGathered = 0
	self.Seconds = 0
	self.Elapsed = 0
	
	for key in pairs(self.SecondsPerItem) do
		self.SecondsPerItem[key] = 0
	end
	
	self.Text:SetTextColor(1, 1, 1)
	self.Text:SetText(date("!%X", self.Seconds))
end

function Gathering:OnEvent(event, msg)
	if (not msg) then
		return
	end
	
	if (InboxFrame:IsVisible() or (GuildBankFrame and GuildBankFrame:IsVisible())) then -- Ignore useless info
		return
	end
	
	local PreMessage, _, ItemString, Name, Quantity = match(msg, LootMatch)
	local LinkType, ID = strsplit(":", ItemString)
	
	if (PreMessage ~= LootMessage) then
		return
	end
	
	ID = tonumber(ID)
	Quantity = tonumber(Quantity) or 1
	local Type, SubType, _, _, _, _, ClassID, SubClassID = select(6, GetItemInfo(ID))
	
	-- Check that we want to track the type of item
	--if (TrackedItemTypes[ClassID] and not TrackedItemTypes[ClassID][SubClassID]) then
	if (not self.Tracked[ID]) then
		return
	end
	
	if (not self.Gathered[SubType]) then
		self.Gathered[SubType] = {}
		self.NumTypes = self.NumTypes + 1
	end
	
	if (not self.Gathered[SubType][Name]) then
		self.Gathered[SubType][Name] = 0
	end
	
	if (not self.SecondsPerItem[Name]) then
		self.SecondsPerItem[Name] = 0
	end
	
	self.Gathered[SubType][Name] = self.Gathered[SubType][Name] + Quantity
	self.TotalGathered = self.TotalGathered + Quantity -- For gathered/hr stat
	
	if (not self:GetScript("OnUpdate")) then
		self:StartTimer()
	end
	
	if self.MouseIsOver then
		self:OnLeave()
		self:OnEnter()
	end
end

function Gathering:OnEnter()
	if (self.TotalGathered == 0) then
		return
	end
	
	self.MouseIsOver = true
	
	local Count = 0
	
	self.Tooltip:SetOwner(self, "ANCHOR_NONE")
	self.Tooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT")
	self.Tooltip:ClearLines()
	
	self.Tooltip:AddLine("Gathering")
	self.Tooltip:AddLine(" ")
	
	for SubType, Info in pairs(self.Gathered) do
		self.Tooltip:AddLine(SubType, 1, 1, 0)
		Count = Count + 1
		
		for Name, Value in pairs(Info) do
			local Rarity = select(3, GetItemInfo(Name))
			local Hex = "|cffFFFFFF"
			
			if Rarity then
				Hex = RarityColor[Rarity].hex
			end
			
			if self.SecondsPerItem[Name] then
				self.Tooltip:AddDoubleLine(format("%s%s|r:", Hex, Name), format("%s (%s/Hr)", Value, format("%.0f", (((Value / self.SecondsPerItem[Name]) * 60) * 60))), 1, 1, 1, 1, 1, 1)
			else
				self.Tooltip:AddDoubleLine(format("%s%s|r:", Hex, Name), Value, 1, 1, 1, 1, 1, 1)
			end
		end
		
		if (Count ~= self.NumTypes) then
			self.Tooltip:AddLine(" ")
		end
	end
	
	self.Tooltip:AddLine(" ")
	self.Tooltip:AddDoubleLine("Total Gathered:", format("%s", self.TotalGathered))
	self.Tooltip:AddDoubleLine("Total Average Per Hour:", format("%.0f", (((self.TotalGathered / self.Seconds) * 60) * 60)))
	self.Tooltip:AddLine(" ")
	self.Tooltip:AddLine("Left click: Toggle timer")
	self.Tooltip:AddLine("Right click: Reset data")
	
	self:UpdateFont()
	
	self.Tooltip:Show()
end

function Gathering:OnLeave()
	if self.Tooltip.Override then
		return
	end
	
	self.MouseIsOver = false
	
	self.Tooltip:Hide()
end

function Gathering:OnMouseUp(button)
	if (button == "LeftButton") then
		self:ToggleTimer()
	elseif (button == "RightButton") then
		self:Reset()
	elseif (button == "MiddleButton") then
		if (self.Tooltip.Override == true) then
			self.Tooltip.Override = false
		else
			self.Tooltip.Override = true
		end
	end
end

Gathering:RegisterEvent("CHAT_MSG_LOOT")
Gathering:SetScript("OnEvent", Gathering.OnEvent)
Gathering:SetScript("OnEnter", Gathering.OnEnter)
Gathering:SetScript("OnLeave", Gathering.OnLeave)
Gathering:SetScript("OnMouseUp", Gathering.OnMouseUp)

Gathering.Tracked = {
	-- Herbs
	[765] = true,     -- Silverleaf
	[785] = true,     -- Mageroyal
	[2044] = true,    -- Dragon's Teeth
	[2447] = true,    -- Peacebloom
	[2449] = true,    -- Earthroot
	[2450] = true,    -- Briarthorn
	[2452] = true,    -- Swiftthistle
	[2453] = true,    -- Bruiseweed
	[3355] = true,    -- Wild Steelbloom
	[3356] = true,    -- Kingsblood
	[3357] = true,    -- Liferoot
	[3358] = true,    -- Khadgar's Whisker
	[3369] = true,    -- Grave Moss
	[3818] = true,    -- Fadeleaf
	[3819] = true,    -- Wintersbite
	[3820] = true,    -- Stranglekelp
	[3821] = true,    -- Goldthorn
	[4625] = true,    -- Firebloom
	[8831] = true,    -- Purple Lotus
	[8836] = true,    -- Arthas' Tears
	[8838] = true,    -- Sungrass
	[8839] = true,    -- Blindweed
	[8845] = true,    -- Ghost Mushroom
	[8846] = true,    -- Gromsblood
	[13463] = true,   -- Dreamfoil
	[13466] = true,   -- Sorrowmoss
	[13464] = true,   -- Golden Sansam
	[13465] = true,   -- Mountain Silversage
	[13466] = true,   -- Plaguebloom
	[13467] = true,   -- Icecap
	[13468] = true,   -- Black Lotus
	[19726] = true,   -- Bloodvine
	
	-- Ore
	[2770] = true,    -- Copper Ore
	[2771] = true,    -- Tin Ore
	[2775] = true,    -- Silver Ore
	[2772] = true,    -- Iron Ore
	[2776] = true,    -- Gold Ore
	[3858] = true,    -- Mithril Ore
	[7911] = true,    -- Truesilver Ore
	[10620] = true,   -- Thorium Ore
	[12363] = true,   -- Arcane Crystal
	
	-- Skins
	[2934] = true,    -- Ruined Leather Scraps
	[2318] = true,    -- Light Leather
	[783] = true,     -- Light Hide
	[2319] = true,    -- Medium Leather
	[4232] = true,    -- Medium Hide
	[20649] = true,   -- Heavy Leather
	[4304] = true,    -- Thick Leather
	[8170] = true,    -- Rugged Leather
	[8171] = true,    -- Rugged Hide
	[15417] = true,   -- Devilsaur Leather
	
	-- Fish
	[6291] = true,    -- Raw Brilliant Smallfish
	[6299] = true,    -- Sickly Looking Fish
	[6303] = true,    -- Raw Slitherskin Mackerel
	[6289] = true,    -- Raw Longjaw Mud Snapper
	[6317] = true,    -- Raw Loch Frenzy
	[6358] = true,    -- Oily Blackmouth
	[6361] = true,    -- Raw Rainbow Fin Albacore
	[21071] = true,   -- Raw Sagefish
	[6308] = true,    -- Raw Bristle Whisker Catfish
	[6359] = true,    -- Firefin Snapper
	[6362] = true,    -- Raw Rockscale Cod
	[4603] = true,    -- Raw Spotted Yellowtail
	[12238] = true,   -- Darkshore Grouper
	[13422] = true,   -- Stonescale Eel
	[13754] = true,   -- Raw Glossy Mightfish
	[13755] = true,   -- Winter Squid
	[13756] = true,   -- Raw Summer Bass
	[13757] = true,   -- Lightning Eel
	[13758] = true,   -- Raw Redgill
	[13759] = true,   -- Raw Nightfin Snapper
	[13760] = true,   -- Raw Sunscale Salmon
	[13888] = true,   -- Darkclaw Lobster
	[13889] = true,   -- Raw Whitescale Salmon
	[13893] = true,   -- Large Raw Mightfish
	[6522] = true,    -- Deviate Fish
	[8365] = true,    -- Raw Mithril Head Trout
	
	-- Cooking
	[769] = true,      -- Chunk of Boar Meat
	[1015] = true,     -- Lean Wolf Flank
	[2674] = true,     -- Crawler Meat
	[2675] = true,     -- Crawler Claw
	[3173] = true,     -- Bear Meat
	[3685] = true,     -- Raptor Egg
	[3712] = true,     -- Turtle Meat
	[3731] = true,     -- Lion Meat
	[5503] = true,     -- Clam Meat
	[12037] = true,    -- Mystery Meat <3
	[12205] = true,    -- White Spider Meat
	[12207] = true,    -- Giant Egg
	[12184] = true,    -- Raptor Flesh
	[20424] = true,    -- Sandworm Meat
	
	-- Cloth
	[2589] = true,     -- Linen Cloth
	[2592] = true,     -- Wool Cloth
	[4306] = true,     -- Silk Cloth
	[4338] = true,     -- Mageweave Cloth
	[14047] = true,    -- Runecloth
	[14256] = true,    -- Felcloth
	
	-- Enchanting
	[10938] = true,    -- Lesser Magic Essence
	[10939] = true,    -- Greater Magic Essence
	[10940] = true,    -- Strange Dust
	[10998] = true,    -- Lesser Astral Essence
	[11082] = true,    -- Greater Astral Essence
	[11083] = true,    -- Soul Dust
	[11134] = true,    -- Lesser Mystic Essence
	[11135] = true,    -- Greater Mystic Essence
	[11137] = true,    -- Vision Dust
	[11174] = true,    -- Lesser Nether Essence
	[11175] = true,    -- Greater Nether Essence
	[11176] = true,    -- Dream Dust
	[11177] = true,    -- Small Radiant Shard
	[11178] = true,    -- Large Radiant Shard
	[14343] = true,    -- Small Brilliant Shard
	[14344] = true,    -- Large Brilliant Shard
	[16202] = true,    -- Lesser Eternal Essence
	[16203] = true,    -- Greater Eternal Essence
	[16204] = true,    -- Illusion Dust
	
	-- Noblegarden
	[45072] = true, -- Brightly Colored Egg
	
	-- Other
	[12811] = true, -- Righteous Orb
	[12803] = true, -- Living Essence
	[7076] = true,  -- Essence of Earth
	[7078] = true,  -- Essence of Fire
	[7080] = true,  -- Essence of Water
	[7082] = true,  -- Essence of Air
	[12938] = true, -- Blood of Heroes
	[12820] = true, -- Winterfall Firewater
	[21377] = true, -- Deadwood Headdress Feather
	[21383] = true, -- Winterfall Spirit Beads
}

--[[local TrackedItemTypes = {
	[7] = { -- LE_ITEM_CLASS_TRADEGOODS
		[5] = true, -- Cloth
		[6] = true, -- Leather
		[7] = true, -- Metal & Stone
		[8] = true, -- Cooking
		[9] = true, -- Herb
		[12] = true, -- Enchanting
	},
	
	[15] = { -- LE_ITEM_CLASS_MISCELLANEOUS
		[2] = true, -- Companion Pets
		[3] = true, -- Holiday
		[5] = true, -- Mount
	},
}]]