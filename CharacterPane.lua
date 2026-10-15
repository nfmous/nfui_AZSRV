-- Equipment and run modifiers share a compact character-sheet extension.
local C,W=nfUIConfig,nfUIWidgets
if not CharacterFrame or not PaperDollFrame then return end
local view=CreateFrame("Frame","nfUICharacter",PaperDollFrame)
view:SetWidth(546);view:SetHeight(430);view:SetPoint("TOPLEFT",CharacterFrame,"TOPLEFT",11,-11)
view:SetFrameLevel(math.max(0,PaperDollFrame:GetFrameLevel()-1))
W.Fill(view,{0.05,0.05,0.07,0.96});W.Fill(view,{0,0,0,1},"BACKGROUND",-1)
local stats=CreateFrame("Frame","nfUICharacterStats",view)
stats:SetWidth(204);stats:SetHeight(430);stats:SetPoint("TOPRIGHT",view,"TOPRIGHT",0,0)
local heading=W.Label(stats,18,"TOP",0,-14,"-",{0.72,0.45,1})
local caption=W.Label(stats,10,"TOP",0,-38,"Damage bonus",{0.7,0.7,0.7})
local scroll=CreateFrame("ScrollFrame","nfUICharacterScroll",stats)
scroll:SetWidth(180);scroll:SetHeight(368);scroll:SetPoint("TOPLEFT",stats,"TOPLEFT",12,-54)
local list=CreateFrame("Frame",nil,scroll);list:SetWidth(180);list:SetHeight(1);scroll:SetScrollChild(list)
local offset,maximum=0,0
scroll:EnableMouseWheel(true)
scroll:SetScript("OnMouseWheel",function() offset=math.max(0,math.min(maximum,offset-(arg1 or 0)*28));scroll:SetVerticalScroll(offset) end)
local cells={}
for _,section in ipairs(C.CharacterStatSections) do
    local label=W.Label(list,10,"TOPLEFT",0,0,section.title,section.color)
    local group={header=label,rows={}}
    for _,source in ipairs(section.rows) do
        local row=CreateFrame("Frame",nil,list);row:SetWidth(180);row:SetHeight(14);row:EnableMouse(true)
        row.caption=W.Label(row,11,"LEFT",2,0,source[1],{0.82,0.82,0.82})
        row.amount=W.Label(row,11,"RIGHT",-2,0,"",section.color)
        row.source=source
        row:SetScript("OnEnter",function()
            GameTooltip:SetOwner(row,"ANCHOR_RIGHT");GameTooltip:SetText(source[1],1,1,1)
            GameTooltip:AddLine(source[3],1,0.82,0,true);GameTooltip:Show()
        end)
        row:SetScript("OnLeave",function() GameTooltip:Hide() end)
        table.insert(group.rows,row)
    end
    table.insert(cells,group)
end
local equipment={}
local slots={"Head","Neck","Shoulder","Back","Chest","Shirt","Tabard","Wrist","Hands","Waist","Legs","Feet","Finger0","Finger1","Trinket0","Trinket1","MainHand","SecondaryHand","Ranged"}
for _,part in ipairs(slots) do
    local key="Character"..part.."Slot";local slot=getglobal(key)
    if slot then
        local normal=getglobal(key.."NormalTexture");if normal then normal:SetAlpha(0) end
        local icon=getglobal(key.."IconTexture");if icon then icon:SetTexCoord(0.08,0.92,0.08,0.92) end
        local frame=CreateFrame("Frame",nil,view)
        frame:SetPoint("TOPLEFT",slot,"TOPLEFT",-1,1);frame:SetPoint("BOTTOMRIGHT",slot,"BOTTOMRIGHT",1,-1)
        table.insert(equipment,{slot=slot,tint=W.Fill(frame,{0,0,0,1})})
        W.Fill(frame,{0.09,0.09,0.11,1},"BORDER",1)
    end
end
local tabs={}
for index=1,5 do
    local key="CharacterFrameTab"..index;local button=getglobal(key)
    if button then
        for _,suffix in ipairs({"Left","Middle","Right","LeftDisabled","MiddleDisabled","RightDisabled"}) do
            local texture=getglobal(key..suffix);if texture then texture:SetTexture(nil) end
        end
        local highlight=button.GetHighlightTexture and button:GetHighlightTexture();if highlight then highlight:SetTexture(nil) end
        local back=W.Fill(button,{0.03,0.03,0.04,0.85},"BACKGROUND",3)
        local mark=W.Fill(button,{1,0.82,0,1},"BORDER");mark:ClearAllPoints();mark:SetHeight(2)
        mark:SetPoint("BOTTOMLEFT",button,"BOTTOMLEFT",3,6);mark:SetPoint("BOTTOMRIGHT",button,"BOTTOMRIGHT",-3,6)
        local label=getglobal(key.."Text");if label then label:SetFont(W.font,11) end
        table.insert(tabs,{button=button,back=back,mark=mark})
    end
