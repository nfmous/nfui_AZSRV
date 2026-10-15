-- nfUI: unit frames and an action bar for Azeroth Survivors, in the
-- compact, flat styling. The default layout uses a centered row at the
-- bottom of the screen:
--
--   [portrait][ player ]  [1][2][3][4][5][6][=]  [ target ][portrait]
--
--   Unit frames: a health bar in the class color (red for an enemy) on a dark
--   backing with a thin black border, the name on the left, the health on the
--   right ("439K | 100%"), a slim power bar underneath and the portrait on the
--   outer end. The target's debuffs line up above its frame. They replace the
--   stock player and target frames.
--
--   Action bar: the game only uses the first bar. Buttons 1 to 6 and the last
--   button (the = key) make the middle of the row; the rest of the bar and its
--   art are put away. The experience bar becomes a thin strip under the row.
--
--   Also: the hero's buffs and debuffs above the player frame with time left
--   and stacks, cooldown numbers on the buttons, a square minimap, a flat
--   chat panel scrolled with the mouse wheel, and the micro buttons in the
--   bottom right corner, shown when the mouse reaches them.
--
-- The row sits a little under the hero, who stands in the middle of the screen.
--
-- Left click a frame to target it, right click for its menu. Alt-drag either
-- frame to move the whole row.

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local FONT = "Fonts\\FRIZQT__.TTF"

local BAR_BUTTONS = { 1, 2, 3, 4, 5, 6, 12 }     -- 12 is the = key
local BUTTON_SIZE = 36
local BUTTON_GAP = 2
local ROW_BELOW_CENTER = 150                    -- the row sits this far under the hero, who stands mid-screen
local SECTION_GAP = 6                           -- between a unit frame and the buttons

local FRAME_WIDTH = 150                         -- the bar part of a unit frame
local POWER_HEIGHT = 3
local HEALTH_HEIGHT = BUTTON_SIZE - POWER_HEIGHT - 1

local ENEMY = { 0.80, 0.22, 0.22 }

local CHAT_SIZE = 12                            -- default; /nfui chat N changes it

-- Saved between sessions; the /nfui command at the end of the file changes them.
local function Settings()
	nfUIDB = nfUIDB or {}
	if nfUIDB.damageText == nil then
		nfUIDB.damageText = true
	end
	nfUIDB.chatSize = nfUIDB.chatSize or CHAT_SIZE
	return nfUIDB
end

-- 1.12 paints shamans in the paladin's pink; they wear their modern blue here.
local CLASS_OVERRIDES = {
	SHAMAN = { r = 0.00, g = 0.44, b = 0.87 },
}

local POWER_COLORS = {
	[0] = { 0.25, 0.50, 1.00 },   -- mana
	[1] = { 0.85, 0.20, 0.20 },   -- rage
	[2] = { 1.00, 0.55, 0.15 },   -- focus
	[3] = { 1.00, 0.90, 0.25 },   -- energy
}

------------------------------------------------------------------------------
-- Pieces

-- A thin black border: a flat texture one pixel larger than the frame.
local function AddBorder(frame) return nfUIWidgets.Fill(frame,{0,0,0,1},"BACKGROUND",-1) end
local function AddBacking(frame,layer) return nfUIWidgets.Fill(frame,{0.09,0.09,0.11,1},layer or "BORDER") end
local FlatBar=nfUIWidgets.Bar
local function Text(parent,size,point,x,y) return nfUIWidgets.Label(parent,size,point,x,y) end

local function Hide(name)
	local object = getglobal(name)
	if object then
		object:Hide()
	end
end

-- 439K, 1.2M
local function Short(value)
	if value >= 1000000 then
		return string.format("%.1fM", value / 1000000)
	elseif value >= 10000 then
		return math.floor(value / 1000 + 0.5).."K"
	end
	return value
end

------------------------------------------------------------------------------
-- The row: the buttons' holder is the anchor everything else hangs from.

local row = CreateFrame("Frame", "nfUIRow", UIParent)
row:SetWidth(table.getn(BAR_BUTTONS) * (BUTTON_SIZE + BUTTON_GAP) - BUTTON_GAP)
row:SetHeight(BUTTON_SIZE)
row:SetPoint("CENTER", UIParent, "CENTER", 0, -ROW_BELOW_CENTER)
row:SetMovable(true)
row:SetFrameStrata("LOW")

-- A dark, bordered slot behind every button, so an empty one still reads as a
-- slot. These are frames of the row, not textures of the buttons: a texture
-- added to a button's own background layer draws over its icon.
local slots = {}
for position = 1, table.getn(BAR_BUTTONS) do
	local slot = CreateFrame("Frame", nil, row)
	slot:SetWidth(BUTTON_SIZE)
	slot:SetHeight(BUTTON_SIZE)
	slot:SetPoint("LEFT", row, "LEFT", (position - 1) * (BUTTON_SIZE + BUTTON_GAP), 0)
	-- Borderless icon: slot
	AddBacking(slot)
	slots[position] = slot
end

------------------------------------------------------------------------------
-- Unit frames

local function HealthColor(unit)
	-- Players wear their class color; everything else on the field is an enemy.
	if UnitIsPlayer(unit) then
		local _, class = UnitClass(unit)
		local color = class and (CLASS_OVERRIDES[class] or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]))
		if color then
			return color.r, color.g, color.b
		end
		return 0.6, 0.6, 0.6
	end
	return ENEMY[1], ENEMY[2], ENEMY[3]
end

