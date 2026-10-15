-- Independent screen-space anchors; native button parents remain unchanged.
local C=nfUIConfig
local FLAT="Interface\\ChatFrame\\ChatFrameBackground"
local FONT="Fonts\\FRIZQT__.TTF"
local registry={}
local handles={}
local unlocked=false
local details=false
local active
local toolbar
local dirty=0
local grid
local gridLines={}
local function GridSettings()
    local db=C.Settings()
    if type(db.moverGrid)~="table" then db.moverGrid={enabled=true,size=16} end
    db.moverGrid.size=math.max(4,math.min(128,tonumber(db.moverGrid.size) or 16))
    return db.moverGrid
end
local function RefreshGrid()
    if not grid then
        grid=CreateFrame("Frame","nfUIMoverGrid",UIParent)
        grid:SetAllPoints(UIParent);grid:SetFrameStrata("BACKGROUND");grid:EnableMouse(false)
        C.moverGrid=grid
    end
    local settings=GridSettings()
    if not unlocked or not settings.enabled then grid:Hide();return end
    grid:Show()
    local width,height=UIParent:GetWidth(),UIParent:GetHeight()
    local key=width..":"..height..":"..settings.size
    if grid.layoutKey==key then return end
    grid.layoutKey=key
    for _,line in ipairs(gridLines) do line:Hide() end
    local count=0
    local function Line(vertical,offset,center)
        count=count+1
        local line=gridLines[count]
        if not line then line=grid:CreateTexture(nil,"BACKGROUND");gridLines[count]=line end
        line:ClearAllPoints();line:SetTexture(FLAT)
        line:SetVertexColor(center and 0.3 or 0.5,0.7,1,center and 0.6 or 0.12)
        line:SetWidth(vertical and 1 or width);line:SetHeight(vertical and height or 1)
        line:SetPoint("CENTER",grid,"CENTER",vertical and offset or 0,vertical and 0 or offset);line:Show()
    end
    for x=0,width/2,settings.size do Line(true,x,x==0);if x>0 then Line(true,-x,false) end end
    for y=0,height/2,settings.size do Line(false,y,y==0);if y>0 then Line(false,-y,false) end end
end
function C.SnapMoverPosition(position)
    local settings=GridSettings()
    if not unlocked or not settings.enabled or (IsShiftKeyDown and IsShiftKeyDown()) then return position end
    local ox,oy=0,0
    if position.centered then
        ox=UIParent:GetWidth()/2
        oy=C.Settings().compassStyle.anchor=="TOP" and UIParent:GetHeight() or 0
    end
    local step=settings.size
    position.x=math.floor((position.x+ox-UIParent:GetWidth()/2)/step+0.5)*step+UIParent:GetWidth()/2-ox
    position.y=math.floor((position.y+oy-UIParent:GetHeight()/2)/step+0.5)*step+UIParent:GetHeight()/2-oy
    return position
end
local function Positions()
    local db=C.Settings()
    if type(db.positions)~="table" then db.positions={} end
    return db.positions
end
local function Add(key,label,object,category,detail,extra)
    if not object then return end
    local entry={key=key,label=label,object=object,category=category,detail=detail,extra=extra,originalPoints={}}
    if object.GetPoint then
        local count=object.GetNumPoints and object:GetNumPoints() or 1
        for i=1,count do
            local ok,point,relative,rp,x,y=pcall(object.GetPoint,object,i)
            if ok and point then
                table.insert(entry.originalPoints,{point=point,relative=relative,rp=rp,x=x,y=y})
            end
        end
    end
    table.insert(registry,entry)
    return entry
end
local function Group(name,parent)
    local group=CreateFrame("Frame",name,parent)
    group:SetWidth(1); group:SetHeight(1)
    return group
end
local auraGroup=Group("nfUIPlayerAuras",C.player)
local debuffGroup=Group("nfUITargetDebuffs",C.target)
Add("actionBar","Action bar",C.row,"action")
Add("player","Player",C.player,"player")
Add("target","Target",C.target,"target")
Add("playerAuras","Player auras",auraGroup,"auras")
Add("targetDebuffs","Target debuffs",debuffGroup,"debuffs")
Add("xp","Experience bar",getglobal("MainMenuExpBar"),"xp")
Add("minimap","Minimap",Minimap,"minimap")
Add("compass","Compass",nfUIConfig.compassFrame,"compassStyle")
Add("runPanel","Run statistics",getglobal("nfUIRun"),"runDisplay")
Add("characterStats","Character stats",C.statsFrame,"statsDisplay")
for i=1,7 do
    Add("chat"..i,"Chat "..i,getglobal("ChatFrame"..i),"chat")
    Add("chatTab"..i,"Chat tab "..i,getglobal("ChatFrame"..i.."Tab"),"chat",true)
