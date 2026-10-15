-- Run data and layout are separate. The saved header corner stays fixed while the panel expands upward.
local C=nfUIConfig
local FONT="Fonts\\FRIZQT__.TTF"
C.defaults.runDisplay={width=206,height=320,scale=1,font=11,backdrop=true}
local range=C.Range
C.Range=function(category,key)
    if category=="runDisplay" then
        if key=="width" then return 140,800,1 end
        if key=="height" then return 100,UIParent:GetHeight(),1 end
        if key=="scale" then return 0.5,2,0.01 end
        if key=="font" then return 8,28,1 end
    end
    return range(category,key)
end
local model={kills=0,dealt=0,taken=0,crit={},hits={}}
local previousTime
local function Number(v) return type(v)=="number" and v==v and v-v==0 end
local function ResetModel() model={kills=0,dealt=0,taken=0,crit={},hits={}} end
local function Phase() return type(AZS_GetPhase)=="function" and AZS_GetPhase() or nil end
local function Alive()
    local now=GetTime()
    if not model.started then model.started=now end
    if model.pausedAt then model.started=model.started+now-model.pausedAt;model.pausedAt=nil end
    model.lastAction=now
end
local function Seconds()
    if Phase() and type(AZS_GetRunTime)=="function" then local t=AZS_GetRunTime();if Number(t) then return t end end
    return model.started and math.max(0,(model.ended or model.pausedAt or GetTime())-model.started) or 0
end
local function Short(v)
    if not Number(v) then return "-" end
    if v>=1000000 then return string.format("%.1fm",v/1000000) end
    if v>=1000 then return string.format("%.1fk",v/1000) end
    return string.format("%.0f",v)
end
local function Native(key,fallback) return type(AZS_RUN)=="table" and Number(AZS_RUN[key]) and AZS_RUN[key] or fallback end
local panel=CreateFrame("Frame","nfUIRun",UIParent)
panel:SetWidth(112);panel:SetHeight(32);panel:SetFrameStrata("MEDIUM")
panel:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"});panel:Hide()
local header=CreateFrame("Frame","nfUIRunHeader",panel)
header:SetHeight(32);header:EnableMouse(true);header:RegisterForDrag("LeftButton")
local title=header:CreateFontString(nil,"OVERLAY")
title:SetText("Run Stats");title:SetTextColor(1,0.82,0);title:SetPoint("LEFT",header,"LEFT",8,0)
local collapse=CreateFrame("Button","nfUIRunCollapse",panel,"UIPanelButtonTemplate")
collapse:SetWidth(22);collapse:SetHeight(22);collapse:SetPoint("BOTTOMRIGHT",panel,"BOTTOMRIGHT",-5,5)
local scroll=CreateFrame("ScrollFrame","nfUIRunScroll",panel)
local content=CreateFrame("Frame",nil,scroll);content:SetHeight(1);scroll:SetScrollChild(content)
local offset=0
scroll:EnableMouseWheel(true)
scroll:SetScript("OnMouseWheel",function()
    offset=math.max(0,math.min(math.max(0,content:GetHeight()-scroll:GetHeight()),offset-(arg1 or 0)*30))
    scroll:SetVerticalScroll(offset)
end)
local descriptions={{"time","Survived"},{"level","Level"},{"kills","Kills"},{"elites","Elites & guardians slain"},
    {"bosses","Bosses slain"},{"dealt","Damage dealt"},{"dps","Damage / sec"},{"taken","Damage taken"}}
local rows={}
local function Row(name)
    local row=CreateFrame("Frame",name,content)
    row.label=row:CreateFontString(nil,"OVERLAY");row.label:SetPoint("LEFT",row,"LEFT",0,0)
    row.label:SetJustifyH("LEFT");row.label:SetTextColor(0.82,0.82,0.82)
    row.value=row:CreateFontString(nil,"OVERLAY");row.value:SetPoint("RIGHT",row,"RIGHT",0,0)
    row.value:SetJustifyH("RIGHT");row.value:SetTextColor(1,0.82,0)
    return row