-- side: "LEFT" puts the frame left of the buttons with its portrait on the far
-- left; "RIGHT" mirrors it.
local function UnitFrame(unit,name,side,dropdown)
    local widget=CreateFrame("Button",name,UIParent)
    widget.unit=unit;widget:SetHeight(BUTTON_SIZE);widget:SetWidth(FRAME_WIDTH+BUTTON_SIZE+1)
    local isPlayer=side=="LEFT"
    widget:SetPoint(isPlayer and "RIGHT" or "LEFT",row,isPlayer and "LEFT" or "RIGHT",isPlayer and -SECTION_GAP or SECTION_GAP,0)
    local portrait=CreateFrame("Frame",nil,widget)
    portrait:SetHeight(BUTTON_SIZE);portrait:SetWidth(BUTTON_SIZE);portrait:SetPoint(side,widget,side,0,0)
    nfUIWidgets.Fill(portrait,{0.04,0.04,0.04,1},"BACKGROUND")
    portrait.texture=portrait:CreateTexture(nil,"ARTWORK");portrait.texture:SetAllPoints(portrait)
    portrait.texture:SetTexCoord(0.15,0.85,0.15,0.85);widget.portrait=portrait
    widget.health=FlatBar(widget,FRAME_WIDTH,HEALTH_HEIGHT)
    local corner=isPlayer and "TOPRIGHT" or "TOPLEFT"
    widget.health:SetPoint(corner,widget,corner,0,0)
    widget.power=FlatBar(widget,FRAME_WIDTH,POWER_HEIGHT);widget.power:SetPoint("TOP",widget.health,"BOTTOM",0,-1)
    widget.name=Text(widget.health,11,"LEFT",5,0);widget.name:SetWidth(FRAME_WIDTH-82);widget.name:SetHeight(12);widget.name:SetJustifyH("LEFT")
    widget.value=Text(widget.health,11,"RIGHT",-5,0)
    widget.name:SetTextColor(1,1,1);widget.value:SetTextColor(1,1,1)
    local absorb=CreateFrame("StatusBar",nil,widget.health)
    absorb:SetMinMaxValues(0,1);absorb:SetStatusBarTexture(FLAT);absorb:SetStatusBarColor(0.2,0.75,1,0.85)
    absorb:SetWidth(FRAME_WIDTH);absorb:SetHeight(3);absorb:SetPoint("BOTTOMLEFT",widget.health,"BOTTOMLEFT",0,0);absorb:Hide()
    widget.shield=absorb;widget.shieldText=Text(widget.health,10,"TOPRIGHT",-5,-2)
    widget.shieldText:SetTextColor(0.4,0.85,1);widget.shieldText:Hide()
    widget:RegisterForClicks("LeftButtonUp","RightButtonUp");widget:RegisterForDrag("LeftButton")
    widget:SetScript("OnClick",function()
        local menu=dropdown and getglobal(dropdown)
        if arg1=="RightButton" and menu then ToggleDropDownMenu(1,nil,menu,"cursor") else TargetUnit(unit) end
    end)
    widget:SetScript("OnDragStart",function()
        if not IsAltKeyDown() then return end
        if nfUIConfig.FreezePositions then nfUIConfig.FreezePositions() end
        widget:SetMovable(true);widget:StartMoving()
    end)
    widget:SetScript("OnDragStop",function() widget:StopMovingOrSizing();if nfUIConfig.SaveElement then nfUIConfig.SaveElement(widget) end end)
    return widget
end

local function UpdatePortrait(frame)
	if UnitExists(frame.unit) then
		SetPortraitTexture(frame.portrait.texture, frame.unit)
	end
end

local function UpdateUnitFrame(widget)
    local unit=widget.unit
    if not UnitExists(unit) then
        widget.shield:Hide();widget.shieldText:Hide()
        if nfUIConfig.editing then
            widget:Show();widget.name:SetText("Target preview");widget.value:SetText("75%")
            widget.health:SetValue(0.75);widget.power:SetValue(0.5)
        else widget:Hide() end
        return
    end
    widget:Show()
    local current,maximum=UnitHealth(unit),UnitHealthMax(unit)
    local fraction=maximum>0 and current/maximum or 0
    local percent=math.floor(fraction*100+0.5)
    local options=nfUIDB and nfUIDB[unit.."Style"] or {}
    local red,green,blue=HealthColor(unit)
    if options.healthColor~=false then
        local value=math.max(0,math.min(1,fraction));red=math.min(1,2-2*value);green=math.min(1,2*value);blue=0.15
    end
    widget.health:SetStatusBarColor(red,green,blue,1);widget.health:SetValue(fraction)
    widget.name:SetText(nfUI_AbbreviateName(UnitName(unit)))
    local value=percent.."%"
    if UnitIsDead(unit) or UnitIsGhost(unit) then value="Dead"
    elseif options.healthText=="Numerical" then value=string.format("%.0f",current)
    elseif options.healthText=="CurrentHP+%" or (not options.healthText and unit=="player") then value=Short(current).." | "..value end
    widget.value:SetText(value)
    local total=nfUIConfig.GetShield and nfUIConfig.GetShield(unit)
    widget.shieldAvailable=total~=nil
    if options.showShield and total and total>0 and maximum>0 then
        widget.shield:SetValue(math.min(1,total/maximum));widget.shield:Show()
        widget.shieldText:SetText("+"..Short(total));widget.shieldText:Show()
    else widget.shield:Hide();widget.shieldText:Hide() end
    local energy,capacity=UnitMana(unit),UnitManaMax(unit)
    widget.power:SetValue(capacity>0 and energy/capacity or 0)
    if capacity>0 then widget.power:SetStatusBarColor(unpack(POWER_COLORS[UnitPowerType(unit)] or POWER_COLORS[0])) end
end

local player = UnitFrame("player", "nfUIPlayer", "LEFT", "PlayerFrameDropDown")
local target = UnitFrame("target", "nfUITarget", "RIGHT", "TargetFrameDropDown")

-- The target's debuffs, in a row above its frame.
local DEBUFFS = 8
local debuffs = {}
for index = 1, DEBUFFS do
	local icon = CreateFrame("Frame", nil, target)
	icon:SetWidth(18)
	icon:SetHeight(18)
	icon:SetPoint("BOTTOMLEFT", target, "TOPLEFT", (index - 1) * 21, 4)
	-- Borderless icon: icon

	icon.texture = icon:CreateTexture(nil, "ARTWORK")
	icon.texture:SetAllPoints(icon)
	icon.texture:SetTexCoord(0, 1, 0, 1)

	icon.count = Text(icon, 9, "BOTTOMRIGHT", -1, 1)
	icon:Hide()
	debuffs[index] = icon
end

