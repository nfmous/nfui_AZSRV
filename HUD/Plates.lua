-- nfUI enemy plate rendering and collision layout.
-- A flat health bar on a dark backing with a thin black border, the name above
-- it, the unit's health on it, an execute-range marker, and a highlighted
-- target with its debuffs. Elites, guardians and bosses get larger plates in their own colors.
--
-- The 1.12 client owns the nameplate frames: they are unnamed children of
-- WorldFrame, recognized by their border texture. Each one is skinned once,
-- its stock art blanked and an overlay drawn from the stock health bar's
-- values. The client recycles a plate for another unit, so the overlay
-- re-reads the name every frame.
--
-- Native plate anchors remain client-owned; nfUI offsets the visual bars
-- using collision rectangles, optional upward stacking and two-second easing.
--
-- Visibility, caps, colors, geometry and text share the Nameplates settings page.
--
-- Slash commands:
--   /nfplates all        toggle all enemies / current target
--   /nfplates names      toggle name labels
--   /nfplates scale N    plate size, 0.6 to 2 (default 1)

local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local FONT = "Fonts\\FRIZQT__.TTF"
local BORDER_TEXTURE = "Interface\\Tooltips\\Nameplate-Border"

local EXECUTE_RANGE = 0.30      -- the game's execute effects start below this share of health

local KINDS = {
	normal   = { width = 100, height = 9,  nameSize = 9,  color = { 0.84, 0.20, 0.20 } },
	elite    = { width = 130, height = 11, nameSize = 11, color = { 1.00, 0.55, 0.10 } },
	guardian = { width = 150, height = 12, nameSize = 12, color = { 0.20, 0.75, 0.95 } },
	boss     = { width = 170, height = 14, nameSize = 13, color = { 0.72, 0.32, 1.00 } },
}
local EXECUTE_COLOR = { 1.00, 0.86, 0.25 }

-- The five bosses of each zone.
local BOSSES = {
	-- Elwynn Forest
	"Hogger", "Mother Fang", "Rhahk'Zor", "Mr. Smite", "Edwin VanCleef",
	-- Duskwood
	"Naraxis", "Mor'Ladim", "Stitches", "Lupos", "Morbent Fel",
	-- Warsong Gulch
	"Doomguard Commander", "Mannoroth's Herald", "Varimathras", "Lord Hel'nurath", "Lord Kazzak",
	-- Arathi Basin
	"Patchwerk", "Lord Blackwood", "Baron Rivendare", "Anub'Rekhan", "Kel'Thuzad",
	-- Feralas
	"Zevrim Thornhoof", "Alzzin the Wildshaper", "Tendris Warpwood", "Immol'thar", "King Gordok",
	-- Gurubashi Arena
	"High Priestess Jeklik", "High Priest Venoxis", "Bloodlord Mandokir", "Jin'do the Hexxer", "Hakkar the Soulflayer",
	-- Alterac Valley
	"Korrak the Bloodrager", "Ivus the Forest Lord", "Lokholar the Ice Lord", "Glacius the Frozen Titan", "Azuregos",
	-- Blackrock Mountain
	"General Angerforge", "Warchief Rend Blackhand", "Emperor Dagran Thaurissan", "Majordomo Executus", "Nefarian",
	-- Gates of Ahn'Qiraj
	"Kurinnaxx", "General Rajaxx", "Princess Huhuran", "Ossirian the Unscarred", "C'Thun",
}

-- The elites of each zone's horde: the three enemies the game's own tables
-- flag as elite in every zone.
local ELITES = {
	"Kobold Taskmaster", "Gruff Swiftbite", "Bellygrub",
	"Nightbane Worgen Alpha", "Carrion Recluse", "Flesh Eating Abomination",
	"Felguard Elite", "Infernal", "Doomguard",
	"Crypt Fiend", "Bone Golem", "Death Knight Captain",
	"Gordunni Brute", "Warpwood Treant", "Ironbark Protector",
	"Gurubashi Berserker", "Zulian Crocolisk", "Gurubashi Champion",
	"Alterac Yeti Lord", "Mountain Giant", "Winterax Warlord",
	"Core Hound", "Black Drake", "Molten Giant",
	"Qiraji Champion", "Anubisath Sentinel", "Obsidian Destroyer",
}