end
Add("chatInput","Chat input",ChatFrameEditBox,"chat")
for _,name in ipairs(C.microButtons) do Add(name,name,getglobal(name),"micro") end
for _,unit in ipairs({"player","target"}) do
    local frame=C[unit]
    Add(unit.."Portrait",unit.." portrait",frame.portrait,unit,true)
    Add(unit.."Health",unit.." health bar",frame.health,unit,true)
    Add(unit.."Power",unit.." power bar",frame.power,unit,true)
    Add(unit.."Name",unit.." name",frame.name,unit,true)
    Add(unit.."Value",unit.." health text",frame.value,unit,true)
    Add(unit.."Shield",unit.." shield bar",frame.shield,unit,true)
    Add(unit.."ShieldText",unit.." shield text",frame.shieldText,unit,true)
end
for i,slot in ipairs(C.slots) do
    local id=C.buttonIDs[i]
    Add("action"..id,"Action "..(id==12 and "=" or id),slot,"action",true,function(object)
        for _,prefix in ipairs({"ActionButton","BonusActionButton"}) do
            local button=getglobal(prefix..id)
            if button then
                button:ClearAllPoints(); button:SetPoint("CENTER",object,"CENTER",0,0)
                button:SetWidth(object:GetWidth()); button:SetHeight(object:GetHeight())
                button:SetScale(object:GetEffectiveScale()/button:GetParent():GetEffectiveScale())
                local cooldown=getglobal(prefix..id.."Cooldown")
                if cooldown then cooldown:SetWidth(object:GetWidth()); cooldown:SetHeight(object:GetHeight()) end
            end
        end
    end)
end
for _,id in ipairs(C.buttonIDs) do
    for _,prefix in ipairs({"ActionButton","BonusActionButton"}) do
        Add(prefix..id.."Key","Action "..id.." keybind",getglobal(prefix..id.."HotKey"),"action",true)
        Add(prefix..id.."Count","Action "..id.." item count",getglobal(prefix..id.."Count"),"action",true)
    end
end
Add("xpText","Experience text",getglobal("MainMenuExpBarText"),"xp",true)
for i,aura in ipairs(C.auras) do
    Add("aura"..i,"Player aura "..i,aura,"auras",true)
    Add("auraTime"..i,"Aura "..i.." timer",aura.time,"auras",true)
    Add("auraCount"..i,"Aura "..i.." stacks",aura.count,"auras",true)
end
for i,icon in ipairs(C.debuffs) do
    Add("debuff"..i,"Target debuff "..i,icon,"debuffs",true)
    Add("debuffCount"..i,"Debuff "..i.." stacks",icon.count,"debuffs",true)
end

local function Capture(object)
    if object==C.dpsFrame and C.CaptureDPSPosition then return C.CaptureDPSPosition() end
    if object==C.runFrame and C.CaptureRunPosition then return C.CaptureRunPosition() end
    local left,bottom=object:GetLeft(),object:GetBottom()
    if not left or not bottom then return nil end
    local ratio=object:GetEffectiveScale()/UIParent:GetEffectiveScale()
    if object==C.compassFrame then
        local top=C.Settings().compassStyle.anchor=="TOP"
        return {x=(left+object:GetWidth()/2)*ratio-UIParent:GetWidth()/2,
            y=(bottom+(top and object:GetHeight() or 0))*ratio-(top and UIParent:GetHeight() or 0),centered=true}
    end
    return {x=left*ratio,y=bottom*ratio}