local function UpdateDebuffs()
	for index = 1, DEBUFFS do
		local texture, count = UnitDebuff("target", index)
		local icon = debuffs[index]
        icon.nfuiPreview=nil
		if texture then
			icon.texture:SetTexture(texture)
			icon.count:SetText(count and count > 1 and count or "")
			icon:Show()
		else
            if nfUIConfig and nfUIConfig.editing then
                icon.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                icon.count:SetText("2"); icon.nfuiPreview=true; icon:Show()
            else icon:Hide() end
		end
	end
end

local elapsed = 0
local unitUpdater = CreateFrame("Frame")
unitUpdater:SetScript("OnUpdate", function()
	elapsed = elapsed + arg1
	if elapsed < 0.05 then
		return
	end
	elapsed = 0
	UpdateUnitFrame(player)
	UpdateUnitFrame(target)
	if UnitExists("target") or (nfUIConfig and nfUIConfig.editing) then
		UpdateDebuffs()
	end
end)

local function HideStockUnitFrames()
	for _, name in pairs({ "PlayerFrame", "TargetFrame" }) do
		local frame = getglobal(name)
		if frame then
			frame:UnregisterAllEvents()
			frame:Hide()
		end
	end
end

------------------------------------------------------------------------------
-- Action bar

-- Flat look: no rounded slot art and a cropped icon; the row's slot behind it
-- supplies the border.
local function StyleButton(button)
    local key=button:GetName();if not key then return end
    for _,suffix in ipairs({"NormalTexture","Border"}) do
        local region=getglobal(key..suffix);if region then region:SetAlpha(0) end
    end
    local normal=button.GetNormalTexture and button:GetNormalTexture();if normal then normal:SetAlpha(0) end
    local image=getglobal(key.."Icon");if image then image:SetTexCoord(0.08,0.92,0.08,0.92) end
    if button.nfuiStyled then return end
    button.nfuiStyled=true
    local shortcut=getglobal(key.."HotKey")
    if shortcut then shortcut:SetFont(FONT,10,"OUTLINE");shortcut:ClearAllPoints();shortcut:SetPoint("TOPRIGHT",button,"TOPRIGHT",-1,-2) end
end

local stockActionButtonUpdate = ActionButton_Update
if stockActionButtonUpdate then
	ActionButton_Update = function()
		stockActionButtonUpdate()
		if this and this.nfuiKept then
			StyleButton(this)
		end
	end
end

local function PlaceButton(prefix, id, position)
	local button = getglobal(prefix..id)
	if not button then
		return
	end

	button:ClearAllPoints()
	if position then
		button:SetPoint("LEFT", row, "LEFT", (position - 1) * (BUTTON_SIZE + BUTTON_GAP), 0)
		button.nfuiKept = true
		StyleButton(button)
	else
		-- Off screen rather than hidden: the stock code shows buttons on its own.
		button:SetPoint("TOP", UIParent, "BOTTOM", 0, -600)
	end
end

local function LayoutBar()
	local positions = {}
	for position = 1, table.getn(BAR_BUTTONS) do
		positions[BAR_BUTTONS[position]] = position
	end

	-- A stance bar's buttons, when a class has one, sit where the main bar's do.
	for id = 1, 12 do
		PlaceButton("ActionButton", id, positions[id])
		PlaceButton("BonusActionButton", id, positions[id])
	end

	for _, name in pairs({
		"MainMenuBarTexture0", "MainMenuBarTexture1", "MainMenuBarTexture2", "MainMenuBarTexture3",
		"MainMenuBarLeftEndCap", "MainMenuBarRightEndCap",
		"ActionBarUpButton", "ActionBarDownButton", "MainMenuBarPageNumber",
		"MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot", "CharacterBag3Slot",
		"KeyRingButton", "MainMenuBarPerformanceBarFrame",
		"BonusActionBarTexture0", "BonusActionBarTexture1",
		"MainMenuXPBarTexture0", "MainMenuXPBarTexture1", "MainMenuXPBarTexture2", "MainMenuXPBarTexture3",
		"ExhaustionTick",
	}) do
		Hide(name)
	end

	-- The experience bar: a thin flat strip under the whole row.
	local xp = getglobal("MainMenuExpBar")
	if xp then
		xp:ClearAllPoints()
		xp:SetPoint("TOP", row, "BOTTOM", 0, -5)
		xp:SetWidth(row:GetWidth() + 2 * (SECTION_GAP + FRAME_WIDTH + 1 + BUTTON_SIZE))
		xp:SetHeight(4)
		xp:SetStatusBarTexture(FLAT)
		if not xp.nfuiBorder then
			xp.nfuiBorder = AddBorder(xp)
			xp.nfuiBack = AddBacking(xp)
		end
	end
end

------------------------------------------------------------------------------
-- The hero's buffs and debuffs, in a row above the player frame, each with
-- its time left and its stacks. Right click a buff to cancel it.

local AURA_SIZE = 22
local AURA_MAX = 12

local function TimeText(seconds)
	if seconds >= 3600 then
		return math.floor(seconds / 3600 + 0.5).."h"
	elseif seconds >= 60 then
		return math.floor(seconds / 60 + 0.5).."m"
	elseif seconds >= 10 then
		return math.floor(seconds)
	end
	return string.format("%.1f", seconds)
end

local auras = {}
for index = 1, AURA_MAX do
	local aura = CreateFrame("Button", nil, player)
	aura:SetWidth(AURA_SIZE)
	aura:SetHeight(AURA_SIZE)
	aura:SetPoint("BOTTOMLEFT", player, "TOPLEFT", (index - 1) * (AURA_SIZE + 3), 5)
	aura.border = AddBorder(aura); aura.border:Hide()

	aura.texture = aura:CreateTexture(nil, "ARTWORK")
	aura.texture:SetAllPoints(aura)
	aura.texture:SetTexCoord(0, 1, 0, 1)

	aura.time = Text(aura, 10, "CENTER", 0, 0)
	aura.time:SetTextColor(1, 0.95, 0.6)
	aura.count = Text(aura, 9, "BOTTOMRIGHT", -1, 1)

	aura:RegisterForClicks("RightButtonUp")
	aura:SetScript("OnClick", function() if this.helpful and not this.nfuiPreview then CancelPlayerBuff(this.buffIndex) end end)
	aura:SetScript("OnEnter", function()
        if this.nfuiPreview then return end
		GameTooltip:SetOwner(this, "ANCHOR_TOPLEFT")
		GameTooltip:SetPlayerBuff(this.buffIndex)
	end)
	aura:SetScript("OnLeave", function() GameTooltip:Hide() end)
	aura:Hide()
	auras[index] = aura