local kindByName = {}
for index = 1, table.getn(ELITES) do
	kindByName[ELITES[index]] = "elite"
end
for index = 1, table.getn(BOSSES) do
	kindByName[BOSSES[index]] = "boss"
end

local function Classify(name)
	if not name then
		return "normal"
	end
	-- A guardian's plate reads "<name> (Guardian)".
	if string.find(name, "(Guardian)", 1, true) then
		return "guardian"
	end
	return kindByName[name] or "normal"
end

local function Settings()
    local db=nfUIConfig.Settings().nameplates
    if not nfUIDB.nameplatesMigrated then
        if nfUIPlatesDB then db.scale=nfUIPlatesDB.scale or db.scale;db.showNames=nfUIPlatesDB.names~=false end
        nfUIDB.nameplatesMigrated=true
    end
    if db.stacking then db.collision=true end
    return db
end

-- 1234, 12.3k, 1.2m
local function Short(value)
	if value >= 1000000 then
		return string.format("%.1fm", value / 1000000)
	elseif value >= 10000 then
		return string.format("%.1fk", value / 1000)
	end
	return math.floor(value + 0.5)
end

local overlays = {}
nfUIPlatesRegistry = overlays

local function ApplyKind(overlay, kind)
	local style = KINDS[kind]
	local settings = Settings()
	local scale = settings.scale
	overlay.kind = kind
	overlay.style = style
	overlay.bar:SetWidth(settings.width * style.width / 100 * scale)
	overlay.bar:SetHeight(settings.height * style.height / 9 * scale)
	overlay.marker:SetHeight(settings.height * style.height / 9 * scale)
	overlay.marker:SetPoint("LEFT", overlay.bar, "LEFT", settings.width * style.width / 100 * scale * EXECUTE_RANGE, 0)
	overlay.name:SetFont(FONT, settings.nameFont * scale, "OUTLINE")
	overlay.name:SetWidth(overlay.bar:GetWidth());overlay.name:SetHeight(settings.nameFont*scale+4)
	overlay.health:SetFont(FONT, settings.healthFont * scale, "OUTLINE")
	overlay.name:SetText(settings.abbreviate and nfUI_AbbreviateName(overlay.stock.name:GetText()) or overlay.stock.name:GetText())

	overlay.named = settings.showNames
	if overlay.named and not overlay.put then
		overlay.name:Show()
	else
		overlay.name:Hide()
	end

end

-- Debuffs on the target's plate, with their stacks. The 1.12 client only tells
-- an addon about the debuffs of a unit it can name, and of all the plates on
-- screen only the target's can be told apart (it alone keeps full alpha).
local PLATE_DEBUFFS = 6
local DEBUFF_SIZE = 15

local function UpdatePlateDebuffs(overlay,target)
    if not target then
        if overlay.debuffsShown then for _,icon in ipairs(overlay.debuffs or {}) do icon:Hide() end end
        overlay.debuffsShown=nil;return
    end
    local W=nfUIWidgets
    overlay.debuffs=overlay.debuffs or {};overlay.debuffsShown=true
    local lift=overlay.named and Settings().nameFont*Settings().scale+7 or 4
    for index=1,PLATE_DEBUFFS do
        local texture,stacks=UnitDebuff("target",index)
        local icon=overlay.debuffs[index]
        if texture then
            if not icon then
                icon=CreateFrame("Frame",nil,overlay.bar);icon:SetHeight(DEBUFF_SIZE);icon:SetWidth(DEBUFF_SIZE)
                icon.texture=W.Fill(icon,{1,1,1,1},"ARTWORK");icon.texture:SetTexCoord(0.08,0.92,0.08,0.92)
                icon.count=W.Label(icon,9,"BOTTOMRIGHT",1,-1)
                overlay.debuffs[index]=icon
            end
            icon:ClearAllPoints();icon:SetPoint("BOTTOMLEFT",overlay.bar,"TOPLEFT",(index-1)*(DEBUFF_SIZE+2),lift)
            icon.texture:SetTexture(texture);icon.count:SetText(stacks and stacks>1 and stacks or "");icon:Show()
        elseif icon then icon:Hide() end
    end
