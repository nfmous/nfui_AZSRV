-- Skyrim-style bearing strip. Reads only revealed map landmarks and registered marker providers.
local C=nfUIConfig
local FLAT="Interface\\Buttons\\WHITE8X8"
local FONT="Fonts\\FRIZQT__.TTF"
-- Lua 5.0 has math.mod but no modulo operator; fmod needs positive wrapping.
local function Mod(value,divisor)
    local remainder=math.mod(value,divisor)
    if remainder<0 then remainder=remainder+divisor end
    return remainder
end
local frame=CreateFrame("Frame","nfUICompass",UIParent)
frame:SetWidth(UIParent:GetWidth()); frame:SetHeight(11.5); frame:SetPoint("BOTTOM",UIParent,"BOTTOM",0,12)
frame:SetFrameStrata("MEDIUM")
local back=frame:CreateTexture(nil,"BACKGROUND")
back:SetTexture(FLAT); back:SetAllPoints(frame); back:SetVertexColor(0.03,0.04,0.06,0.72)
local pointer=frame:CreateTexture(nil,"OVERLAY")
pointer:SetTexture(FLAT); pointer:SetVertexColor(1,0.82,0.3,1); pointer:SetWidth(2); pointer:SetHeight(12)
pointer:SetPoint("TOP",frame,"TOP",0,0)
local heading=frame:CreateFontString("nfUICompassHeading","OVERLAY")
heading:SetFont(FONT,11,"OUTLINE"); heading:SetPoint("BOTTOM",frame,"BOTTOM",0,2)
local directions={"N","NE","E","SE","S","SW","W","NW"}
local labels={}
local iconSize=18
for i,name in ipairs(directions) do
    local label=frame:CreateFontString(nil,"OVERLAY"); label:SetFont(FONT,Mod(i,2)==1 and 13 or 10,"OUTLINE")
    label:SetText(name); labels[i]=label
end
local markers,widgets,providers={},{},{}
local scanAge=1
local screenWidth=UIParent:GetWidth()
local needsZone=true
local lastMapOpen=false
local lastFacing,lastX,lastY
local dirty=true
local lastIconOffset
function C.CompassIconOffset()
    local bottom=frame:GetBottom()
    if not bottom then return 0 end
    local ratio=frame:GetEffectiveScale()/UIParent:GetEffectiveScale()
    if ratio<=0 then return 0 end
    local center=(bottom+frame:GetHeight()/2)*ratio
    local half=iconSize*ratio/2
    local low,high=half+2,UIParent:GetHeight()-half-2
    local inside=low>high and UIParent:GetHeight()/2 or math.max(low,math.min(high,center))
    return (inside-center)/ratio
end
local function Number(n) return type(n)=="number" and n==n and n-n==0 end
local function Wrap(degrees) return Mod(degrees+180,360)-180 end
local function Degrees(radians) return Mod(-radians*180/math.pi,360) end
C.CompassDegrees=Degrees
C.CompassDelta=Wrap
function C.RegisterCompassProvider(name,provider)
    assert(type(name)=="string" and type(provider)=="function","provider requires a name and function")
    providers[name]=provider; scanAge=1
end
function C.UnregisterCompassProvider(name) providers[name]=nil; scanAge=1 end
local function Add(marker)
    if type(marker)~="table" or not Number(marker.x) or not Number(marker.y)
        or marker.x<0 or marker.x>1 or marker.y<0 or marker.y>1 then return end
    table.insert(markers,marker)
end
local function Collect()
    markers={}
    if GetNumMapLandmarks and GetMapLandmarkInfo then
        local count=GetNumMapLandmarks() or 0
        for i=1,math.min(count,128) do
            local name,description,index,x,y=GetMapLandmarkInfo(i)
            if name then Add({name=name,description=description,textureIndex=index,x=x,y=y}) end
        end
    end
    local mapFile=GetMapInfo and GetMapInfo()
    for _,provider in pairs(providers) do
        local ok,list=pcall(provider)
        if ok and type(list)=="table" then
            for i=1,math.min(table.getn(list),128) do
                local marker=list[i]
                if type(marker)=="table" and (not marker.mapFile or marker.mapFile==mapFile) then Add(marker) end
            end
        end
    end
    dirty=true
end
local function Facing()
    if GetPlayerFacing then local ok,value=pcall(GetPlayerFacing); if ok and Number(value) then return value end end
    if Minimap and Minimap.GetChildren then
        local arrow=({Minimap:GetChildren()})[9]
        if arrow and arrow.GetFacing then local ok,value=pcall(arrow.GetFacing,arrow); if ok and Number(value) then return value end end
    end
