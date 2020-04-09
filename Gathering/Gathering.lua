local format = format
local date = date
local pairs = pairs
local select = select
local tonumber = tonumber
local match = string.match
local strsplit = strsplit
local GetItemInfo = GetItemInfo
local RarityColor = ITEM_QUALITY_COLORS
local TotalGathered = 0
local LootMessage = (LOOT_ITEM_SELF:gsub("%%.*", ""))
local LootMatch = "([^|]+)|cff(%x+)|H([^|]+)|h%[([^%]]+)%]|h|r[^%d]*(%d*)"
local MouseIsOver = false

-- DB of items to track
local Tracked = {
	--[[ HERBS ]]--
	[765] = true,     -- Silverleaf
	[785] = true,     -- Mageroyal
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
	[13464] = true,   -- Golden Sansam
	[13465] = true,   -- Mountain Silversage
	[13466] = true,   -- Plaguebloom
	[13467] = true,   -- Icecap
	[13468] = true,   -- Black Lotus
	
	--[[ ORE ]]--
	[2770] = true,    -- Copper Ore
	[2771] = true,    -- Tin Ore
	[2775] = true,    -- Silver Ore
	[2772] = true,    -- Iron Ore
	[2776] = true,    -- Gold Ore
	[3858] = true,    -- Mithril Ore
	[7911] = true,    -- Truesilver Ore
	[10620] = true,   -- Thorium Ore
	
	--[[ SKINS ]]--
	[2934] = true,    -- Ruined Leather Scraps
	[2318] = true,    -- Light Leather
	[783] = true,     -- Light Hide
	[2319] = true,    -- Medium Leather
	[4232] = true,    -- Medium Hide
	[20649] = true,   -- Heavy Leather
	[4304] = true,    -- Thick Leather
	[8170] = true,    -- Rugged Leather
	[8171] = true,    -- Rugged Hide
	
	--[[ FISH ]]--
	[6291] = true,    -- Raw Brilliant Smallfish
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
	[13422] = true,   -- Stonescale Eel
	[13754] = true,   -- Raw Glossy Mightfish
	[13756] = true,   -- Raw Summer Bass
	[13757] = true,   -- Lightning Eel
	[13758] = true,   -- Raw Redgill
	[13759] = true,   -- Raw Nightfin Snapper
	[13760] = true,   -- Raw Sunscale Salmon
	[13889] = true,   -- Raw Whitescale Salmon
	[6522] = true,    -- Deviate Fish
	[20916] = true,   -- Mithril Headed Trout
	
	--[[ CLOTH ]]--
	[2589] = true,     -- Linen Cloth
	[2592] = true,     -- Wool Cloth
	[4306] = true,     -- Silk Cloth
	[4338] = true,     -- Mageweave Cloth
	[14047] = true,    -- Runecloth
	[14256] = true,    -- Felcloth
}

-- Keep track of what we've gathered, how many nodes, and what quantity.
local Gathered = {}
local NumTypes = 0

-- Tooltip
local Tooltip = CreateFrame("GameTooltip", "GatheringTooltip", UIParent, "GameTooltipTemplate")
local TooltipFont = "Interface\\Addons\\Gathering\\PTSans.ttf"

local SetFont = function(self)
	for i = 1, self:GetNumRegions() do
		local Region = select(i, self:GetRegions())
		
		if (Region:GetObjectType() == "FontString" and not Region.Handled) then
			Region:SetFont(TooltipFont, 12)
			Region:SetShadowColor(0, 0, 0)
			Region:SetShadowOffset(1.25, -1.25)
			Region.Handled = true
		end
	end
end

-- Main frame
local Frame = CreateFrame("Frame", nil, UIParent)
Frame:SetSize(140, 28)
Frame:SetPoint("TOP", UIParent, "TOP", 0, -100)
Frame:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = {left = 4, right = 4, top = 4, bottom = 4}})
Frame:SetBackdropColor(0, 0, 0, 1)
Frame:EnableMouse(true)
Frame:SetMovable(true)
Frame:RegisterForDrag("LeftButton")
Frame:SetScript("OnDragStart", Frame.StartMoving)
Frame:SetScript("OnDragStop", Frame.StopMovingOrSizing)

Frame.Text = Frame:CreateFontString(nil, "OVERLAY")
Frame.Text:SetPoint("CENTER", Frame, "CENTER", 0, 0)
Frame.Text:SetJustifyH("CENTER")
Frame.Text:SetFont(TooltipFont, 14)
Frame.Text:SetText("Gathering")

local Timer = CreateFrame("Frame", "GatheringTimer")

local SecondsPerItem = {}
local Seconds = 0
local Elapsed = 0

local ClearStats = function()
	wipe(Gathered)
	NumTypes = 0
	TotalGathered = 0
	
	for key in pairs(SecondsPerItem) do
		SecondsPerItem[key] = 0
	end
end