end

local function UpdatePlate()
	local overlay = this
	local stock = overlay.stock

	local name = stock.name:GetText()
	if name ~= overlay.lastName then
		overlay.lastName = name
		overlay.name:SetText(Settings().abbreviate and nfUI_AbbreviateName(name) or name)
		ApplyKind(overlay, Classify(name))
	end

	-- The client dims every plate but the target's.
	local isTarget = UnitExists("target") and overlay.plate:GetAlpha() == 1

	if overlay.put then return end

	local low, high = stock.health:GetMinMaxValues()
	local value = stock.health:GetValue()
	local share = high > low and (value - low) / (high - low) or 0
	local percent = math.floor(share * 100 + 0.5)
	overlay.bar:SetValue(share)

	-- A 0 to 100 bar means the client only knows the percentage; anything else
	-- is the unit's real health.
    local mode=Settings().healthText
    if mode=="Numerical" then overlay.health:SetText(Short(value))
    elseif mode=="CurrentHP+%" then overlay.health:SetText(Short(value).." | "..percent.."%")
    else overlay.health:SetText(percent.."%") end

	local color = Settings().rankColors and overlay.style.color or Settings().color
	if share <= EXECUTE_RANGE then
		color = EXECUTE_COLOR
		overlay.marker:Hide()
	else
		overlay.marker:Show()
	end
	overlay.bar:SetStatusBarColor(color[1], color[2], color[3], 1)

	if isTarget then
		overlay.border:SetVertexColor(1, 1, 1, 1)
	else
		overlay.border:SetVertexColor(0, 0, 0, 1)
	end
	UpdatePlateDebuffs(overlay, isTarget)
end

local function IsNameplate(frame)
	local region = frame:GetRegions()
	return region and region.GetObjectType and region:GetObjectType() == "Texture"
		and region:GetTexture() == BORDER_TEXTURE
end

local function SkinPlate(plate)
    if plate.nfUIPlateOverlay then return end
    local bar=plate:GetChildren()
    if not bar or not bar.GetMinMaxValues then return end
    local regions={plate:GetRegions()};local source={health=bar}
    for index,region in ipairs(regions) do
        local kind=region:GetObjectType()
        if kind=="FontString" then
            if not source.name then source.name=region else source.level=region end
            region:SetAlpha(0)
        elseif kind=="Texture" and index<table.getn(regions) then region:SetAlpha(0);region:SetTexCoord(0,0,0,0) end
    end
    if not source.name then return end
    -- A nil status-bar texture is a no-op on some clients. Hide only the
    -- native bar child; the plate stays visible as our anchor/data source.
    source.health:SetAlpha(0)
    local W=nfUIWidgets
    local overlay=CreateFrame("Frame",nil,plate)
    overlay.stock=source;overlay.plate=plate;overlay.motion={};overlay:SetAllPoints(plate);overlay:SetAlpha(0)
    overlay.bar=CreateFrame("StatusBar",nil,overlay)
    overlay.bar:SetMinMaxValues(0,1);overlay.bar:SetStatusBarTexture(W.texture);overlay.bar:SetPoint("CENTER",overlay,"CENTER",0,-4)
    overlay.border=W.Fill(overlay.bar,{0,0,0,1},"BACKGROUND",-1)
    overlay.backing=W.Fill(overlay.bar,{0.1,0.1,0.12,1},"BORDER")
    overlay.marker=W.Fill(overlay.bar,{1,1,1,0.7},"OVERLAY");overlay.marker:ClearAllPoints();overlay.marker:SetWidth(1)
    overlay.name=W.Label(overlay,11,"BOTTOM",0,0,nil,{1,1,1})
    overlay.name:ClearAllPoints();overlay.name:SetPoint("BOTTOM",overlay.bar,"TOP",0,3)
    overlay.health=W.Label(overlay.bar,10,"RIGHT",-2,0,nil,{1,1,1})
    ApplyKind(overlay,"normal")
    overlay:SetScript("OnUpdate",UpdatePlate)
    plate.nfUIPlateOverlay=overlay;table.insert(overlays,overlay)
