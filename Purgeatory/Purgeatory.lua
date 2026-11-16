local ADDON = ...

local NAME = "Purgeatory"

Purgeatory = {}
local P = Purgeatory
P.NAME = NAME
P.ADDON = ADDON

P.FRAME_DEFAULTS = { frameScale = 1, frameX = 0, frameY = 130 }

local band = bit.band
local gsub, format, trim = string.gsub, string.format, string.trim
local GetSpellInfo = GetSpellInfo
local MINE = COMBATLOG_OBJECT_AFFILIATION_MINE
local HOSTILE = COMBATLOG_OBJECT_REACTION_HOSTILE

local GROUNDING = { ["Grounding Totem"] = true, ["Totem de glèbe"] = true }
do
	local n = GetSpellInfo(8177)
	if n then GROUNDING[n] = true end
end

local GROUND_EVENTS = { SPELL_CAST_SUCCESS = true, SPELL_DAMAGE = true, SPELL_MISSED = true, SPELL_AURA_APPLIED = true }

local instanceType
local prof
local zone
local lastGroundGUID

function P:OnInitialize()
	local d = P.FRAME_DEFAULTS
	self.defaults = {
		profile = {
			showIcon = true,
			dispelSuccessMsg = "*spell",
			dispelFailMsg = "FAILED *spell",
			dispelColor = {r = 1, g = 1, b = 1},
			dispelLocation = "rwframe",
			interruptMsg = "*spell",
			interruptColor = {r = 1, g = 1, b = 1},
			interruptLocation = "rwframe",
			reflectMsg = "Reflected *spell",
			reflectColor = {r = 1, g = 1, b = 1},
			reflectLocation = "rwframe",
			groundingMsg = "Grounded *spell",
			groundingColor = {r = 1, g = 1, b = 1},
			groundingLocation = "rwframe",
			frameScale = d.frameScale,
			frameX = d.frameX,
			frameY = d.frameY,

			zones = {
				["*"] = {
					enabled = true,
					dispelOffensive = true,
					dispelDefensive = true,
					dispelFail = true,
					interrupt = true,
					reflect = true,
					grounding = true,
				},
			},
		},
	}

	self.db = LibStub:GetLibrary("AceDB-3.0"):New("PurgeatoryDB", self.defaults, true)
	self.db.RegisterCallback(self, "OnProfileChanged", "Reload")
	self.db.RegisterCallback(self, "OnProfileCopied", "Reload")
	self.db.RegisterCallback(self, "OnProfileReset", "Reload")
	prof = self.db.profile
end

function P:COMBAT_LOG_EVENT_UNFILTERED(event, timestamp, eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, ...)
	if( not zone ) then return end

	if( eventType == "SPELL_INTERRUPT" ) then
		if( zone.interrupt and band(sourceFlags, MINE) > 0 ) then
			local _, spellName, _, extraSpellID, extraSpellName = ...
			self:SendMessage(prof.interruptMsg, extraSpellID, extraSpellName, spellName, destName, prof.interruptLocation, prof.interruptColor)
		end

	elseif( eventType == "SPELL_DISPEL" or eventType == "SPELL_STOLEN" or eventType == "SPELL_DISPEL_FAILED" ) then
		if( band(sourceFlags, MINE) == 0 ) then return end
		local hostile = band(destFlags, HOSTILE) > 0
		if( hostile and not zone.dispelOffensive ) or ( not hostile and not zone.dispelDefensive ) then return end
		local _, spellName, _, extraSpellID, extraSpellName = ...
		if( eventType == "SPELL_DISPEL_FAILED" ) then
			if( zone.dispelFail ) then
				self:SendMessage(prof.dispelFailMsg, extraSpellID, extraSpellName, spellName, destName, prof.dispelLocation, prof.dispelColor)
			end
		else
			self:SendMessage(prof.dispelSuccessMsg, extraSpellID, extraSpellName, spellName, destName, prof.dispelLocation, prof.dispelColor)
		end

	elseif( eventType == "SPELL_MISSED" and band(destFlags, MINE) > 0 and select(4, ...) == "REFLECT" ) then
		if( zone.reflect ) then
			local spellID, spellName = ...
			self:SendMessage(prof.reflectMsg, spellID, spellName, spellName, destName, prof.reflectLocation, prof.reflectColor)
		end

	elseif( GROUND_EVENTS[eventType] and destName and GROUNDING[destName] ) then
		if( zone.grounding and band(destFlags, MINE) > 0 and band(sourceFlags, MINE) == 0 and destGUID ~= lastGroundGUID ) then
			lastGroundGUID = destGUID
			local spellID, spellName = ...
			self:SendMessage(prof.groundingMsg, spellID, spellName, spellName, destName, prof.groundingLocation, prof.groundingColor)
		end
	end
end

function P:PLAYER_ENTERING_WORLD()
	self:ZONE_CHANGED_NEW_AREA()
end

function P:ZONE_CHANGED_NEW_AREA()
	local t = select(2, IsInInstance()) or "none"
	if( t ~= instanceType ) then
		instanceType = t
		local z = prof.zones[t]
		if( z.enabled ) then
			zone = z
			self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		else
			zone = nil
			self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		end
	end