end
local function Widget(i)
    if widgets[i] then return widgets[i] end
    local marker=CreateFrame("Frame","nfUICompassMarker"..i,frame)
    local size=iconSize
    marker:SetWidth(size); marker:SetHeight(size); marker:EnableMouse(true)
    marker.icon=marker:CreateTexture(nil,"ARTWORK"); marker.icon:SetAllPoints(marker)
    marker:SetScript("OnEnter",function()
        GameTooltip:SetOwner(this,"ANCHOR_TOP"); GameTooltip:AddLine(this.marker.name or "Map marker",1,0.82,0.3)
        if this.marker.description then GameTooltip:AddLine(this.marker.description,0.8,0.8,0.8) end
        GameTooltip:Show()
    end)
    marker:SetScript("OnLeave",function() GameTooltip:Hide() end)
    marker:Hide(); widgets[i]=marker; return marker
end
local function Atlas(index)
    if not Number(index) or index<0 or index>=64 then return 0,1,0,1 end
    if WorldMap_GetPOITextureCoords then return WorldMap_GetPOITextureCoords(index) end
    local zero=index; local col=math.mod(zero,8); local row=math.floor(zero/8)
    return col/8,(col+1)/8,row/8,(row+1)/8
end
local function HideMarkers()
    for _,widget in ipairs(widgets) do if widget:IsShown() then widget:Hide() end end
end
local function Draw(facing,x,y,mapOpen)
    local bearing=Degrees(facing)
    local width=frame:GetWidth()
    if frame:GetHeight()>22 then heading:Show() else heading:Hide() end
    heading:SetText(directions[math.mod(math.floor((bearing+22.5)/45),8)+1]..string.format(" %03d",math.mod(math.floor(bearing+0.5),360)))
    for i,label in ipairs(labels) do
        local delta=Wrap((i-1)*45-bearing)
        if math.abs(delta)<=82 then
            local position=delta*width/180
            if label.compassX~=position then
                label:ClearAllPoints(); label:SetPoint("CENTER",frame,"CENTER",position,0); label.compassX=position
            end
            if not label:IsShown() then label:Show() end
        elseif label:IsShown() then label:Hide() end
    end
    if mapOpen or not Number(x) or not Number(y) or (x==0 and y==0) then HideMarkers(); return end
    local aspect=1.5
    local visible={}
    for _,marker in ipairs(markers) do
        local dx,dy=(marker.x-x)*aspect,y-marker.y
        local distance=math.sqrt(dx*dx+dy*dy)
        if distance>0.00001 and distance<=0.35 then
            local target=Mod(math.atan2(dx,dy)*180/math.pi,360)
            local delta=Wrap(target-bearing)
            table.insert(visible,{marker=marker,delta=delta,distance=distance})
        end
    end
    table.sort(visible,function(a,b) return a.distance<b.distance end)
    local used=0; local occupied={}
    for _,entry in ipairs(visible) do
        -- Clamp the icon center inside the rail so out-of-view markers stay at the nearest edge.
        local edge=math.max(0,(width-iconSize)/2)
        local desired=entry.delta*width/180
        local position=math.max(-edge,math.min(edge,desired))
        local pinned=desired~=position
        local side=entry.delta<0 and -1 or 1
        local overlap=false
        local attempts=0
        repeat
            overlap=false
            for _,previous in ipairs(occupied) do
                if math.abs(previous-position)<iconSize+2 then overlap=true; break end
            end
            if overlap and pinned then position=position-side*(iconSize+2); attempts=attempts+1 end
        until not overlap or not pinned or attempts>=12 or math.abs(position)>edge
        if not overlap and math.abs(position)<=edge and used<12 then
            used=used+1; table.insert(occupied,position)
            local widget=Widget(used); widget.marker=entry.marker
            local path=entry.marker.icon or (entry.marker.kind=="cache" and "Interface\\Icons\\INV_Crate_01") or "Interface\\Minimap\\POIIcons"
            if widget.compassPath~=path or widget.compassIndex~=entry.marker.textureIndex then
                widget.icon:SetTexture(path)
                if entry.marker.textureIndex and not entry.marker.icon then widget.icon:SetTexCoord(Atlas(entry.marker.textureIndex))
                else widget.icon:SetTexCoord(0,1,0,1) end
                widget.compassPath=path; widget.compassIndex=entry.marker.textureIndex
            end
            local vertical=C.CompassIconOffset()
            if widget.compassX~=position or widget.compassY~=vertical then
                widget:ClearAllPoints(); widget:SetPoint("CENTER",frame,"CENTER",position,vertical); widget.compassX=position;widget.compassY=vertical
            end
            if not widget:IsShown() then widget:Show() end
        end
    end
    for i=used+1,table.getn(widgets) do if widgets[i]:IsShown() then widgets[i]:Hide() end end