end

local function UpdateAuras()
    local entries={}
    for _,filter in ipairs({"HELPFUL","HARMFUL"}) do
        for slot=0,15 do
            local id=GetPlayerBuff(slot,filter)
            if id and id>=0 and table.getn(entries)<AURA_MAX then table.insert(entries,{id=id,helpful=filter=="HELPFUL"}) end
        end
    end
    for index,widget in ipairs(auras) do
        local entry=entries[index];widget.nfuiPreview=nil
        if entry then
            widget.buffIndex=entry.id;widget.helpful=entry.helpful;widget.texture:SetTexture(GetPlayerBuffTexture(entry.id))
            local remaining=GetPlayerBuffTimeLeft(entry.id);local stacks=GetPlayerBuffApplications(entry.id)
            widget.time:SetText(remaining and remaining>0 and TimeText(remaining) or "")
            widget.count:SetText(stacks and stacks>1 and stacks or "");widget:Show()
        elseif nfUIConfig.editing then
            widget.nfuiPreview=true;widget.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            widget.time:SetText("30s");widget.count:SetText("2");widget:Show()
        else widget:Hide() end
    end
end

local auraElapsed = 0
local auraUpdater = CreateFrame("Frame")
auraUpdater:SetScript("OnUpdate", function()
	auraElapsed = auraElapsed + arg1
	if auraElapsed >= 0.1 then
		auraElapsed = 0
		UpdateAuras()
	end
end)

local function HideStockBuffs()
	for _, name in pairs({ "BuffFrame", "TemporaryEnchantFrame" }) do
		local frame = getglobal(name)
		if frame then
			frame:Hide()
		end
	end
end

------------------------------------------------------------------------------
-- Cooldown numbers on the action buttons. OmniCC does the same job; with it
-- installed, this stands aside.

if CooldownFrame_SetTimer and not OmniCC_OnUpdate then
	local stockSetTimer = CooldownFrame_SetTimer

	local function CounterUpdate()
		local left = this.start + this.duration - GetTime()
		if left <= 0 then
			this:Hide()
			return
		end
		this.text:SetText(TimeText(left))
	end

	CooldownFrame_SetTimer = function(cooldown, start, duration, enable)
		stockSetTimer(cooldown, start, duration, enable)

		local parent = cooldown and cooldown:GetParent()
		if not parent then
			return
		end

		local counter = parent.nfuiCounter
		if not counter then
			counter = CreateFrame("Frame", nil, parent)
			counter:SetAllPoints(parent)
			counter:SetFrameLevel(cooldown:GetFrameLevel() + 3)
			counter.text = Text(counter, (nfUIDB and nfUIDB.action and nfUIDB.action.cooldownFont) or 14, "CENTER", 0, 0)
			counter.text:SetTextColor(1, 0.95, 0.6)
			counter:SetScript("OnUpdate", CounterUpdate)
			parent.nfuiCounter = counter
		end

		-- The global cooldown's flicker is not worth a number.
		if start and start > 0 and duration and duration > 1.5 and enable and enable > 0 then
			counter.start, counter.duration = start, duration
			counter:Show()
		else
			counter:Hide()
		end
	end
end

------------------------------------------------------------------------------
-- A square minimap with a thin border, zoomed with the mouse wheel.

------------------------------------------------------------------------------
-- The micro buttons (character, talents, map, menu, help) go to the bottom
-- right corner. The others are chained to the first, so moving it moves all.

local function MoveMicroButtons()
	local first = getglobal("CharacterMicroButton")
	if first then
		first:ClearAllPoints()
		first:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMRIGHT", -140, 2)
	end
end

------------------------------------------------------------------------------
-- The micro buttons stay out of sight until the mouse reaches their corner.

local MICRO_BUTTONS = {
	"CharacterMicroButton", "SpellbookMicroButton", "TalentMicroButton", "QuestLogMicroButton",
	"SocialsMicroButton", "WorldMapMicroButton", "MainMenuMicroButton", "HelpMicroButton",
}

local microZone = CreateFrame("Frame", "nfUIMicroZone", UIParent)
microZone:SetWidth(170)
microZone:SetHeight(60)
microZone:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)

local microAlpha = 0
microZone:SetScript("OnUpdate", function()
	local over=false
    for _,name in ipairs(MICRO_BUTTONS) do
        local button=getglobal(name)
        if button and button:IsVisible() and MouseIsOver(button) then over=true end
    end
    local want = ((nfUIConfig and nfUIConfig.editing) or over) and 1 or 0
	if microAlpha == want then
		return
	end

	-- A quick fade either way.
	local step = arg1 * 6
	if want > microAlpha then
		microAlpha = math.min(1, microAlpha + step)
	else
		microAlpha = math.max(0, microAlpha - step)
	end
	for _, name in pairs(MICRO_BUTTONS) do
		local button = getglobal(name)
		if button then
			button:SetAlpha(microAlpha)
		end
	end
end)

local function HideMicroButtons()
	microAlpha = 0
	for _, name in pairs(MICRO_BUTTONS) do
		local button = getglobal(name)
		if button then
			button:SetAlpha(0)
		end
	end
end

------------------------------------------------------------------------------
-- Chat: a flat dark panel, no scroll buttons, no tab art. The mouse wheel
-- scrolls; with Shift held it jumps to the top or the bottom.

local function ChatWheel()
	if arg1 > 0 then
		if IsShiftKeyDown() then
			this:ScrollToTop()
		else
			this:ScrollUp()
		end
	else
		if IsShiftKeyDown() then
			this:ScrollToBottom()
		else
			this:ScrollDown()
		end
	end
end