end

function P:Reload()
	prof = self.db.profile
	instanceType = nil
	self:ZONE_CHANGED_NEW_AREA()
	self:ApplyFramePosition()
end

function P:StripServer(text)
	return string.match(text, "^(.-)%-") or text
end

function P:WrapIcon(msg, spellID)
	if( not prof.showIcon or not spellID ) then
		return msg
	end

	local icon = select(3, GetSpellInfo(spellID))
	return icon and format("|T%s:0:0|t %s", icon, msg) or msg
end

local function safe(s)
	return (gsub(s, "%%", "%%%%"))
end

function P:GetAlertFrame()
	local f = self.alertFrame
	if( not f ) then
		f = CreateFrame("MessageFrame", nil, UIParent)
		f:SetInsertMode("TOP")
		f:SetFrameStrata("HIGH")
		f:SetWidth(400)
		f:SetHeight(80)
		f:SetFadeDuration(0.5)
		f:SetTimeVisible(2)
		f:SetFont((GameFontNormal:GetFont()), 20, "OUTLINE")
		f:SetMovable(true)
		f:SetClampedToScreen(true)
		self.alertFrame = f
		self:ApplyFramePosition()
	end
	return f
end

function P:ApplyFramePosition()
	local f = self.alertFrame
	if( not f or not prof ) then return end

	local s = prof.frameScale or 1
	if( s < 0.7 ) then s = 0.7; prof.frameScale = s end
	f:SetScale(s)
	f:ClearAllPoints()
	f:SetPoint("CENTER", UIParent, "CENTER", (prof.frameX or 0) / s, (prof.frameY or 0) / s)
end

local CHANNEL = { say = "SAY", party = "PARTY", raid = "RAID", rw = "RAID_WARNING", bg = "BATTLEGROUND" }

function P:SendMessage(msg, spellID, spellName, usedSpellName, destName, dest, color)
	local inRaid = GetNumRaidMembers() > 0
	local grouped = inRaid or GetNumPartyMembers() > 0

	if( ( dest == "rw" or dest == "party" or dest == "raid" ) and not grouped ) then
		dest = "rwframe"

	elseif( dest == "rw" and inRaid and not IsRaidLeader() and not IsRaidOfficer() ) then
		dest = "raid"
	end

	if( dest == "raid" ) then
		if( instanceType == "pvp" ) then
			dest = "bg"
		elseif( not inRaid ) then
			dest = "party"
		end
	end

	msg = gsub(msg, "*target", safe(self:StripServer(destName or "")))
	msg = gsub(msg, "*spell", safe(spellName or ""))
	msg = gsub(msg, "*used", safe(usedSpellName or ""))
	msg = trim((gsub(msg, "%(%)", "")))
	if( msg == "" ) then return end

	if( tonumber(dest) ) then
		local cf = _G["ChatFrame" .. dest] or DEFAULT_CHAT_FRAME
		cf:AddMessage(format("|cff33ff99%s|r|cffffffff:|r %s", NAME, self:WrapIcon(msg, spellID)), color.r, color.g, color.b)
	elseif( CHANNEL[dest] ) then
		SendChatMessage(msg, CHANNEL[dest])
	elseif( dest == "rwframe" ) then
		self:GetAlertFrame():AddMessage(self:WrapIcon(msg, spellID), color.r, color.g, color.b)
	elseif( dest == "ct" ) then
		msg = self:WrapIcon(msg, spellID)
		if( SCT and IsAddOnLoaded("sct") ) then
			SCT:DisplayText(msg, color, nil, "event", 1)
		elseif( MikSBT and IsAddOnLoaded("MikScrollingBattleText") ) then
			MikSBT.DisplayMessage(msg, MikSBT.DISPLAYTYPE_NOTIFICATION, false, color.r * 255, color.g * 255, color.b * 255)
		elseif( IsAddOnLoaded("Blizzard_CombatText") ) then
			if( not COMBAT_TEXT_SCROLL_FUNCTION ) then
				CombatText_UpdateDisplayedMessages()
			end
			CombatText_AddMessage(msg, COMBAT_TEXT_SCROLL_FUNCTION, color.r, color.g, color.b)
		else

			self:GetAlertFrame():AddMessage(msg, color.r, color.g, color.b)
		end
	end
end

function P:Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99" .. NAME .. "|r: " .. msg)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:SetScript("OnEvent", function(self, event, ...)
	if( event == "COMBAT_LOG_EVENT_UNFILTERED" ) then
		P:COMBAT_LOG_EVENT_UNFILTERED(event, ...)
	elseif( event == "ADDON_LOADED" ) then
		if( ... == ADDON ) then
			P:OnInitialize()
			P:ZONE_CHANGED_NEW_AREA()
			self:UnregisterEvent("ADDON_LOADED")
		end
	elseif( prof ) then
		P[event](P, event, ...)
	end
end)

function P:RegisterEvent(event)
	frame:RegisterEvent(event)
end

function P:UnregisterEvent(event)
	frame:UnregisterEvent(event)
end