end
local function RefreshTabs()
    local selected=PanelTemplates_GetSelectedTab and PanelTemplates_GetSelectedTab(CharacterFrame)
    for _,tab in ipairs(tabs) do
        local active=tab.button:GetID()==selected
        tab.back:SetVertexColor(active and 0.05 or 0.03,active and 0.05 or 0.03,active and 0.07 or 0.04,0.96)
        if active then tab.mark:Show() else tab.mark:Hide() end
    end
end
local function Refresh()
    W.HideNames({"CharacterAttributesFrame","CharacterResistanceFrame","AZSMoreStats","CharacterFramePortrait"})
    if PaperDollFrame.GetRegions then
        for _,region in ipairs({PaperDollFrame:GetRegions()}) do if region:GetObjectType()=="Texture" then region:Hide() end end
    end
    for _,item in ipairs(equipment) do
        local quality=GetInventoryItemQuality and GetInventoryItemQuality("player",item.slot:GetID())
        local color=quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
        item.tint:SetVertexColor(color and color.r or 0,color and color.g or 0,color and color.b or 0,1)
    end
    local damage=AZS_STATS and AZS_STATS.dmg
    heading:SetText(type(damage)=="number" and string.format("%+.0f%%",(damage-1)*100) or "-")
    caption:SetText(damage and "Damage bonus" or "Start a run to see modifiers")
    local visible,total={},0
    for _,group in ipairs(cells) do
        local values={}
        for _,row in ipairs(group.rows) do
            local value=C.CharacterStatText(row.source,AZS_STATS)
            if value then table.insert(values,{row=row,value=value});total=total+1 else row:Hide() end
        end
        if table.getn(values)>0 then table.insert(visible,{group=group,values=values}) else group.header:Hide() end
    end
    local rowHeight=math.max(9,math.min(14,math.floor((scroll:GetHeight()-table.getn(visible)*20)/math.max(1,total))))
    local size=math.max(8,rowHeight-3);local y=0
    for _,item in ipairs(visible) do
        local header=item.group.header;header:ClearAllPoints();header:SetPoint("TOPLEFT",list,"TOPLEFT",0,-y);header:Show();y=y+20
        for _,data in ipairs(item.values) do
            local row=data.row;row:ClearAllPoints();row:SetPoint("TOPLEFT",list,"TOPLEFT",0,-y);row:SetHeight(rowHeight)
            row.caption:SetFont(W.font,size);row.amount:SetFont(W.font,size);row.amount:SetText(data.value);row:Show();y=y+rowHeight
        end
    end
    list:SetHeight(math.max(1,y));maximum=math.max(0,y-scroll:GetHeight());offset=math.min(offset,maximum);scroll:SetVerticalScroll(offset)
    RefreshTabs()
end
W.HideNames({"CharacterModelFrameRotateLeftButton","CharacterModelFrameRotateRightButton"})
if CharacterModelFrame then
    local model=CharacterModelFrame;local pointer,angle=nil,0;local previous=model:GetScript("OnUpdate")
    model:EnableMouse(true)
    model:SetScript("OnMouseDown",function() pointer=GetCursorPosition() end)
    model:SetScript("OnMouseUp",function() pointer=nil end)
    model:SetScript("OnUpdate",function()
        if previous then previous() end
        if pointer then local x=GetCursorPosition();angle=angle+(x-pointer)*0.01;pointer=x;model:SetRotation(angle) end
    end)
end
local close=CharacterFrameCloseButton
view:SetScript("OnShow",function() Refresh();if close then close:ClearAllPoints();close:SetPoint("TOPRIGHT",view,"TOPRIGHT",4,4) end end)
view:SetScript("OnHide",function()
    if CharacterFramePortrait then CharacterFramePortrait:Show() end
    if close then close:ClearAllPoints();close:SetPoint("CENTER",CharacterFrame,"TOPRIGHT",-44,-25) end
end)
local age=0
view:SetScript("OnUpdate",function() age=age+(arg1 or 0);if age>=0.2 then age=0;Refresh() end end)
local tabDriver=CreateFrame("Frame",nil,CharacterFrame)
local tabAge=0
tabDriver:SetScript("OnUpdate",function() tabAge=tabAge+(arg1 or 0);if tabAge>=0.1 then tabAge=0;RefreshTabs() end end)
C.RefreshCharacterPane=Refresh