end
for _,d in ipairs(descriptions) do local row=Row("nfUIRunRow_"..d[1]);row.label:SetText(d[2]);rows[d[1]]=row end
local critHeading=content:CreateFontString(nil,"OVERLAY");critHeading:SetText("Biggest Crits");critHeading:SetTextColor(1,0.82,0)
local reset=CreateFrame("Button","nfUIRunCritReset",content,"UIPanelButtonTemplate")
reset:SetWidth(46);reset:SetHeight(20);reset:SetText("Reset")
local critRows={}
for i=1,10 do
    local row=Row("nfUIRunCrit"..i);row:EnableMouse(true);row:Hide()
    row:SetScript("OnEnter",function()
        local stats=row.ability and model.crit[row.ability];if not stats then return end
        GameTooltip:SetOwner(row,"ANCHOR_RIGHT");GameTooltip:AddLine(row.ability,1,0.82,0)
        GameTooltip:AddLine("Biggest: "..Short(stats.best),1,1,1);GameTooltip:AddLine("Last: "..Short(stats.last),1,1,1)
        GameTooltip:AddLine("Average: "..Short(stats.total/stats.count),1,1,1);GameTooltip:AddLine("Smallest: "..Short(stats.least),1,1,1)
        GameTooltip:AddLine("Critical hits: "..stats.count,1,1,1)
        local hits=model.hits[row.ability]
        if hits then GameTooltip:AddLine("Normal hit average: "..Short(hits.total/hits.count),0.8,0.8,0.8) end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave",function() GameTooltip:Hide() end);critRows[i]=row
end
local drag,layoutKey
local function Position()
    local db=C.Settings();db.positions=db.positions or {}
    if db.runCollapsed==nil then db.runCollapsed=true end
    local p=db.positions.runPanel;local old=db.elements and db.elements.runPanel
    if not db.runDisplay.layoutVersion then
        if old then
            for _,k in ipairs({"width","height","scale","font"}) do if Number(old[k]) then db.runDisplay[k]=old[k] end end
            db.elements.runPanel=nil
        end
        if p and not p.runAnchor then
            local scale=db.runDisplay.scale;local width=db.runCollapsed~=false and 112 or db.runDisplay.width
            local height=db.runCollapsed~=false and 32 or (old and old.height or 180)
            local right=p.x+width*scale/2>UIParent:GetWidth()/2
            p.x=p.x+(right and width*scale or 0);p.y=p.y+height*scale;p.runAnchor=right and "TOPRIGHT" or "TOPLEFT"
        end
        db.runDisplay.layoutVersion=1
    end
    if not p then p={x=24,y=math.max(64,UIParent:GetHeight()-260),runAnchor="TOPLEFT"};db.positions.runPanel=p end
    if p.runAnchor~="TOPLEFT" and p.runAnchor~="TOPRIGHT" then
        local right=p.x+panel:GetWidth()*db.runDisplay.scale/2>UIParent:GetWidth()/2
        if right then p.x=p.x+panel:GetWidth()*db.runDisplay.scale end
        p.runAnchor=right and "TOPRIGHT" or "TOPLEFT"
    end
    return p
end
local function Collapsed() return nfUIDB.runCollapsed~=false end
function C.CaptureRunPosition() local p=Position();return {x=p.x,y=p.y,runAnchor=p.runAnchor} end
function C.AnchorRunPosition(p)
    if not p or not Number(p.x) or not Number(p.y) then return end
    local saved=Position();saved.x=p.x;saved.y=p.y;if p.runAnchor then saved.runAnchor=p.runAnchor end
    local ratio=panel:GetEffectiveScale()/UIParent:GetEffectiveScale()
    local key=saved.runAnchor..":"..saved.x..":"..saved.y..":"..ratio
    if panel.positionKey~=key then
        panel:ClearAllPoints();panel:SetPoint(saved.runAnchor=="TOPRIGHT" and "BOTTOMRIGHT" or "BOTTOMLEFT",UIParent,"BOTTOMLEFT",saved.x/ratio,saved.y/ratio-32);panel.positionKey=key
    end
end
function C.LayoutRunPanel()
    local p=Position();local db=C.Settings().runDisplay
    db.scale=math.max(0.5,math.min(2,db.scale));db.width=math.max(140,math.min(800,db.width));db.height=math.max(100,math.min(UIParent:GetHeight(),db.height))
    local width=Collapsed() and 112 or db.width;local height=Collapsed() and 32 or db.height
    if C.MatchedDimension then width=C.MatchedDimension("runPanel","width",width);height=C.MatchedDimension("runPanel","height",height) end
    local key=width..":"..height..":"..db.scale..":"..db.font..":"..tostring(db.backdrop)..":"..tostring(Collapsed())
    if layoutKey~=key then
        layoutKey=key;panel:SetScale(db.scale);panel:SetWidth(width);panel:SetHeight(height)
        panel:SetBackdropColor(0.04,0.04,0.07,db.backdrop and 0.88 or 0)
        header:ClearAllPoints();header:SetPoint("BOTTOMLEFT",panel,"BOTTOMLEFT",0,0);header:SetWidth(width-30);title:SetFont(FONT,db.font,"OUTLINE")
        scroll:ClearAllPoints();scroll:SetPoint("BOTTOMLEFT",panel,"BOTTOMLEFT",8,36);scroll:SetWidth(width-16);scroll:SetHeight(math.max(1,height-44));content:SetWidth(width-16)
        for _,row in pairs(rows) do
            row:SetWidth(width-16);row:SetHeight(db.font+7);row.label:SetFont(FONT,db.font);row.value:SetFont(FONT,db.font);row.label:SetWidth(math.max(30,width-90))
        end
        for _,row in ipairs(critRows) do
            row:SetWidth(width-16);row:SetHeight(db.font+7);row.label:SetFont(FONT,db.font);row.value:SetFont(FONT,db.font);row.label:SetWidth(math.max(30,width-90))
        end
        critHeading:SetFont(FONT,db.font,"OUTLINE")
    end
    C.AnchorRunPosition(p)
    if Collapsed() then
        if scroll:IsShown() then scroll:Hide() end
        if reset:IsShown() then reset:Hide() end
    elseif not scroll:IsShown() then scroll:Show() end
    if nfUIDB.runPanel==false then panel:Hide() elseif not panel:IsShown() then panel:Show() end
    local center=p.x+(p.runAnchor=="TOPRIGHT" and -width*db.scale/2 or width*db.scale/2);local right=center>UIParent:GetWidth()/2
    local arrow=Collapsed() and (right and "<" or ">") or (right and ">" or "<")
    if collapse.arrow~=arrow then collapse:SetText(arrow);collapse.arrow=arrow end
end
function C.SetRunCollapsed(value)
    Position();nfUIDB.runCollapsed=value;C.LayoutRunPanel()
end
function C.NormalizeRunAnchor()
    local p=Position();local scale=C.Settings().runDisplay.scale
    local center=p.x+(p.runAnchor=="TOPRIGHT" and -panel:GetWidth()*scale/2 or panel:GetWidth()*scale/2)
    local anchor=center>UIParent:GetWidth()/2 and "TOPRIGHT" or "TOPLEFT"
    if p.runAnchor~=anchor then p.x=p.x+(anchor=="TOPRIGHT" and panel:GetWidth()*scale or -panel:GetWidth()*scale);p.runAnchor=anchor end
end
function C.IsRunDragging() return drag~=nil end
function C.BeginRunDrag() local x,y=GetCursorPosition();drag={x=x,y=y,position=C.CaptureRunPosition()} end
function C.EndRunDrag() drag=nil;C.NormalizeRunAnchor();C.LayoutRunPanel() end
header:SetScript("OnDragStart",function() if IsAltKeyDown() then C.BeginRunDrag() end end)
header:SetScript("OnDragStop",C.EndRunDrag);header:SetScript("OnMouseUp",C.EndRunDrag)
local function SetText(row,text) text=tostring(text);if row.last~=text then row.value:SetText(text);row.last=text end end
function C.RefreshRunPanel()
    C.LayoutRunPanel();local phase=Phase();local seconds=Seconds()
    local label=(phase=="paused" or phase=="choosing" or (not phase and model.pausedAt)) and "Survived (paused)" or "Survived"
    if rows.time.caption~=label then rows.time.label:SetText(label);rows.time.caption=label end
    SetText(rows.time,string.format("%d:%02d",math.floor(seconds/60),math.mod(math.floor(seconds),60)))
    SetText(rows.level,UnitLevel("player") or "-");SetText(rows.kills,Native("kills",model.kills))
    local elite=Native("ek",nil);if elite then elite=elite+Native("gk",0) end
    SetText(rows.elites,Short(elite));SetText(rows.bosses,Short(Native("bk",nil)))
    local dealt=Native("dealt",model.dealt)
    if type(AZS_GetMeter)=="function" and phase then local _,total=AZS_GetMeter();if Number(total) then dealt=total end end
    SetText(rows.dealt,Short(dealt));SetText(rows.dps,Short(seconds>0 and dealt/seconds or 0));SetText(rows.taken,Short(Native("taken",model.taken)))
    if Collapsed() then return end
    local y=0;local line=C.Settings().runDisplay.font+7
    for _,d in ipairs(descriptions) do local row=rows[d[1]];if row.y~=y then row:ClearAllPoints();row:SetPoint("TOPLEFT",content,"TOPLEFT",0,-y);row.y=y end;y=y+line end
    local sorted={};for name in pairs(model.crit) do table.insert(sorted,name) end
    table.sort(sorted,function(a,b) return model.crit[a].best>model.crit[b].best end)
    if table.getn(sorted)>0 then
        if critHeading.y~=y then
            critHeading:ClearAllPoints();critHeading:SetPoint("TOPLEFT",content,"TOPLEFT",0,-y-8)
            reset:ClearAllPoints();reset:SetPoint("TOPRIGHT",content,"TOPRIGHT",0,-y-4);critHeading.y=y
        end
        if not critHeading:IsShown() then critHeading:Show() end
        if not reset:IsShown() then reset:Show() end;y=y+line+16
    else critHeading:Hide();reset:Hide() end
    for i,row in ipairs(critRows) do
        local name=sorted[i]
        if name then
            if row.ability~=name then row.ability=name;row.label:SetText(name) end
            SetText(row,Short(model.crit[name].best))
            if row.y~=y then row:ClearAllPoints();row:SetPoint("TOPLEFT",content,"TOPLEFT",0,-y);row.y=y end
            if not row:IsShown() then row:Show() end;y=y+line
        elseif row:IsShown() then row:Hide() end
    end
    if content:GetHeight()~=y then content:SetHeight(y) end
    local maximum=math.max(0,y-scroll:GetHeight());offset=math.min(offset,maximum);scroll:SetVerticalScroll(offset)
end
collapse:SetScript("OnClick",function() C.SetRunCollapsed(not Collapsed());C.RefreshRunPanel() end)
function nfUI_ToggleRun() nfUIDB.runPanel=nfUIDB.runPanel==false;C.RefreshRunPanel() end
function nfUI_ResetRun() model.crit={};model.hits={};C.RefreshRunPanel() end
reset:SetScript("OnClick",nfUI_ResetRun)
local outgoing={CHAT_MSG_COMBAT_SELF_HITS=true,CHAT_MSG_SPELL_SELF_DAMAGE=true,CHAT_MSG_COMBAT_PET_HITS=true,CHAT_MSG_SPELL_PET_DAMAGE=true,CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE=true,CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF=true}
local incoming={CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS=true,CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE=true,CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE=true}
local events=CreateFrame("Frame","nfUIRunEvents",UIParent)
for name in pairs(outgoing) do events:RegisterEvent(name) end
for name in pairs(incoming) do events:RegisterEvent(name) end
events:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH");events:RegisterEvent("CHAT_MSG_SYSTEM")
events:SetScript("OnEvent",function()
    local message=arg1 or ""
    if event=="CHAT_MSG_SYSTEM" then
        if string.find(message,"Move to begin",1,true) then ResetModel();previousTime=nil
        elseif string.find(message,"talent experience",1,true) and model.started then model.ended=GetTime() end
    elseif outgoing[event] then
        local parser=nfUIModules and nfUIModules.tools.ParseNameplateCombatEvent;local info=parser and parser(event,message)
        if info and info.kind=="damage" and Number(info.amount) then
            Alive();model.dealt=model.dealt+info.amount
            local name=info.spell or info.ability or info.sourceName or "Melee";local collection=info.critical and model.crit or model.hits
            local value=collection[name] or {best=0,total=0,count=0,least=info.amount}
            value.last=info.amount;value.best=math.max(value.best,info.amount);value.least=math.min(value.least,info.amount)
            value.total=value.total+info.amount;value.count=value.count+1;collection[name]=value
        end
    elseif incoming[event] then
        local _,_,amount=string.find(message," you for (%d+)");if not amount then _,_,amount=string.find(message,"^You suffer (%d+)") end
        if amount then Alive();model.taken=model.taken+tonumber(amount) end
    elseif event=="CHAT_MSG_COMBAT_HOSTILE_DEATH" then model.kills=model.kills+1 end
end)
local age=0
panel:SetScript("OnUpdate",function()
    if drag then
        local x,y=GetCursorPosition();local rootScale=UIParent:GetEffectiveScale()
        C.AnchorRunPosition({x=drag.position.x+(x-drag.x)/rootScale,y=drag.position.y+(y-drag.y)/rootScale,runAnchor=drag.position.runAnchor})
    end
    age=age+(arg1 or 0);if age<0.25 then return end;age=0
    if Phase() and type(AZS_GetRunTime)=="function" then
        local time=AZS_GetRunTime();if Number(time) then if previousTime and time<previousTime then ResetModel() end;previousTime=time end
    elseif model.started and not model.ended then
        local x,y=GetPlayerMapPosition("player")
        if Number(x) and Number(y) and (x~=0 or y~=0) then
            if model.x and (x~=model.x or y~=model.y) then Alive() end;model.x=x;model.y=y
        end
        if not model.pausedAt and GetTime()-(model.lastAction or model.started)>1.5 then model.pausedAt=model.lastAction or model.started end
    end
    C.RefreshRunPanel()
end)
C.runFrame=panel