local function StyleChat()
	Hide("ChatFrameMenuButton")

	for index = 1, 7 do
		local name = "ChatFrame"..index
		local chat = getglobal(name)
		if chat then
			Hide(name.."UpButton")
			Hide(name.."DownButton")
			Hide(name.."BottomButton")

			-- Plain text with a soft shadow in place of the stock look.
			local _, size = chat:GetFont()
			chat:SetFont(FONT, size or 13)
			chat:SetShadowColor(0, 0, 0, 1)
			chat:SetShadowOffset(1, -1)

			chat:EnableMouseWheel(true)
			chat:SetScript("OnMouseWheel", ChatWheel)

			if not chat.nfuiPanel then
				local panel = CreateFrame("Frame", nil, chat)
				panel:SetPoint("TOPLEFT", chat, "TOPLEFT", -6, 6)
				panel:SetPoint("BOTTOMRIGHT", chat, "BOTTOMRIGHT", 6, -6)
				panel:SetFrameLevel(math.max(0, chat:GetFrameLevel() - 1))
				local fill = panel:CreateTexture(nil, "BACKGROUND")
				fill:SetTexture(FLAT)
				fill:SetVertexColor(0.04, 0.04, 0.06, 0.55)
				fill:SetAllPoints(panel)
				-- An accent line down the left edge.
				local accent = panel:CreateTexture(nil, "BORDER")
				accent:SetTexture(FLAT)
				accent:SetVertexColor(1, 0.82, 0, 0.8)
				accent:SetWidth(2)
				accent:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
				accent:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 0)
				chat.nfuiPanel = panel
				chat.nfuiBackdrop=fill;chat.nfuiAccent=accent
			end

			-- The tab keeps its text and loses its art.
			for _, piece in pairs({ "Left", "Middle", "Right" }) do
				local art = getglobal(name.."Tab"..piece)
				if art then
					art:SetTexture("")
				end
			end
			local tabText = getglobal(name.."TabText")
			if tabText then
				tabText:SetFont(FONT, 11, "OUTLINE")
			end
		end
	end

	-- The edit box: a flat field under the chat.
	local edit = getglobal("ChatFrameEditBox")
	if edit then
		for _, piece in pairs({ "Left", "Mid", "Right" }) do
			local art = getglobal("ChatFrameEditBox"..piece)
			if art then
				art:SetTexture("")
			end
		end
		if not edit.nfuiBack then
			edit.nfuiBack = edit:CreateTexture(nil, "BACKGROUND")
			edit.nfuiBack:SetTexture(FLAT)
			edit.nfuiBack:SetVertexColor(0.04, 0.04, 0.06, 0.8)
			edit.nfuiBack:SetPoint("TOPLEFT", edit, "TOPLEFT", 4, -5)
			edit.nfuiBack:SetPoint("BOTTOMRIGHT", edit, "BOTTOMRIGHT", -4, 5)
		end
	end
end

------------------------------------------------------------------------------

-- One face everywhere: Friz Quadrata. The stock interface already uses it for
-- most things; chat, numbers, quest and mail text use other faces.

-- Read by the engine when the world loads, for the text it draws itself.
STANDARD_TEXT_FONT = FONT
UNIT_NAME_FONT = FONT
NAMEPLATE_FONT = FONT
DAMAGE_TEXT_FONT = FONT

local FONT_OBJECTS = {
	"GameFontNormal", "GameFontHighlight", "GameFontDisable", "GameFontGreen", "GameFontRed", "GameFontBlack", "GameFontWhite",
	"GameFontNormalSmall", "GameFontHighlightSmall", "GameFontHighlightSmallOutline", "GameFontDisableSmall",
	"GameFontDarkGraySmall", "GameFontGreenSmall", "GameFontRedSmall",
	"GameFontNormalLarge", "GameFontHighlightLarge", "GameFontDisableLarge", "GameFontGreenLarge", "GameFontRedLarge",
	"GameFontNormalHuge",
	"NumberFontNormal", "NumberFontNormalYellow", "NumberFontNormalSmall", "NumberFontNormalSmallGray",
	"NumberFontNormalLarge", "NumberFontNormalHuge",
	"ChatFontNormal", "ChatFontSmall", "CombatLogFont",
	"QuestTitleFont", "QuestFont", "QuestFontNormalSmall", "QuestFontHighlight",
	"ItemTextFontNormal", "MailTextFontNormal", "InvoiceTextFontNormal", "InvoiceTextFontSmall",
	"SubSpellFont", "DialogButtonNormalText", "DialogButtonHighlightText",
	"ZoneTextFont", "SubZoneTextFont", "PVPInfoTextFont", "ErrorFont", "WorldMapTextFont",
	"TextStatusBarText", "TextStatusBarTextSmall",
	"GameTooltipText", "GameTooltipTextSmall", "GameTooltipHeaderText",
}

local function ApplyFonts()
	for _, name in pairs(FONT_OBJECTS) do
		local object = getglobal(name)
		if object and object.GetFont and object.SetFont then
			local _, size, flags = object:GetFont()
			if size and size > 0 then
				object:SetFont(FONT, size, flags)
			end
		end
	end
end

------------------------------------------------------------------------------
-- Tooltip: a flat dark box with a hairline border, a slim health bar along its
-- bottom edge, and smaller type.

local TOOLTIPS = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "WorldMapTooltip" }

