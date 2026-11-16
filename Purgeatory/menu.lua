local P = Purgeatory
local NAME = P.NAME

local BG, BG_MID = {0.028, 0.048, 0.095}, {0.038, 0.075, 0.148}
local BORDER, BORDER_HI = {0.22, 0.52, 0.92}, {0.32, 0.72, 1.00}
local TEXT, TEXT_HI, TEXT_DIM = {0.55, 0.80, 1.00}, {0.82, 0.94, 1.00}, {0.30, 0.50, 0.75}
local TT_BG = "Interface\\Tooltips\\UI-Tooltip-Background"
local TT_BD = "Interface\\Tooltips\\UI-Tooltip-Border"
local BACKDROP = { bgFile = TT_BG, edgeFile = TT_BD, tile = true, tileSize = 16, edgeSize = 12,
	insets = { left = 3, right = 3, top = 3, bottom = 3 } }

local menu, moving, syncing
local widgets = {}

local function Label(parent, text, size, color)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	fs:SetFont((GameFontNormal:GetFont()), size or 11)
	fs:SetTextColor(color[1], color[2], color[3])
	fs:SetText(text)
	return fs
end

local function Button(parent, text, w)
	local b = CreateFrame("Button", nil, parent)
	b:SetWidth(w)
	b:SetHeight(20)
	b:SetBackdrop(BACKDROP)
	b:SetBackdropColor(BG_MID[1], BG_MID[2], BG_MID[3], 0.95)
	b:SetBackdropBorderColor(BORDER[1], BORDER[2], BORDER[3], 0.8)
	b.text = Label(b, text, 11, TEXT)
	b.text:SetPoint("CENTER")
	b:SetScript("OnEnter", function(self)
		self:SetBackdropBorderColor(BORDER_HI[1], BORDER_HI[2], BORDER_HI[3], 1)
		self.text:SetTextColor(TEXT_HI[1], TEXT_HI[2], TEXT_HI[3])
	end)
	b:SetScript("OnLeave", function(self)
		self:SetBackdropBorderColor(BORDER[1], BORDER[2], BORDER[3], 0.8)
		self.text:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
	end)
	return b
end