end
function C.UpdateCompass()
    if not nfUIDB.compass then frame:Hide(); HideMarkers(); return end
    if not frame:IsShown() then frame:Show() end
    local facing=Facing()
    if not facing then
        heading:SetText("Heading unavailable"); HideMarkers()
        for _,label in ipairs(labels) do label:Hide() end
        return
    end
    local mapOpen=WorldMapFrame and WorldMapFrame:IsShown() or false
    if lastMapOpen and not mapOpen then needsZone=true end
    lastMapOpen=mapOpen
    if needsZone and not mapOpen then
        needsZone=false
        if SetMapToCurrentZone then SetMapToCurrentZone() end
        scanAge=1
    end
    if scanAge>=0.5 and not mapOpen then Collect(); scanAge=0 end
    local x,y
    if GetPlayerMapPosition then x,y=GetPlayerMapPosition("player") end
    local vertical=C.CompassIconOffset()
    if dirty or vertical~=lastIconOffset or facing~=lastFacing or x~=lastX or y~=lastY or mapOpen then
        Draw(facing,x,y,mapOpen); dirty=false; lastFacing,lastX,lastY=facing,x,y
        lastIconOffset=vertical
    end
end
local function MigrateLayout(db)
    if db.layoutVersion==2 then return end
    local overrides=nfUIDB.elements and nfUIDB.elements.compass
    if overrides then
        if overrides.width then db.width=overrides.width end
        if overrides.height then db.height=overrides.height end
        if overrides.scale then db.scale=overrides.scale end
        nfUIDB.elements.compass=nil
    end
    if not db.anchor or (db.anchor~="TOP" and db.anchor~="BOTTOM") then db.anchor="BOTTOM" end
    local position=nfUIDB.positions and nfUIDB.positions.compass
    if position and not position.centered then
        local ratio=db.scale
        position.x=position.x+(db.width or 420)*ratio/2-UIParent:GetWidth()/2
        if db.anchor=="TOP" then position.y=position.y+(db.height or 46)*ratio-UIParent:GetHeight() end
        position.centered=true
    end
    if db.width==420 and not overrides then db.fullWidth=true
    elseif db.width~=UIParent:GetWidth() or (overrides and overrides.width) then db.fullWidth=false end
    db.layoutVersion=2
end
function C.LayoutCompass()
    local db=C.Settings().compassStyle
    MigrateLayout(db)
    if db.anchor~="TOP" and db.anchor~="BOTTOM" then db.anchor="BOTTOM" end
    local maximum=UIParent:GetWidth()/db.scale
    if db.fullWidth then db.width=maximum else db.width=math.max(100,math.min(maximum,db.width)) end
    frame:SetScale(db.scale)
    local width,height=db.width,db.height
    if C.MatchedDimension then width=C.MatchedDimension("compass","width",width);height=C.MatchedDimension("compass","height",height) end
    frame:SetWidth(width); frame:SetHeight(height)
    pointer:SetHeight(math.min(12,math.max(2,db.height/4)))
    iconSize=db.iconSize
    local font=db.labelFont
    heading:SetFont(FONT,font,"OUTLINE")
    for i,label in ipairs(labels) do
        label:SetFont(FONT,Mod(i,2)==1 and font or math.max(6,font-2),"OUTLINE")
        label.compassX=nil
    end
    for _,widget in ipairs(widgets) do
        widget:SetWidth(iconSize); widget:SetHeight(iconSize)
    end
    if not (nfUIDB.positions and nfUIDB.positions.compass) then
        local inset=math.max(12,(math.max(db.iconSize,db.labelFont)-db.height)/2+2)
        frame:ClearAllPoints(); frame:SetPoint(db.anchor,UIParent,db.anchor,0,(db.anchor=="TOP" and -inset or inset)/db.scale)
    end
    dirty=true
end
C.defaults.compassStyle={width=UIParent:GetWidth(),height=11.5,scale=1,anchor="BOTTOM",fullWidth=true,iconSize=18,labelFont=13}
local range=C.Range
C.Range=function(category,key)
    if category=="compassStyle" then
        if key=="width" then return 100,UIParent:GetWidth()/C.Settings().compassStyle.scale,1 end
        if key=="height" then return 6,120,0.5 end
        if key=="iconSize" then return 6,96,1 end
        if key=="labelFont" then return 6,48,1 end
    end
    return range(category,key)
end
C.compassFrame=frame
frame:SetScript("OnUpdate",function()
    scanAge=scanAge+(arg1 or 0)
    local currentWidth=UIParent:GetWidth()
    if currentWidth~=screenWidth then screenWidth=currentWidth; C.LayoutCompass() end
    C.UpdateCompass()
end)
-- A UIParent driver keeps zone events active while the compass is hidden.
local loader=CreateFrame("Frame","nfUICompassLoader",UIParent)
for _,eventName in ipairs({"PLAYER_ENTERING_WORLD","ZONE_CHANGED","ZONE_CHANGED_NEW_AREA","WORLD_MAP_UPDATE"}) do loader:RegisterEvent(eventName) end
loader:SetScript("OnEvent",function()
    if event~="WORLD_MAP_UPDATE" then needsZone=true end
    scanAge=1; dirty=true; C.UpdateCompass()
end)
