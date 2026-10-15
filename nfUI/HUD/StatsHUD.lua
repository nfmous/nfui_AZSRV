-- Persistent character stats use the same native values and sections as the character pane.
local C=nfUIConfig
local sections=C.CharacterStatSections or {}
local FONT="Fonts\\FRIZQT__.TTF"
C.defaults.statsDisplay={width=210,height=340,scale=1,font=11,valueFont=11,headingFont=12,backdrop=true,headings=true}
function C.StatSettingKey(source) return "stat_"..source[1] end
for _,section in ipairs(sections) do
    for _,source in ipairs(section.rows) do
        C.defaults.statsDisplay[C.StatSettingKey(source)]=source[1]~="Health" and source[1]~="Lives"
    end
end
local range=C.Range
C.Range=function(category,key)
    if category=="statsDisplay" then
        if key=="width" then return 160,600,1 end
        if key=="height" then return 100,UIParent:GetHeight(),1 end
        if key=="headingFont" or key=="valueFont" or key=="font" then return 6,40,1 end
    end
    return range(category,key)
end
local panel=CreateFrame("Frame","nfUIStats",UIParent)
panel:SetWidth(210);panel:SetHeight(340);panel:SetPoint("TOPRIGHT",UIParent,"TOPRIGHT",-16,-260)
panel:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"});panel:SetBackdropColor(0.04,0.04,0.07,0.88)
local title=panel:CreateFontString(nil,"OVERLAY");title:SetFont(FONT,12,"OUTLINE")
title:SetText("Character Stats");title:SetTextColor(1,0.82,0);title:SetPoint("TOPLEFT",panel,"TOPLEFT",8,-8)
local scroll=CreateFrame("ScrollFrame","nfUIStatsScroll",panel)
scroll:SetPoint("TOPLEFT",panel,"TOPLEFT",8,-30);scroll:SetPoint("BOTTOMRIGHT",panel,"BOTTOMRIGHT",-8,8)
scroll:EnableMouseWheel(true)
local content=CreateFrame("Frame",nil,scroll);content:SetWidth(194);content:SetHeight(1);scroll:SetScrollChild(content)
local offset=0
scroll:SetScript("OnMouseWheel",function()
    offset=math.max(0,math.min(math.max(0,content:GetHeight()-scroll:GetHeight()),offset-(arg1 or 0)*30))
    scroll:SetVerticalScroll(offset)
end)
local entries={}
for _,section in ipairs(sections) do
    local header=content:CreateFontString(nil,"OVERLAY");header:SetFont(FONT,11,"OUTLINE")
    header:SetText(section.title);header:SetTextColor(section.color[1],section.color[2],section.color[3])
    local group={header=header}
    table.insert(entries,group)
    for _,source in ipairs(section.rows) do
        local row=CreateFrame("Frame",nil,content);row:SetWidth(194);row:SetHeight(15)
        local label=row:CreateFontString(nil,"OVERLAY");label:SetPoint("LEFT",row,"LEFT",0,0);label:SetText(source[1]);label:SetTextColor(0.82,0.82,0.82)
        local value=row:CreateFontString(nil,"OVERLAY");value:SetPoint("RIGHT",row,"RIGHT",0,0);value:SetTextColor(1,1,1)
        table.insert(entries,{row=row,label=label,value=value,source=source,group=group})
    end
end
local function Update()
    local db=C.Settings().statsDisplay
    local stats=type(AZS_STATS)=="table" and AZS_STATS or {}
    for _,entry in ipairs(entries) do
        if entry.header then entry.visible=false
        else
            entry.text=db[C.StatSettingKey(entry.source)] and C.CharacterStatText(entry.source,stats,true) or nil
            if entry.text~=nil then entry.group.visible=true end
        end
    end
    local y=0
    for _,entry in ipairs(entries) do
        if entry.header then
            if entry.visible and db.headings then
                if entry.y~=y then entry.header:ClearAllPoints();entry.header:SetPoint("TOPLEFT",content,"TOPLEFT",0,-y);entry.y=y end
                if not entry.header:IsShown() then entry.header:Show() end
                y=y+db.headingFont+8
            elseif entry.header:IsShown() then entry.header:Hide() end
        elseif entry.text~=nil then
            if entry.last~=entry.text then entry.value:SetText(entry.text);entry.last=entry.text end
            if entry.y~=y then entry.row:ClearAllPoints();entry.row:SetPoint("TOPLEFT",content,"TOPLEFT",0,-y);entry.y=y end
            if not entry.row:IsShown() then entry.row:Show() end
            y=y+math.max(db.font,db.valueFont)+4
        elseif entry.row:IsShown() then entry.row:Hide() end
    end
    if content:GetHeight()~=y then content:SetHeight(y) end
    local maximum=math.max(0,y-scroll:GetHeight())
    if offset>maximum then offset=maximum;scroll:SetVerticalScroll(offset) end
end
function C.LayoutStats()
    local db=C.Settings().statsDisplay
    panel:SetScale(db.scale)
    local width,height=db.width,db.height
    if C.MatchedDimension then width=C.MatchedDimension("characterStats","width",width);height=C.MatchedDimension("characterStats","height",height) end
    panel:SetWidth(width);panel:SetHeight(height)
    panel:SetBackdropColor(0.04,0.04,0.07,db.backdrop and 0.88 or 0)
    title:SetFont(FONT,db.headingFont,"OUTLINE")
    if db.headings then title:Show() else title:Hide() end
    local top=db.headings and db.headingFont+18 or 8
    scroll:ClearAllPoints();scroll:SetPoint("TOPLEFT",panel,"TOPLEFT",8,-top);scroll:SetPoint("BOTTOMRIGHT",panel,"BOTTOMRIGHT",-8,8)
    content:SetWidth(math.max(1,width-16));scroll:SetWidth(math.max(1,width-16));scroll:SetHeight(math.max(1,height-top-8))
    for _,entry in ipairs(entries) do
        if entry.header then entry.header:SetFont(FONT,db.headingFont,"OUTLINE")
        else entry.row:SetWidth(math.max(1,width-16));entry.row:SetHeight(math.max(db.font,db.valueFont)+4);entry.label:SetFont(FONT,db.font);entry.value:SetFont(FONT,db.valueFont) end
        entry.y=nil
    end
    Update()
end
C.statsFrame=panel
C.UpdateStatsHUD=Update
local age=0
panel:SetScript("OnUpdate",function()
    age=age+(arg1 or 0);if age<0.25 then return end;age=0;Update()
end)