end
local function Anchor(object,position)
    if object==C.dpsFrame and C.AnchorDPSPosition and position then C.AnchorDPSPosition(position);return end
    if object==C.runFrame and C.AnchorRunPosition then C.AnchorRunPosition(position);return end
    if not position or type(position.x)~="number" or type(position.y)~="number" then return end
    local ratio=object:GetEffectiveScale()/UIParent:GetEffectiveScale()
    if ratio<=0 then return end
    object:ClearAllPoints()
    if object==C.compassFrame and position.centered then
        local anchor=C.Settings().compassStyle.anchor
        object:SetPoint(anchor,UIParent,anchor,position.x/ratio,position.y/ratio)
    else object:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",position.x/ratio,position.y/ratio) end
end
local function GroupLayout()
    local db=C.Settings()
    auraGroup:SetWidth(table.getn(C.auras)*(db.auras.size+db.auras.gap)-db.auras.gap)
    auraGroup:SetHeight(db.auras.size)
    if not Positions().playerAuras then
        auraGroup:ClearAllPoints(); auraGroup:SetPoint("BOTTOMLEFT",C.player,"TOPLEFT",0,5)
    end
    for i,aura in ipairs(C.auras) do
        aura:SetParent(auraGroup)
        if not Positions()["aura"..i] then
            aura:ClearAllPoints()
            aura:SetPoint("BOTTOMLEFT",auraGroup,"BOTTOMLEFT",(i-1)*(db.auras.size+db.auras.gap),0)
        end
    end
    debuffGroup:SetWidth(table.getn(C.debuffs)*(db.debuffs.size+db.debuffs.gap)-db.debuffs.gap)
    debuffGroup:SetHeight(db.debuffs.size)
    if not Positions().targetDebuffs then
        debuffGroup:ClearAllPoints(); debuffGroup:SetPoint("BOTTOMLEFT",C.target,"TOPLEFT",0,4)
    end
    for i,icon in ipairs(C.debuffs) do
        icon:SetParent(debuffGroup)
        if not Positions()["debuff"..i] then
            icon:ClearAllPoints()
            icon:SetPoint("BOTTOMLEFT",debuffGroup,"BOTTOMLEFT",(i-1)*(db.debuffs.size+db.debuffs.gap),0)
        end
    end
end
function C.ApplyPositions()
    GroupLayout()
    -- Parents first, then smaller elements, so scale conversions are stable.
    local positions=Positions()
    for _,entry in ipairs(registry) do
        if entry.object==C.runFrame and C.LayoutRunPanel then
            if (not active or active.entry~=entry) and not C.IsRunDragging() then C.LayoutRunPanel() end
        else
            if C.ApplyElementSizes then C.ApplyElementSizes(entry) end
            if not active or active.entry~=entry then Anchor(entry.object,positions[entry.key]) end
        end
        if entry.extra then entry.extra(entry.object) end
    end
      if C.ApplySizeMatches then C.ApplySizeMatches() end
end
local function SnapshotMajors()
    -- Freeze all major components before moving any one of them.
    local positions=Positions()
    for _,entry in ipairs(registry) do
        if not entry.detail and not positions[entry.key] then
            local position=Capture(entry.object)
            if position then positions[entry.key]=position end
        end
    end
    C.ApplyPositions()
end
C.FreezePositions=SnapshotMajors
function C.SaveElement(object)
    SnapshotMajors()
    for _,entry in ipairs(registry) do
        if entry.object==object then
            local position=Capture(object)
            if position then Positions()[entry.key]=position end
        end
    end
    C.ApplyPositions()
end
function C.ClearPositions(category)
    local positions=Positions()
    for _,entry in ipairs(registry) do
        if not category or category==entry.category then
            if positions[entry.key] and table.getn(entry.originalPoints)>0 then
                entry.object:ClearAllPoints()
                for _,point in ipairs(entry.originalPoints) do
                    entry.object:SetPoint(point.point,point.relative,point.rp,point.x,point.y)
                end
            end
            positions[entry.key]=nil
        end
    end
end

local function Bounds(object)
    local left,bottom=object:GetLeft(),object:GetBottom()
    if not left or not bottom then return nil end
    local ratio=object:GetEffectiveScale()/UIParent:GetEffectiveScale()
    return left*ratio,bottom*ratio,object:GetWidth()*ratio,object:GetHeight()*ratio
end
local function Finish()
    if not active then return end
    local entry=active.entry
    local position=Capture(entry.object)
    if position then Positions()[entry.key]=position end
    active=nil
    if entry.object==C.runFrame and C.EndRunDrag then C.EndRunDrag() end
    C.ApplyPositions()
