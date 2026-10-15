-- Small, pooled damage labels share the localized parser with icon combat text.
local C,W=nfUIConfig,nfUIWidgets
local layer=CreateFrame("Frame","nfUIDamage",UIParent)
layer:SetAllPoints(UIParent);layer:SetFrameStrata("HIGH")
local pool={}
local events={"CHAT_MSG_COMBAT_SELF_HITS","CHAT_MSG_SPELL_SELF_DAMAGE","CHAT_MSG_COMBAT_PET_HITS","CHAT_MSG_SPELL_PET_DAMAGE","CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE","COMBAT_TEXT_UPDATE"}
local incoming={DAMAGE=true,DAMAGE_CRIT=true,SPELL_DAMAGE=true}
local function Origin(name)
    if name then
        for _,entry in ipairs(nfUIPlatesRegistry or {}) do
            if entry.plate:IsVisible() and entry.stock.name:GetText()==name then
                local region=entry.bar
                local x,y=region:GetCenter()
                if x and y then local factor=C.RegionEffectiveScale(region)/UIParent:GetEffectiveScale();return x*factor,y*factor end
            end
        end
    end
    return UIParent:GetWidth()/2,UIParent:GetHeight()/2+(name and 30 or -15)
end
local function Emit(amount,name,critical,periodic)
    local state
    for _,entry in ipairs(pool) do if not entry.active then state=entry;break end end
    if not state then
        if table.getn(pool)>=48 then return end
        state={label=layer:CreateFontString(nil,"OVERLAY")};table.insert(pool,state)
    end
    local x,y=Origin(name)
    state.active=true;state.settled=nil;state.born=GetTime();state.life=critical and 0.715 or 0.55
    state.x=x+(math.random()-0.5)*24;state.y=y;state.drift=(math.random()-0.5)*30
    state.rise=(name and 1 or -1)*(critical and 80.6 or 62);state.critical=critical
    local color=not name and {1,0.22,0.22} or critical and {1,0.76,0.08} or periodic and {0.8,0.8,0.8} or {1,1,1}
    local label=state.label;label:SetText((name and "" or "-")..tostring(amount))
    label:SetFont(W.font,critical and 30 or periodic and 12 or 14,critical and "THICKOUTLINE" or "OUTLINE")
    label:SetTextColor(unpack(color));label:SetAlpha(1);label:Show()
end
layer:SetScript("OnUpdate",function()
    local now=GetTime()
    for _,state in ipairs(pool) do if state.active then
        local elapsed=now-state.born;local t=elapsed/state.life
        if t>=1 then state.active=false;state.label:Hide()
        else
            local ease=t*(2-t)
            if state.critical and elapsed>=0.09 and not state.settled then state.label:SetFont(W.font,22,"THICKOUTLINE");state.settled=true end
            state.label:ClearAllPoints();state.label:SetPoint("CENTER",UIParent,"BOTTOMLEFT",state.x+state.drift*ease,state.y+state.rise*ease)
            state.label:SetAlpha(math.min(1,(1-t)/0.34))
        end
    end end
end)
local reader=CreateFrame("Frame","nfUIQuickTextEvents",UIParent)
reader:SetScript("OnEvent",function()
    if event=="COMBAT_TEXT_UPDATE" then
        if incoming[arg1] and tonumber(arg2) then Emit(arg2,nil,arg1=="DAMAGE_CRIT") end
    else
        local parser=nfUIModules.tools.ParseNameplateCombatEvent
        local hit=parser and parser(event,arg1 or "")
        if hit and hit.kind=="damage" and hit.targetName and hit.targetName~="" then Emit(hit.amount,hit.targetName,hit.critical,hit.damageType=="periodic") end
    end
end)
function C.ApplyQuickText()
    local db=C.Settings();local on=db.damageText and db.damageMode~="default" and db.damageMode~="off"
    for _,name in ipairs(events) do
        if on and (db.damageMode=="quick" or name=="COMBAT_TEXT_UPDATE") then reader:RegisterEvent(name) else reader:UnregisterEvent(name) end
    end
    SetCVar("CombatDamage",db.damageMode=="default" and "1" or "0")
    for name in pairs(incoming) do if COMBAT_TEXT_TYPE_INFO and COMBAT_TEXT_TYPE_INFO[name] then COMBAT_TEXT_TYPE_INFO[name].show=not on and 1 or nil end end
    if not on then for _,state in ipairs(pool) do state.active=false;state.label:Hide() end end
end
local loader=CreateFrame("Frame",nil,UIParent)
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent",function() if arg1=="Blizzard_CombatText" then C.ApplyQuickText() end end)
