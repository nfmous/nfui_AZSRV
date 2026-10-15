-- Shared 1.12 EditBox controls; focus is tracked by callbacks because HasFocus is not a 1.12 method.
local C=nfUIConfig
local inputs={}
function C.NumberText(value,percent)
    local text=string.format("%.3f",percent and value*100 or value)
    text=string.gsub(text,"0+$","");text=string.gsub(text,"%.$","")
    return text..(percent and "%" or "")
end
function C.CancelNumberInputs()
    for _,box in ipairs(inputs) do if box.editing then box:CancelNumber() end end
end
function C.CreateNumberInput(name,parent,width,height,options)
    local box=CreateFrame("EditBox",name,parent)
    box:SetWidth(width);box:SetHeight(height);box:SetAutoFocus(false)
    box:SetFont("Fonts\\FRIZQT__.TTF",12,"OUTLINE");box:SetJustifyH("RIGHT")
    box:SetTextColor(0.3,0.82,1)
    box:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"});box:SetBackdropColor(0.07,0.1,0.14,0.95)
    box.options=options
    function box:RefreshNumber()
        if self.editing then return end
        self:SetText(C.NumberText(self.options.get(),self.options.percent()))
    end
    function box:CancelNumber()
        self.editing=false;self:RefreshNumber();self:ClearFocus()
    end
    function box:CommitNumber()
        local text=string.gsub(self:GetText() or "","%s","")
        text=string.gsub(text,"%%$","");text=string.gsub(text,"px$","")
        local value=tonumber(text)
        self.editing=false
        if value and value==value and value-value==0 then
            if self.options.percent() then value=value/100 end
            local lo,hi,step=self.options.range()
            value=math.max(lo,math.min(hi,value))
            value=lo+math.floor((value-lo)/step+0.5)*step
            self.options.set(math.max(lo,math.min(hi,value)))
        end
        self:RefreshNumber();self:ClearFocus()
    end
    box:SetScript("OnEditFocusGained",function() box.editing=true end)
    box:SetScript("OnEditFocusLost",function() if box.editing then box:CommitNumber() end end)
    box:SetScript("OnEnterPressed",function() box:CommitNumber() end)
    box:SetScript("OnTabPressed",function() box:CommitNumber() end)
    box:SetScript("OnEscapePressed",function() box:CancelNumber() end)
    box:SetScript("OnHide",function() if box.editing then box:CancelNumber() end end)
    table.insert(inputs,box)
    return box
end