end

-- New plates only ever get appended to WorldFrame's children.
local scanned = 0
local scanner = CreateFrame("Frame")
scanner:SetScript("OnUpdate", function()
	local count = WorldFrame:GetNumChildren()
	if count ~= scanned then
		local children = { WorldFrame:GetChildren() }
		for index = scanned + 1, count do
			local child = children[index]
			if child and IsNameplate(child) then
				SkinPlate(child)
			end
		end
		scanned = count
	end
end)

-- Enemy nameplates are off by default; a run is unreadable without them.
scanner:RegisterEvent("PLAYER_ENTERING_WORLD")
scanner:SetScript("OnEvent", function() nfUIConfig.ApplyNameplates() end)

local function Restyle()
	for index = 1, table.getn(overlays) do
		ApplyKind(overlays[index], overlays[index].kind or "normal")
	end
end

local function Nearer(a,b)
    if a.depth~=b.depth then return a.depth>b.depth end
    if a.y~=b.y then return a.y<b.y end
    return a.index<b.index
end
local function MotionValue(state,now)
    local t=math.max(0,math.min(1,(now-state.started)/2))
    local ease=t*t*(3-2*t)
    return state.from+(state.target-state.from)*ease,t
end
local function Animate(overlay,key,target)
    local now=GetTime();overlay.motion=overlay.motion or {}
    local state=overlay.motion[key]
    if state and math.abs(state.target-target)<0.01 then return end
    local current=state and MotionValue(state,now) or 0
    overlay.motion[key]={from=current,target=target,started=now}
end
local function UpdateAnimations()
    local now=GetTime()
    for _,overlay in ipairs(overlays) do
        if overlay.motion then
            local move=overlay.motion.offset
            if move then
                local offset=MotionValue(move,now)
                if overlay.drawOffset~=offset then
                    overlay.bar:ClearAllPoints();overlay.bar:SetPoint("CENTER",overlay,"CENTER",0,-4+offset);overlay.drawOffset=offset
                end
            end
            local fade=overlay.motion.fade
            if fade then
                local alpha,t=MotionValue(fade,now)
                if overlay.drawAlpha~=alpha then overlay:SetAlpha(alpha);overlay.drawAlpha=alpha end
                if t>=1 and fade.target==0 then overlay.bar:Hide();overlay.name:Hide() end
            end
        end
    end