end
local function ShowHandles()
    -- Handles are built lazily when mover mode is first opened.
    if not toolbar then return end
    for _,entry in ipairs(registry) do
        local handle=handles[entry.key]
        if handle then
            local visible=unlocked and (details==entry.detail or (not details and not entry.detail))
            -- Separate layers keep nested handles reachable.
            if entry.object.IsVisible and not entry.object:IsVisible() then visible=false end
            if visible then
                local x,y,w,h=Bounds(entry.object)
                if x then
                    handle:ClearAllPoints()
                    handle:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",x,y)
                    handle:SetWidth(math.max(w,20)); handle:SetHeight(math.max(h,16))
                    handle:Show()
                else handle:Hide() end
            else handle:Hide() end
        end
    end
end
local function Button(name,text,x,width,callback)
    local button=CreateFrame("Button",name,toolbar,"UIPanelButtonTemplate")
    button:SetWidth(width); button:SetHeight(26)
    button:SetPoint("TOPLEFT",toolbar,"TOPLEFT",x,-49)
    button:SetText(text); button:SetScript("OnClick",callback)
    return button
end
local function CreateHandle(entry,i)
        local item=entry
        local handle=CreateFrame("Frame","nfUIMover"..i,UIParent)
        handles[item.key]=handle
        handle:Hide(); handle:SetFrameStrata("FULLSCREEN"); handle:SetFrameLevel(50)
        handle:EnableMouse(true)
        handle:SetBackdrop({bgFile=FLAT,edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
            tile=true,tileSize=16,edgeSize=8,insets={left=1,right=1,top=1,bottom=1}})
        handle:SetBackdropColor(0.05,0.4,0.6,0.3)
        handle:SetBackdropBorderColor(0.25,0.8,1,0.9)
        local caption=handle:CreateFontString(nil,"OVERLAY")
        caption:SetFont(FONT,10,"OUTLINE"); caption:SetPoint("CENTER",handle,"CENTER",0,0)
        caption:SetText(item.label)
        handle:SetScript("OnMouseDown",function()
            if arg1=="RightButton" then
                Finish(); SnapshotMajors()
                if C.ShowMoverMenu then C.ShowMoverMenu(item) elseif C.ShowFineAdjustments then C.ShowFineAdjustments(item) end
                return
            end
            if C.SelectSizeMatch and C.SelectSizeMatch(item) then ShowHandles();return end
            if C.CancelSizeMatch then C.CancelSizeMatch() end
            SnapshotMajors()
            local position=Capture(item.object)
            if not position then return end
            local x,y=GetCursorPosition()
            active={entry=item,x=x,y=y,position=position}
        end)
        handle:SetScript("OnMouseUp",Finish)