local TOOLTIP_BACKDROP = {
	bgFile = FLAT, edgeFile = FLAT,
	tile = false, edgeSize = 1,
	insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

local function PaintTooltip(tooltip)
	tooltip:SetBackdropColor(0.05, 0.05, 0.07, 0.95)
	tooltip:SetBackdropBorderColor(0, 0, 0, 1)
end

local function StyleTooltips()
	-- The stock code repaints a tooltip from these two.
	TOOLTIP_DEFAULT_COLOR = { r = 0, g = 0, b = 0 }
	TOOLTIP_DEFAULT_BACKGROUND_COLOR = { r = 0.05, g = 0.05, b = 0.07 }

	for _, name in pairs(TOOLTIPS) do
		local tooltip = getglobal(name)
		if tooltip and not tooltip.nfuiStyled then
			tooltip.nfuiStyled = true
			tooltip:SetBackdrop(TOOLTIP_BACKDROP)
			PaintTooltip(tooltip)

			local stockShow = tooltip:GetScript("OnShow")
			tooltip:SetScript("OnShow", function()
				if stockShow then
					stockShow()
				end
				PaintTooltip(this)
			end)
		end
	end

	local header = getglobal("GameTooltipHeaderText")
	if header then
		header:SetFont(FONT, 13)
	end
	local body = getglobal("GameTooltipText")
	if body then
		body:SetFont(FONT, 11)
	end
	local small = getglobal("GameTooltipTextSmall")
	if small then
		small:SetFont(FONT, 10)
	end

	local bar = getglobal("GameTooltipStatusBar")
	if bar and GameTooltip then
		bar:SetStatusBarTexture(FLAT)
		bar:SetHeight(4)
		bar:ClearAllPoints()
		bar:SetPoint("BOTTOMLEFT", GameTooltip, "BOTTOMLEFT", 1, 1)
		bar:SetPoint("BOTTOMRIGHT", GameTooltip, "BOTTOMRIGHT", -1, 1)
	end
end

------------------------------------------------------------------------------
-- Damage numbers: small, quick, and gone. A number pops over the enemy it hit,
-- shoots up and fades within half a second; a critical strike is larger and
-- gold. They replace the engine's own floating numbers while switched on
-- (/nfui damage switches back and forth).
--
-- The addon reads hits from the combat log, which names the enemy but not
-- which one of several with that name. The number goes over one of them.

local function ApplyDamageText()
    if nfUIConfig.ApplyQuickText then nfUIConfig.ApplyQuickText() end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:RegisterEvent("PLAYER_TARGET_CHANGED")
loader:RegisterEvent("UNIT_PORTRAIT_UPDATE")
loader:SetScript("OnEvent", function()
	if event == "PLAYER_ENTERING_WORLD" then
		HideStockUnitFrames()
		HideStockBuffs()
		LayoutBar()
		-- Map.lua installs the shared minimap layout.
		MoveMicroButtons()
		HideMicroButtons()
		ApplyFonts()
		StyleChat()
		StyleTooltips()
		ApplyDamageText()
		UpdatePortrait(player)
	elseif event == "PLAYER_TARGET_CHANGED" then
		UpdatePortrait(target)
	elseif arg1 == "player" then
		UpdatePortrait(player)
	elseif arg1 == "target" then
		UpdatePortrait(target)
	end
end)


------------------------------------------------------------------------------
-- Public configuration hooks. Keep native button parents/page IDs intact.
nfUIConfig = {}
local Config = nfUIConfig
Config.defaults = {
    layout = {scale=1, x=0, y=-150, sectionGap=6},
    player = {scale=1, width=150, height=36, portrait=36, powerHeight=3, nameFont=11, valueFont=11,hideName=false,healthArea="Right"},
    target = {scale=1, width=150, height=36, portrait=36, powerHeight=3, nameFont=11, valueFont=11},
    playerStyle = {showPortrait=true, healthText="CurrentHP+%", healthColor=true, showShield=true, shieldHeight=3, shieldFont=10},
    targetStyle = {showPortrait=true, healthText="Percentage", healthColor=true, showShield=true, shieldHeight=3, shieldFont=10},
    action = {scale=1, size=36, gap=2, hotkeyFont=10, cooldownFont=14, countFont=12},
    auras = {size=22, gap=3, timeFont=10, stackFont=9},
    debuffs = {size=18, gap=3, stackFont=9},
    xp = {width=650, height=4, gap=5},
    minimap = {size=140, scale=1},
    chat = {width=380, height=150, font=13, tabFont=11, editScale=1, editFont=13,backdropOpacity=0.55},
    dpsDisplay={width=250,height=240,scale=1,backdropOpacity=0.88,autoWidth=false,autoHeight=false},
    nameplates={enabled=true,amount="All",collision=false,stacking=false,scale=1,width=100,height=9,color={0.84,0.2,0.2},rankColors=true,showNames=true,abbreviate=true,nameFont=11,healthFont=10,healthText="Percentage"},
    micro = {scale=1}
}
Config.limits = {
    scale={0.5,2,0.05}, x={-800,800,5}, y={-600,600,5}, sectionGap={0,50,1},
    width={80,600,5}, height={16,100,1}, portrait={16,100,1}, powerHeight={1,16,1},
    nameFont={8,24,1}, valueFont={8,24,1},
    size={16,72,1}, gap={0,20,1}, hotkeyFont={8,24,1}, cooldownFont={8,32,1},
    timeFont={8,24,1}, stackFont={8,24,1}, font={8,24,1}, tabFont={8,24,1},
    countFont={8,24,1}, editFont={8,24,1},
    shieldHeight={1,10,1}, shieldFont={8,24,1},
    editScale={0.5,2,0.05}
}
function Config.Settings()
    if type(nfUIDB) ~= "table" then nfUIDB = {} end
    for category, defaults in pairs(Config.defaults) do
        if type(nfUIDB[category]) ~= "table" then nfUIDB[category] = {} end
        for key, value in pairs(defaults) do
            local current=nfUIDB[category][key]
            if type(value)=="number" then
                if tonumber(current)==nil then nfUIDB[category][key]=value end
            elseif type(current)~=type(value) then nfUIDB[category][key]=value end
        end
    end
    return nfUIDB
end

function Config.Range(category,key)
    if category=="nameplates" then
        if key=="width" then return 30,400,1 end
        if key=="height" then return 3,60,1 end
        if key=="nameFont" or key=="healthFont" then return 6,32,1 end
    end
    if key=="backdropOpacity" then return 0,1,0.01 end
    if category=="dpsDisplay" and key=="height" then return 66,UIParent:GetHeight(),1 end
    if category=="dpsDisplay" and key=="width" then return 112,UIParent:GetWidth(),1 end
    if category=="chat" and key=="width" then return 180,800,5 end
    if category=="chat" and key=="height" then return 60,500,5 end
    if category=="minimap" and key=="size" then return 80,300,5 end
    if category=="xp" and key=="width" then return 80,1800,5 end
    if category=="xp" and key=="height" then return 1,16,1 end
    local limit=Config.limits[key] or {1,100,1}
    return limit[1],limit[2],limit[3]
end

-- Keep small unit-frame labels readable and rasterize at whole physical pixels.
function Config.RegionEffectiveScale(region)
    -- 1.12 FontStrings expose GetParent, but not GetEffectiveScale.
    local owner=region
    while owner and not owner.GetEffectiveScale do owner=owner:GetParent() end
    return math.max(0.01,owner and owner:GetEffectiveScale() or UIParent:GetEffectiveScale())
end
function Config.UnitTextSize(region,size)
    local scale=Config.RegionEffectiveScale(region)
    return math.max(9,math.floor(size*scale+0.5))/scale
end
local function SizeUnit(frame,data)
    local side=frame.unit=="player" and "LEFT" or "RIGHT"
    local inner=frame.unit=="player" and "TOPRIGHT" or "TOPLEFT"
    frame.portrait:ClearAllPoints(); frame.portrait:SetPoint(side,frame,side,0,0)
    frame.health:ClearAllPoints(); frame.health:SetPoint(inner,frame,inner,0,0)
    frame.power:ClearAllPoints(); frame.power:SetPoint("TOP",frame.health,"BOTTOM",0,-1)
    frame.name:ClearAllPoints(); frame.name:SetPoint("LEFT",frame.health,"LEFT",5,0)
    frame.value:ClearAllPoints()
    local area=frame.unit=="player" and data.healthArea or "Right"
    if area=="Left" then
        frame.value:SetPoint("LEFT",frame.health,"LEFT",5,0);frame.value:SetJustifyH("LEFT")
        frame.name:ClearAllPoints();frame.name:SetPoint("RIGHT",frame.health,"RIGHT",-5,0);frame.name:SetJustifyH("RIGHT")
    elseif area=="Middle" then frame.value:SetPoint("CENTER",frame.health,"CENTER",0,0);frame.value:SetJustifyH("CENTER")
    else frame.value:SetPoint("RIGHT",frame.health,"RIGHT",-5,0);frame.value:SetJustifyH("RIGHT") end
    if area~="Left" then frame.name:SetJustifyH("LEFT") end
    if frame.unit=="player" and data.hideName then frame.name:Hide() else frame.name:Show() end
    frame:SetScale(data.scale * nfUIDB.layout.scale)
    local style=nfUIDB[frame.unit.."Style"]
    if style.showPortrait then frame.portrait:Show() else frame.portrait:Hide() end
    frame:SetWidth(data.width+(style.showPortrait and data.portrait+1 or 0))
    frame:SetHeight(data.height)
    frame.portrait:SetWidth(data.portrait); frame.portrait:SetHeight(data.portrait)
    frame.health:SetWidth(data.width)
    frame.health:SetHeight(math.max(4,data.height-data.powerHeight-1))
    frame.power:SetWidth(data.width); frame.power:SetHeight(data.powerHeight)
    local nameSize=Config.UnitTextSize(frame.name,data.nameFont)
    frame.name:SetFont(FONT,nameSize,"OUTLINE")
    frame.name:SetWidth(math.max(30,data.width*0.5-5)); frame.name:SetHeight(nameSize+4)
    frame.value:SetFont(FONT,Config.UnitTextSize(frame.value,data.valueFont),"OUTLINE")
    frame.shield:SetWidth(data.width); frame.shield:SetHeight(style.shieldHeight)
    frame.shieldText:SetFont(FONT,Config.UnitTextSize(frame.shieldText,style.shieldFont),"OUTLINE")
end

local minimapBaseScale = Minimap and Minimap:GetScale() or 1
local editBaseScale = ChatFrameEditBox and ChatFrameEditBox:GetScale() or 1
local microBaseScales = {}
for _, name in ipairs(MICRO_BUTTONS) do
    local button=getglobal(name)
    if button then microBaseScales[name]=button:GetScale() end
end

function Config.Apply()
    local db=Config.Settings()
    for category,defaults in pairs(Config.defaults) do
        for key in pairs(defaults) do
            if type(defaults[key])=="number" then
                local lo,hi=Config.Range(category,key)
                db[category][key]=math.max(lo,math.min(hi,tonumber(db[category][key]) or defaults[key]))
            end
        end
    end
    BUTTON_SIZE=db.action.size; BUTTON_GAP=db.action.gap; SECTION_GAP=db.layout.sectionGap
    row:SetScale(db.layout.scale*db.action.scale)
    row:SetWidth(table.getn(BAR_BUTTONS)*(BUTTON_SIZE+BUTTON_GAP)-BUTTON_GAP)
    row:SetHeight(BUTTON_SIZE)
    row:ClearAllPoints()
    row:SetPoint("CENTER",UIParent,"CENTER",db.layout.x/db.layout.scale,db.layout.y/db.layout.scale)
    for position,slot in ipairs(slots) do
        slot:SetWidth(BUTTON_SIZE); slot:SetHeight(BUTTON_SIZE)
        slot:ClearAllPoints()
        slot:SetPoint("LEFT",row,"LEFT",(position-1)*(BUTTON_SIZE+BUTTON_GAP),0)
    end
    db.player.powerHeight=math.min(db.player.powerHeight,db.player.height-5)
    db.target.powerHeight=math.min(db.target.powerHeight,db.target.height-5)
    SizeUnit(player,db.player); SizeUnit(target,db.target)
    player:ClearAllPoints()
    player:SetPoint("RIGHT",row,"LEFT",-SECTION_GAP/db.player.scale,0)
    target:ClearAllPoints()
    target:SetPoint("LEFT",row,"RIGHT",SECTION_GAP/db.target.scale,0)
    LayoutBar()
    for _,prefix in ipairs({"ActionButton","BonusActionButton"}) do
        for _,id in ipairs(BAR_BUTTONS) do
            local button=getglobal(prefix..id)
            if button then
                button:SetWidth(BUTTON_SIZE); button:SetHeight(BUTTON_SIZE)
                local parent=button:GetParent()
                local parentScale=parent and parent:GetEffectiveScale() or UIParent:GetEffectiveScale()
                button:SetScale(row:GetEffectiveScale()/parentScale)
                local hotkey=getglobal(prefix..id.."HotKey")
                if hotkey then
                    hotkey:SetFont(FONT,db.action.hotkeyFont,"OUTLINE")
                    hotkey:ClearAllPoints(); hotkey:SetPoint("TOPRIGHT",button,"TOPRIGHT",-1,-2)
                end
                local count=getglobal(prefix..id.."Count")
                if count then
                    count:SetFont(FONT,db.action.countFont,"OUTLINE")
                    count:ClearAllPoints(); count:SetPoint("BOTTOMRIGHT",button,"BOTTOMRIGHT",-2,2)
                end
                if button.nfuiCounter then
                    button.nfuiCounter.text:SetFont(FONT,db.action.cooldownFont,"OUTLINE")
                    button.nfuiCounter.text:ClearAllPoints()
                    button.nfuiCounter.text:SetPoint("CENTER",button.nfuiCounter,"CENTER",0,0)
                end
                local cooldown=getglobal(prefix..id.."Cooldown")
                if cooldown then cooldown:SetWidth(BUTTON_SIZE); cooldown:SetHeight(BUTTON_SIZE) end
            end
        end
    end
    for index,aura in ipairs(auras) do
        aura:SetWidth(db.auras.size); aura:SetHeight(db.auras.size)
        aura:ClearAllPoints()
        aura:SetPoint("BOTTOMLEFT",player,"TOPLEFT",(index-1)*(db.auras.size+db.auras.gap),5)
        aura.time:ClearAllPoints(); aura.time:SetPoint("CENTER",aura,"CENTER",0,0)
        aura.count:ClearAllPoints(); aura.count:SetPoint("BOTTOMRIGHT",aura,"BOTTOMRIGHT",-1,1)
        aura.time:SetFont(FONT,db.auras.timeFont,"OUTLINE")
        aura.count:SetFont(FONT,db.auras.stackFont,"OUTLINE")
    end
    for index,icon in ipairs(debuffs) do
        icon:SetWidth(db.debuffs.size); icon:SetHeight(db.debuffs.size)
        icon:ClearAllPoints()
        icon:SetPoint("BOTTOMLEFT",target,"TOPLEFT",(index-1)*(db.debuffs.size+db.debuffs.gap),4)
        icon.count:ClearAllPoints(); icon.count:SetPoint("BOTTOMRIGHT",icon,"BOTTOMRIGHT",-1,1)
        icon.count:SetFont(FONT,db.debuffs.stackFont,"OUTLINE")
    end
    local xp=getglobal("MainMenuExpBar")
    if xp then
        local parent=xp:GetParent()
        local parentScale=parent and parent:GetEffectiveScale() or UIParent:GetEffectiveScale()
        xp:SetScale(row:GetEffectiveScale()/parentScale)
        xp:ClearAllPoints(); xp:SetPoint("TOP",row,"BOTTOM",0,-db.xp.gap)
        xp:SetWidth(db.xp.width)
        xp:SetHeight(db.xp.height)
    end
    if Minimap then
        Minimap:SetWidth(db.minimap.size); Minimap:SetHeight(db.minimap.size)
        Minimap:SetScale(minimapBaseScale*db.minimap.scale)
    end
    for i=1,7 do
        local chat=getglobal("ChatFrame"..i)
        if chat then
            chat:SetWidth(db.chat.width); chat:SetHeight(db.chat.height)
            chat:SetFont(FONT,db.chat.font)
          if chat.nfuiBackdrop then chat.nfuiBackdrop:SetVertexColor(0.04,0.04,0.06,db.chat.backdropOpacity) end
          if chat.nfuiAccent then chat.nfuiAccent:SetAlpha(math.min(1,db.chat.backdropOpacity/0.55)) end
            local tab=getglobal("ChatFrame"..i.."TabText")
            if tab then tab:SetFont(FONT,db.chat.tabFont,"OUTLINE") end
        end
    end
    if ChatFrameEditBox then
        ChatFrameEditBox:SetScale(editBaseScale*db.chat.editScale)
        ChatFrameEditBox:SetFont(FONT,db.chat.editFont)
    end
    for _,name in ipairs(MICRO_BUTTONS) do
        local button=getglobal(name)
        if button then button:SetScale((microBaseScales[name] or 1)*db.micro.scale) end
    end
    local first=getglobal("CharacterMicroButton")
    if first then
        first:ClearAllPoints()
        first:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMRIGHT",-140,2/db.micro.scale)
    end
    microZone:SetWidth(170*db.micro.scale); microZone:SetHeight(60*db.micro.scale)
    if Config.LayoutCompass then Config.LayoutCompass() end
    if Config.ApplyPositions then Config.ApplyPositions() end
    UpdateUnitFrame(player); UpdateUnitFrame(target)
end

function Config.SaveRowPosition()
    local x,y=row:GetCenter()
    if x and y then
        local ratio=row:GetEffectiveScale()/UIParent:GetEffectiveScale()
        local db=Config.Settings()
        db.layout.x=x*ratio-UIParent:GetWidth()/2
        db.layout.y=y*ratio-UIParent:GetHeight()/2
        Config.Apply()
        if Config.Refresh then Config.Refresh() end
    end
end

function Config.Reset(category)
    local db=Config.Settings()
    for name,defaults in pairs(Config.defaults) do
        if not category or category==name or ((category=="player" or category=="target") and name==category.."Style") then
            db[name]={}
            for key,value in pairs(defaults) do db[name][key]=value end
        end
    end
    if Config.ClearPositions then Config.ClearPositions(category) end
    if Config.ClearElementSizes then Config.ClearElementSizes(category) end
    Config.Apply()
end

Config.row=row
Config.player=player
Config.target=target
Config.auras=auras
Config.debuffs=debuffs
Config.slots=slots
Config.buttonIDs=BAR_BUTTONS
Config.microButtons=MICRO_BUTTONS
Config.microZone=microZone
Config.UpdateUnits=function() UpdateUnitFrame(player); UpdateUnitFrame(target) end
local configLoader=CreateFrame("Frame","nfUIConfigLoader",UIParent)
configLoader:RegisterEvent("VARIABLES_LOADED")
configLoader:RegisterEvent("PLAYER_ENTERING_WORLD")
configLoader:SetScript("OnEvent",function() Config.Apply() end)


Config.ApplyDamageText=ApplyDamageText