end
nfUIConfig.UpdateNameplateAnimations=UpdateAnimations
local function LayoutPlates()
    local settings=Settings();local candidates={}
    for index,overlay in ipairs(overlays) do
        overlay.layoutAccepted=false
        if overlay.plate:IsShown() then
            local x,y=overlay.plate:GetCenter()
            if x and y then
                local ratio=overlay.plate:GetEffectiveScale()/UIParent:GetEffectiveScale()
                local target=UnitExists("target") and overlay.plate:GetAlpha()==1
                if settings.enabled and (settings.amount~="Target" or target) then
                    local halfWidth=overlay.bar:GetWidth()*ratio/2+3
                    local halfHeight=overlay.bar:GetHeight()*ratio/2+3
                    local above=settings.showNames and settings.nameFont*settings.scale*ratio+5 or 0
                    if target and overlay.debuffsShown then above=above+(DEBUFF_SIZE+3)*ratio end
                    table.insert(candidates,{overlay=overlay,index=index,x=x*ratio,y=(y-4)*ratio,width=halfWidth,height=halfHeight,above=above,ratio=ratio,depth=ratio,target=target})
                end
            end
        end
    end
    table.sort(candidates,function(a,b)
        if a.target~=b.target then return a.target and true or false end
        return Nearer(a,b)
    end)
    local limit=settings.amount=="5 max" and 5 or settings.amount=="10 max" and 10 or table.getn(candidates)
    local selected={}
    for index=1,math.min(limit,table.getn(candidates)) do table.insert(selected,candidates[index]) end
    table.sort(selected,Nearer)
    local placed={}
    local function Rect(entry,y) return {left=entry.x-entry.width,right=entry.x+entry.width,bottom=y-entry.height,top=y+entry.height+entry.above} end
    local function Overlap(a,b) return a.left<b.right and a.right>b.left and a.bottom<b.top and a.top>b.bottom end
    for _,entry in ipairs(selected) do
        local y=entry.y
        if settings.collision then
            -- Each accepted invisible rectangle becomes an obstacle for later plates.
            for attempt=1,table.getn(placed)+1 do
                local bounds=Rect(entry,y);local hit
                for _,other in ipairs(placed) do if Overlap(bounds,other) then hit=other;break end end
                if not hit then break end
                local up=hit.top+entry.height+2
                local down=hit.bottom-entry.height-entry.above-2
                y=settings.stacking and up or (math.abs(up-entry.y)<=math.abs(down-entry.y) and up or down)
            end
        end
        local bounds=Rect(entry,y)
        if settings.stacking and bounds.top>UIParent:GetHeight() then
            -- Prefer upward slots, then use space below when the top is full.
            y=entry.y
            for attempt=1,table.getn(placed)+1 do
                local hit;local candidate=Rect(entry,y)
                for _,other in ipairs(placed) do if Overlap(candidate,other) then hit=other;break end end
                if not hit then break end
                y=hit.bottom-entry.height-entry.above-2
            end
            bounds=Rect(entry,y)
        end
        -- If the screen cannot fit another complete rectangle, omit it rather than overlap.
        local blocked=false
        if settings.collision then
            for _,other in ipairs(placed) do if Overlap(bounds,other) then blocked=true end end
            if bounds.top>UIParent:GetHeight() or bounds.bottom<0 then blocked=true end
        end
        if not blocked then
            local overlay=entry.overlay;overlay.put=nil;overlay.layoutAccepted=true
            local offset=(y-entry.y)/entry.ratio
            overlay.collisionOffset=offset
            Animate(overlay,"offset",offset);Animate(overlay,"fade",1)
            overlay.collisionBounds=bounds;overlay.bar:Show()
            if overlay.named then overlay.name:Show() end
            table.insert(placed,bounds)
        end
    end
    for _,overlay in ipairs(overlays) do
        if not overlay.layoutAccepted then
            overlay.put=true
            Animate(overlay,"fade",0)
            overlay.collisionBounds=nil
        end
    end
end
local pendingHide
local nativeEnabled=true
function nfUIConfig.ApplyNameplates()
    local settings=Settings()
    if settings.enabled then
        pendingHide=nil
        if not nativeEnabled or not NAMEPLATES_ON then ShowNameplates();NAMEPLATES_ON=1 end
        nativeEnabled=true
    elseif nativeEnabled and not pendingHide then pendingHide=GetTime()+2 end
    Restyle();LayoutPlates()
end
nfUIConfig.LayoutNameplates=LayoutPlates
local layoutDriver=CreateFrame("Frame","nfUIPlateLayout",UIParent)
local layoutAge=0
layoutDriver:SetScript("OnUpdate",function()
    UpdateAnimations()
    if pendingHide and GetTime()>=pendingHide then
        HideNameplates();NAMEPLATES_ON=nil;nativeEnabled=false;pendingHide=nil
    end
    layoutAge=layoutAge+(arg1 or 0);if layoutAge<0.03 then return end;layoutAge=0;LayoutPlates()
end)

local function Say(text)
	DEFAULT_CHAT_FRAME:AddMessage("nfUI Plates: "..text)
end

SLASH_NFUIPLATES1 = "/nfplates"
SlashCmdList["NFUIPLATES"] = function(msg)
	local settings = Settings()
	local _, _, command, argument = string.find(msg or "", "^(%S*)%s*(.*)$")
	local number = tonumber(argument)

	if command == "all" then
		settings.amount = settings.amount=="All" and "Target" or "All"
		Say("plates: "..settings.amount..".")
	elseif command == "names" then
		settings.showNames = not settings.showNames
		Say("names on "..(settings.showNames and "every plate" or "no plates")..".")
	elseif command == "scale" and number then
		settings.scale = math.max(0.6, math.min(2, number))
		Say("scale "..settings.scale..".")
	else
		Say("/nfplates all | names | scale 0.6-2")
		return
	end
	nfUIConfig.ApplyNameplates()
end
