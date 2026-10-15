-- Native run-wide meter data, rendered in nfUI's own flat collapsible panel.
nfUIModules:NewMod("DPSMeter",5,function()
    local C=nfUIConfig
    local FONT="Fonts\\FRIZQT__.TTF"
    local panel=CreateFrame("Frame","nfUIDPSMeter",UIParent)
    panel:SetWidth(112);panel:SetHeight(32);panel:SetFrameStrata("MEDIUM")
    panel:EnableMouse(true)
    panel:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"});panel:SetBackdropColor(0.04,0.04,0.07,0.88)
    local header=CreateFrame("Button","nfUIDPSHeader",panel);header:SetHeight(32)
    header:EnableMouse(true);header:RegisterForClicks("LeftButtonUp")
    header:SetPoint("BOTTOMLEFT",panel,"BOTTOMLEFT",0,0);header:SetPoint("BOTTOMRIGHT",panel,"BOTTOMRIGHT",0,0)
    local title=header:CreateFontString(nil,"OVERLAY");title:SetFont(FONT,11,"OUTLINE")
    title:SetPoint("LEFT",header,"LEFT",8,0);title:SetText("DPS Meter");title:SetTextColor(1,0.82,0)
    local toggle=CreateFrame("Button","nfUIDPSCollapse",header,"UIPanelButtonTemplate")
    toggle:EnableMouse(true);toggle:RegisterForClicks("LeftButtonUp")
    toggle:SetFrameLevel(header:GetFrameLevel()+5)
    toggle:SetWidth(22);toggle:SetHeight(22);toggle:SetPoint("RIGHT",header,"RIGHT",-5,0)
    local scroll=CreateFrame("ScrollFrame","nfUIDPSScroll",panel)
    scroll:SetPoint("BOTTOMLEFT",panel,"BOTTOMLEFT",8,36)
    local content=CreateFrame("Frame",nil,scroll);content:SetHeight(1);scroll:SetScrollChild(content)
    local summary=content:CreateFontString(nil,"OVERLAY");summary:SetFont(FONT,11,"OUTLINE")
    summary:SetPoint("TOPLEFT",content,"TOPLEFT",0,0)
    local rows,offset={},0
    local fittedWidth,fittedHeight=112,66
    local measure=panel:CreateFontString(nil,"OVERLAY");measure:SetFont(FONT,11,"OUTLINE");measure:Hide()
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel",function()
        local maximum=math.max(0,content:GetHeight()-scroll:GetHeight())
        offset=math.max(0,math.min(maximum,offset-(arg1 or 0)*30));scroll:SetVerticalScroll(offset)
    end)
    local function Settings()
        local db=C.Settings();db.positions=db.positions or {};db.elements=db.elements or {}
        if db.dpsCollapsed==nil then db.dpsCollapsed=true end
        if not db.positions.dpsMeter then db.positions.dpsMeter={x=UIParent:GetWidth()-136,y=90} end
        local old=db.elements.dpsMeter
        if old then for _,key in ipairs({"width","height","scale"}) do if old[key] then db.dpsDisplay[key]=old[key];old[key]=nil end end end
        return db,db.dpsDisplay,db.positions.dpsMeter
    end
    function C.CaptureDPSPosition()
        local _,_,p=Settings();return {x=p.x,y=p.y}
    end
    function C.AnchorDPSPosition(position)
        local _,_,p=Settings();p.x=position.x;p.y=position.y;C.LayoutDPSMeter()
    end
    local layoutKey
    function C.LayoutDPSMeter()
        local db,size,p=Settings()
        local scale=size.scale or 1;panel:SetScale(scale)
        local width=db.dpsCollapsed and 112 or (size.autoWidth and fittedWidth or size.width)
        local height=db.dpsCollapsed and 32 or (size.autoHeight and fittedHeight or size.height)
        width=math.min(width,UIParent:GetWidth()/scale);height=math.min(height,UIParent:GetHeight()/scale)
        panel:SetBackdropColor(0.04,0.04,0.07,size.backdropOpacity)
        if C.MatchedDimension then width=C.MatchedDimension("dpsMeter","width",width);height=C.MatchedDimension("dpsMeter","height",height) end
        local right=p.x+56*scale>UIParent:GetWidth()/2
        local key=width..":"..height..":"..scale..":"..p.x..":"..p.y..":"..tostring(right)
        if layoutKey~=key or panel:GetWidth()~=width or panel:GetHeight()~=height then
            layoutKey=key;panel:SetWidth(width);panel:SetHeight(height)
            panel:ClearAllPoints()
            panel:SetPoint(right and "BOTTOMRIGHT" or "BOTTOMLEFT",UIParent,"BOTTOMLEFT",(p.x+(right and 112*scale or 0))/scale,p.y/scale)
        end
        toggle:SetText(db.dpsCollapsed and (right and "<" or ">") or (right and ">" or "<"))
        scroll:SetWidth(math.max(1,width-16));scroll:SetHeight(math.max(1,height-44));content:SetWidth(math.max(1,width-16))
        if db.dpsCollapsed then scroll:Hide() else scroll:Show() end
    end
    function C.SetDPSCollapsed(collapsed)
        local db=Settings();db.dpsCollapsed=collapsed and true or false
        C.LayoutDPSMeter();C.RefreshDPSMeter()
    end
    local function Toggle()
        local db=Settings();C.SetDPSCollapsed(not db.dpsCollapsed)
    end
    toggle:SetScript("OnClick",Toggle)
    header:SetScript("OnClick",function()
        if MouseIsOver and MouseIsOver(toggle) then return end
        Toggle()
    end)
    local originalShown,owned
    local function Restore()
        if owned and AZS_SetHudShown then pcall(AZS_SetHudShown,"meter",originalShown) end
        owned=nil;panel:Hide()
    end
    local function Number(value) return type(value)=="number" and value>=0 and value-value==0 end
    local function Short(value)
        if value>=1000000 then return string.format("%.1fm",value/1000000) end
        if value>=1000 then return string.format("%.1fk",value/1000) end
        return string.format("%.0f",value)
    end
    function C.RefreshDPSMeter()
        C.LayoutDPSMeter()
        local phase=AZS_GetPhase and AZS_GetPhase()
        local ok,lines,total,dps=false
        if phase and AZS_GetMeter then ok,lines,total,dps=pcall(AZS_GetMeter) end
        if not ok or type(lines)~="table" or not Number(total) or not Number(dps) then
            Restore();if C.editing then panel:Show() end;return
        end
        for _,line in ipairs(lines) do
            if type(line)~="table" or type(line.name)~="string" or not Number(line.dmg) or not Number(line.dps) or not Number(line.share) then Restore();return end
        end
        if not AZS_IsHudShown or not AZS_SetHudShown then Restore();return end
        if not owned then
            local success,shown=pcall(AZS_IsHudShown,"meter")
            if not success or shown==nil then Restore();return end
            originalShown=shown==true or shown==1 or shown=="1";owned=true
        end
        local success=pcall(AZS_SetHudShown,"meter",false)
        if not success then Restore();return end
        local checked,shown=pcall(AZS_IsHudShown,"meter")
        if not checked or (shown~=false and shown~=0 and shown~="0") then Restore();return end
        panel:Show();summary:SetText(Short(dps).." DPS   |   "..Short(total).." damage")
        local function Measure(text)
            measure:SetText(text)
            return measure.GetStringWidth and measure:GetStringWidth() or string.len(text)*7
        end
        fittedWidth=math.max(112,Measure(summary:GetText())+16)
        for _,line in ipairs(lines) do
            local value=Short(line.dps).." | "..string.format("%.0f%%",line.share*100)
            fittedWidth=math.max(fittedWidth,Measure(line.name)+Measure(value)+28)
        end
        fittedHeight=66+table.getn(lines)*23
        C.LayoutDPSMeter()
        local width=math.max(1,panel:GetWidth()-16)
        for index,line in ipairs(lines) do
            local row=rows[index]
            if not row then
                row=CreateFrame("StatusBar",nil,content);row:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
                row:SetMinMaxValues(0,1);row:SetHeight(20)
                row.name=row:CreateFontString(nil,"OVERLAY");row.name:SetFont(FONT,11,"OUTLINE");row.name:SetPoint("LEFT",row,"LEFT",4,0);row.name:SetJustifyH("LEFT")
                row.valueText=row:CreateFontString(nil,"OVERLAY");row.valueText:SetFont(FONT,11,"OUTLINE");row.valueText:SetPoint("RIGHT",row,"RIGHT",-4,0)
                rows[index]=row
            end
            row:SetWidth(width);row:SetPoint("TOPLEFT",content,"TOPLEFT",0,-22-(index-1)*23)
            row:SetStatusBarColor(line.proc==1 and 0.15 or 0.15,line.proc==1 and 0.45 or 0.55,line.proc==1 and 0.8 or 0.3,0.65)
            local value=Short(line.dps).." | "..string.format("%.0f%%",line.share*100)
            local valueWidth=Measure(value)
            row:SetValue(math.min(1,line.share));row.name:SetWidth(math.max(1,width-valueWidth-12));row.name:SetHeight(14);row.name:SetText(line.name)
            row.valueText:SetWidth(valueWidth);row.valueText:SetHeight(14);row.valueText:SetJustifyH("RIGHT");row.valueText:SetText(value);row:Show()
        end
        for index=table.getn(lines)+1,table.getn(rows) do rows[index]:Hide() end
        content:SetHeight(22+table.getn(lines)*23)
        local maximum=math.max(0,content:GetHeight()-scroll:GetHeight());offset=math.min(offset,maximum);scroll:SetVerticalScroll(offset)
    end
    C.dpsFrame=panel;C.dpsRows=rows;C.LayoutDPSMeter()
    if C.RegisterMover then C.RegisterMover("dpsMeter","DPS Meter",panel,"dpsMeter") end
    local age=0
    local driver=CreateFrame("Frame","nfUIDPSDriver",UIParent)
    driver:RegisterEvent("PLAYER_LOGOUT");driver:RegisterEvent("PLAYER_LEAVING_WORLD");driver:RegisterEvent("PLAYER_ENTERING_WORLD")
    local inWorld=true
    driver:SetScript("OnEvent",function() if event=="PLAYER_ENTERING_WORLD" then inWorld=true;C.RefreshDPSMeter() else inWorld=false;Restore() end end)
    driver:SetScript("OnUpdate",function() age=age+(arg1 or 0);if age<0.2 then return end;age=0;if inWorld then C.RefreshDPSMeter() end end)
    C.RefreshDPSMeter()
end)