local OnEnter = function(self)
	if (TotalGathered == 0) then
		return
	end
	
	MouseIsOver = true
	
	local Count = 0
	
	Tooltip:SetOwner(self, "ANCHOR_NONE")
	Tooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT")
	Tooltip:ClearLines()
	
	Tooltip:AddLine("Gathering")
	Tooltip:AddLine(" ")
	
	for SubType, Info in pairs(Gathered) do
		Tooltip:AddLine(SubType, 1, 1, 0)
		Count = Count + 1
		
		for Name, Value in pairs(Info) do
			local Rarity = select(3, GetItemInfo(Name))
			local Hex = "|cffFFFFFF"
			
			if Rarity then
				Hex = RarityColor[Rarity].hex
			end
			
			if SecondsPerItem[Name] then
				local PerHour = (((Value / SecondsPerItem[Name]) * 60) * 60)
				
				Tooltip:AddDoubleLine(format("%s%s|r:", Hex, Name), format("%s (%s/Hr)", Value, format("%.0f", PerHour)), 1, 1, 1, 1, 1, 1)
			else
				Tooltip:AddDoubleLine(format("%s%s|r:", Hex, Name), Value, 1, 1, 1, 1, 1, 1)
			end
		end
		
		if (Count ~= NumTypes) then
			Tooltip:AddLine(" ")
		end
	end
	
	local PerHour = (((TotalGathered / Seconds) * 60) * 60)
	
	Tooltip:AddLine(" ")
	Tooltip:AddDoubleLine("Total Gathered:", format("%s", TotalGathered))
	Tooltip:AddDoubleLine("Total Average Per Hour:", format("%.0f", PerHour))
	Tooltip:AddLine(" ")
	Tooltip:AddLine("Left click: Toggle timer")
	Tooltip:AddLine("Right click: Reset data")
	
	SetFont(Tooltip)
	
	Tooltip:Show()
end

local OnLeave = function()
	if Tooltip.Forced then
		return
	end
	
	MouseIsOver = false
	
	Tooltip:Hide()
end

local TimerUpdate = function(self, ela)
	Elapsed = Elapsed + ela
	
	if (Elapsed >= 1) then
		Seconds = Seconds + 1
		
		for key in pairs(SecondsPerItem) do
			SecondsPerItem[key] = SecondsPerItem[key] + 1
		end
		
		Frame.Text:SetText(date("!%X", Seconds))
		
		-- TT update
		if MouseIsOver then
			OnLeave()
			OnEnter(Frame)
		end
		
		Elapsed = 0
	end
end

local Start = function()
	if (not strfind(Frame.Text:GetText(), "%d:%d%d:%d%d")) then
		Frame.Text:SetText("0:00:00")
	end
	
	Timer:SetScript("OnUpdate", TimerUpdate)
	Frame.Text:SetTextColor(0, 1, 0)
end

local Stop = function()
	Timer:SetScript("OnUpdate", nil)
	Frame.Text:SetTextColor(1, 0, 0)
end

local Toggle = function()
	if (not Timer:GetScript("OnUpdate")) then
		Start()
	else
		Stop()
	end
end

local Reset = function()
	Timer:SetScript("OnUpdate", nil)

	ClearStats()
	
	Seconds = 0
	Elapsed = 0
	
	Frame.Text:SetTextColor(1, 1, 1)
	Frame.Text:SetText(date("!%X", Seconds))
end

local Update = function(self, event, msg)
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
	local SubType = select(7, GetItemInfo(ID))
	
	-- Check that we want to track the type of item
	if (not Tracked[ID]) then
		return
	end
	
	if (not Gathered[SubType]) then
		Gathered[SubType] = {}
		NumTypes = NumTypes + 1
	end
	
	if (not Gathered[SubType][Name]) then
		Gathered[SubType][Name] = 0
	end
	
	if (not SecondsPerItem[Name]) then
		SecondsPerItem[Name] = 0
	end
	
	Gathered[SubType][Name] = Gathered[SubType][Name] + Quantity
	TotalGathered = TotalGathered + Quantity -- For Gathered/Hour stat
	
	if (not Timer:GetScript("OnUpdate")) then
		Start()
	end
	
	-- TT update
	if MouseIsOver then
		OnLeave()
		OnEnter(self)
	end
end

local OnMouseUp = function(self, button)
	if (button == "LeftButton") then
		Toggle()
	elseif (button == "RightButton") then
		Reset()
	elseif (button == "MiddleButton") then
		if (Tooltip.Forced == true) then
			Tooltip.Forced = false
		else
			Tooltip.Forced = true
		end
	end
end

local Enable = function(self)
	self:RegisterEvent("CHAT_MSG_LOOT")
	self:SetScript("OnEvent", Update)
	self:SetScript("OnEnter", OnEnter)
	self:SetScript("OnLeave", OnLeave)
	self:SetScript("OnMouseUp", OnMouseUp)
	self:Update()
end

local Disable = function(self)
	self.Text:SetText("")
	self:SetScript("OnEvent", nil)
	self:SetScript("OnEnter", nil)
	self:SetScript("OnLeave", nil)
	self:SetScript("OnMouseUp", nil)
	self:UnregisterAllEvents()
end

Frame.Update = Update
Frame.Enable = Enable
Frame.Disable = Disable

Frame:RegisterEvent("PLAYER_ENTERING_WORLD")
Frame:SetScript("OnEvent", function(self, event)
	self:Enable()
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
end)