local function Check(parent, text, y, get, set)
	local cb = CreateFrame("CheckButton", nil, parent)
	cb:SetWidth(14)
	cb:SetHeight(14)
	cb:SetPoint("TOPLEFT", 16, y)
	cb:SetBackdrop(BACKDROP)
	cb:SetBackdropColor(BG[1], BG[2], BG[3], 1)
	cb:SetBackdropBorderColor(BORDER[1], BORDER[2], BORDER[3], 0.8)
	cb:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
	local fs = Label(cb, text, 11, TEXT)
	fs:SetPoint("LEFT", cb, "RIGHT", 6, 0)
	cb:SetHitRectInsets(0, -150, 0, 0)
	cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
	cb.refresh = function() cb:SetChecked(get()) end
	widgets[#widgets + 1] = cb
	return cb
end

local function Slider(parent, text, y, fmt, getRange, step, get, set)
	local s = CreateFrame("Slider", nil, parent)
	s:SetOrientation("HORIZONTAL")
	s:SetWidth(208)
	s:SetHeight(10)
	s:SetPoint("TOPLEFT", 16, y)
	s:SetBackdrop(BACKDROP)
	s:SetBackdropColor(BG[1], BG[2], BG[3], 1)
	s:SetBackdropBorderColor(BORDER[1], BORDER[2], BORDER[3], 0.6)
	s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
	s:GetThumbTexture():SetVertexColor(BORDER_HI[1], BORDER_HI[2], BORDER_HI[3])
	s:SetValueStep(step)
	s:EnableMouseWheel(true)
	local name = Label(s, text, 11, TEXT)
	name:SetPoint("BOTTOMLEFT", s, "TOPLEFT", 0, 3)
	local val = Label(s, "", 11, TEXT_HI)
	val:SetPoint("BOTTOMRIGHT", s, "TOPRIGHT", 0, 3)
	s:SetScript("OnValueChanged", function(self, v)
		v = math.floor(v / step + 0.5) * step
		val:SetText(string.format(fmt, v))
		if( not syncing ) then set(v) end
	end)
	s:SetScript("OnMouseWheel", function(self, d)
		self:SetValue(self:GetValue() + d * step)
	end)
	s.refresh = function()
		s:SetMinMaxValues(getRange())
		local v = get()
		s:SetValue(v)

		val:SetText(string.format(fmt, v))
	end
	widgets[#widgets + 1] = s
	return s
end

local function Refresh()
	syncing = true
	for i = 1, #widgets do widgets[i].refresh() end
	syncing = false
end

local function SetMoving(on)
	moving = on
	local f = P:GetAlertFrame()
	if( not f.dragLabel ) then
		f.dragLabel = Label(f, NAME .. " alerts - drag to move", 14, TEXT_HI)
		f.dragLabel:SetPoint("CENTER")
		f:RegisterForDrag("LeftButton")
		f:SetScript("OnDragStart", f.StartMoving)
		f:SetScript("OnDragStop", function(self)
			self:StopMovingOrSizing()

			local s = self:GetScale()
			local cx, cy = self:GetCenter()
			local ux, uy = UIParent:GetCenter()
			local prof = P.db.profile
			prof.frameX = math.floor(cx * s - ux + 0.5)
			prof.frameY = math.floor(cy * s - uy + 0.5)
			P:ApplyFramePosition()
			if( menu and menu:IsShown() ) then Refresh() end
		end)
	end
	f:EnableMouse(on)
	if( on ) then
		f:SetBackdrop(BACKDROP)
		f:SetBackdropColor(BG[1], BG[2], BG[3], 0.8)
		f:SetBackdropBorderColor(BORDER_HI[1], BORDER_HI[2], BORDER_HI[3], 1)
		f.dragLabel:Show()
	else
		f:SetBackdrop(nil)
		f.dragLabel:Hide()
	end
	if( menu ) then menu.move.text:SetText(on and "Lock" or "Move") end
end

function P:TestAlert()
	local prof = self.db.profile
	self:SendMessage(prof.dispelSuccessMsg, 118, (GetSpellInfo(118)), "Dispel Magic", "Target", "rwframe", prof.dispelColor)
end

local function HalfW() local w = math.floor(UIParent:GetWidth() / 2) return -w, w end
local function HalfH() local h = math.floor(UIParent:GetHeight() / 2) return -h, h end

local function CreateMenu()
	menu = CreateFrame("Frame", nil, UIParent)
	menu:SetWidth(240)
	menu:SetHeight(296)
	menu:SetPoint("CENTER")
	menu:SetFrameStrata("DIALOG")
	menu:SetClampedToScreen(true)
	menu:SetMovable(true)
	menu:EnableMouse(true)
	menu:RegisterForDrag("LeftButton")
	menu:SetScript("OnDragStart", menu.StartMoving)
	menu:SetScript("OnDragStop", menu.StopMovingOrSizing)
	menu:SetBackdrop(BACKDROP)
	menu:SetBackdropColor(BG[1], BG[2], BG[3], 0.97)
	menu:SetBackdropBorderColor(BORDER[1], BORDER[2], BORDER[3], 0.95)

	local title = Label(menu, NAME, 13, TEXT_HI)
	title:SetPoint("TOP", 0, -10)
	local line = menu:CreateTexture(nil, "ARTWORK")
	line:SetTexture(BORDER[1], BORDER[2], BORDER[3], 0.5)
	line:SetHeight(1)
	line:SetPoint("TOPLEFT", 10, -28)
	line:SetPoint("TOPRIGHT", -10, -28)

	local close = Button(menu, "x", 18)
	close:SetHeight(18)
	close:SetPoint("TOPRIGHT", -6, -6)
	close:SetScript("OnClick", function() menu:Hide() end)

	local prof = function() return P.db.profile end

	Check(menu, "Show spell icons", -38,
		function() return prof().showIcon end,
		function(v) prof().showIcon = v end)

	local zoneTypes = { "none", "party", "raid", "arena", "pvp" }
	Check(menu, "Enabled (all zones)", -58,
		function()
			local z = prof().zones
			for i = 1, #zoneTypes do if z[zoneTypes[i]].enabled then return true end end
			return false
		end,
		function(v)
			local z = prof().zones
			for i = 1, #zoneTypes do z[zoneTypes[i]].enabled = v end
			P:Reload()
		end)

	Slider(menu, "Scale", -100, "%.2f", function() return 0.7, 2 end, 0.05,
		function() return prof().frameScale end,
		function(v) prof().frameScale = v; P:GetAlertFrame(); P:ApplyFramePosition() end)

	Slider(menu, "Position X", -140, "%d", HalfW, 1,
		function() return prof().frameX end,
		function(v) prof().frameX = v; P:GetAlertFrame(); P:ApplyFramePosition() end)

	Slider(menu, "Position Y", -180, "%d", HalfH, 1,
		function() return prof().frameY end,
		function(v) prof().frameY = v; P:GetAlertFrame(); P:ApplyFramePosition() end)

	local move = Button(menu, "Move", 66)
	move:SetPoint("TOPLEFT", 16, -206)
	move:SetScript("OnClick", function() SetMoving(not moving) end)
	menu.move = move

	local test = Button(menu, "Test", 66)
	test:SetPoint("TOP", 0, -206)
	test:SetScript("OnClick", function() P:TestAlert() end)

	local reset = Button(menu, "Reset", 66)
	reset:SetPoint("TOPRIGHT", -16, -206)
	reset:SetScript("OnClick", function()
		local p, d = prof(), P.FRAME_DEFAULTS
		p.frameScale, p.frameX, p.frameY = d.frameScale, d.frameX, d.frameY
		P:GetAlertFrame()
		P:ApplyFramePosition()
		Refresh()
	end)

	local full = Button(menu, "All options...", 208)
	full:SetPoint("TOPLEFT", 16, -234)
	full:SetScript("OnClick", function()
		menu:Hide()
		P:OpenConfig()
	end)

	local hint = Label(menu, "/purg test  -  /purg config", 10, TEXT_DIM)
	hint:SetPoint("BOTTOM", 0, 12)

	menu:SetScript("OnShow", Refresh)

	menu:SetScript("OnHide", function() if( moving ) then SetMoving(false) end end)
	menu:Hide()
end

SLASH_PURGEATORY1 = "/purgeatory"
SLASH_PURGEATORY2 = "/purg"
SlashCmdList["PURGEATORY"] = function(msg)
	if( not P.db ) then return end
	msg = string.lower(string.trim(msg or ""))
	if( msg == "config" or msg == "options" ) then
		P:OpenConfig()
	elseif( msg == "test" ) then
		P:TestAlert()
	else
		if( not menu ) then CreateMenu() end
		if( menu:IsShown() ) then menu:Hide() else menu:Show() end
	end
end