end
local function Build()
    if toolbar then return end
    toolbar=CreateFrame("Frame","nfUIMoverTools",UIParent)
    toolbar:Hide(); toolbar:SetWidth(490); toolbar:SetHeight(122)
    toolbar:SetPoint("TOP",UIParent,"TOP",0,-80)
    toolbar:SetFrameStrata("FULLSCREEN_DIALOG"); toolbar:EnableMouse(true)
    toolbar:SetBackdrop({bgFile=FLAT,edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true,tileSize=16,edgeSize=12,insets={left=2,right=2,top=2,bottom=2}})
    toolbar:SetBackdropColor(0.04,0.07,0.1,0.98)
    local title=toolbar:CreateFontString(nil,"OVERLAY")
    title:SetFont(FONT,14); title:SetPoint("TOPLEFT",toolbar,"TOPLEFT",12,-10)
    title:SetText("nfUI movers")
    local hint=toolbar:CreateFontString(nil,"OVERLAY")
    hint:SetFont(FONT,11); hint:SetPoint("TOPLEFT",toolbar,"TOPLEFT",12,-29)
    hint:SetText("Drag to move. Right-click for sliders. Details shows smaller parts.")
    local detailButton
    detailButton=Button("nfUIMoversDetails","Details",12,100,function()
        Finish(); details=not details
        detailButton:SetText(details and "Main elements" or "Details")
        ShowHandles()
    end)
    Button("nfUIMoversReset","Reset positions",120,130,function()
        Finish(); C.ClearPositions(); C.Apply()
        -- Wait for a layout tick before freezing the restored default positions.
        dirty=-0.4
    end)
    Button("nfUIMoversSettings","Settings",258,100,function()
        C.ToggleMovers(false); C.Toggle()
    end)
    Button("nfUIMoversDone","Done",366,110,function() C.ToggleMovers(false) end)
    local snap=CreateFrame("CheckButton","nfUIMoversSnap",toolbar,"UICheckButtonTemplate")
    snap:SetWidth(24);snap:SetHeight(24);snap:SetPoint("TOPLEFT",toolbar,"TOPLEFT",12,-86)
    snap:SetChecked(GridSettings().enabled)
    snap:SetScript("OnClick",function() GridSettings().enabled=snap:GetChecked() and true or false;RefreshGrid() end)
    local label=toolbar:CreateFontString(nil,"OVERLAY");label:SetFont(FONT,11)
    label:SetPoint("LEFT",snap,"RIGHT",4,0);label:SetText("Snap grid   Size:")
    local input=C.CreateNumberInput("nfUIMoversGridSize",toolbar,48,22,{
        get=function() return GridSettings().size end,percent=function() return false end,
        range=function() return 4,128,1 end,
        set=function(value) GridSettings().size=value;RefreshGrid() end})
    input:SetPoint("TOPLEFT",toolbar,"TOPLEFT",150,-86);input:RefreshNumber()
    local help=toolbar:CreateFontString(nil,"OVERLAY");help:SetFont(FONT,11)
    help:SetPoint("LEFT",input,"RIGHT",12,0);help:SetText("UI px. Hold Shift for free movement.")
    for i,entry in ipairs(registry) do CreateHandle(entry,i) end
    toolbar:SetScript("OnHide",function()
        Finish(); unlocked=false; C.editing=false
        if C.CancelSizeMatch then C.CancelSizeMatch() end
        RefreshGrid()
        if C.finePanel then C.finePanel:Hide() end
        for _,handle in pairs(handles) do handle:Hide() end
    end)
    table.insert(UISpecialFrames,"nfUIMoverTools")
    C.moverTools=toolbar
end
function C.ToggleMovers(want)
    Build()
    if want==nil then want=not unlocked end
    if not want then toolbar:Hide(); return end
    if C.panel and C.panel:IsShown() then C.panel:Hide() end
    unlocked=true; C.editing=true
    C.target:Show()
    C.Apply()
    SnapshotMajors()
    toolbar:Show(); ShowHandles();RefreshGrid()
end
local originalCommand=SlashCmdList["NFUI"]
SlashCmdList["NFUI"]=function(message)
    local text=string.lower(message or "")
    if text=="move" or text=="movers" then C.ToggleMovers()
    else C.ToggleMovers(false); originalCommand() end
end
local driver=CreateFrame("Frame","nfUIMoverUpdater",UIParent)
driver:SetScript("OnUpdate",function()
    if active then
        local x,y=GetCursorPosition()
        local scale=UIParent:GetEffectiveScale()
        Anchor(active.entry.object,C.SnapMoverPosition({
            centered=active.position.centered,
            runAnchor=active.position.runAnchor,
            x=active.position.x+(x-active.x)/scale,
            y=active.position.y+(y-active.y)/scale}))
        if active.entry.extra then active.entry.extra(active.entry.object) end
        ShowHandles()
    end
    dirty=dirty+(arg1 or 0)
    if dirty<0.2 then return end
    dirty=0
    if unlocked then RefreshGrid() end
    if toolbar then
        for _,id in ipairs(C.buttonIDs) do
            for _,prefix in ipairs({"ActionButton","BonusActionButton"}) do
                local button=getglobal(prefix..id)
                local key=prefix..id.."CooldownText"
                if button and button.nfuiCounter and not handles[key] then
                    local entry=Add(key,"Action "..id.." cooldown",button.nfuiCounter.text,"action",true)
                    if entry then CreateHandle(entry,table.getn(registry)) end
                end
            end
        end
    end
    if unlocked then SnapshotMajors() else C.ApplyPositions() end
    ShowHandles()
end)
C.moverRegistry=registry
C.moverHandles=handles


function C.RegisterMover(key,label,object,category)
    local entry=Add(key,label,object,category)
    if entry and toolbar then CreateHandle(entry,table.getn(registry)) end
    return entry
end
