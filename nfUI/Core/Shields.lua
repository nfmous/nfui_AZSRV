-- Prefer the native absorb total; otherwise read the aggregate player aura.
local C=nfUIConfig
local reader={at=nil,value=nil,tooltip=nil,unsupported=false}
function C.ParseShieldAmount(line)
    if type(line)~="string" then return nil end
    local plain=string.gsub(string.gsub(line,"|c%x%x%x%x%x%x%x%x",""),"|r","")
    local _,_,number=string.find(plain,"^Absorbs ([%d,]+) damage%.$")
    return number and tonumber((string.gsub(number,",",""))) or nil
end
local function AuraTotal()
    if reader.unsupported or not GetPlayerBuff then return nil end
    if not reader.tooltip then
        local success,tooltip=pcall(CreateFrame,"GameTooltip","nfUIShieldScan",UIParent,"GameTooltipTemplate")
        if not success or not tooltip or not tooltip.SetPlayerBuff then reader.unsupported=true;return nil end
        reader.tooltip=tooltip;tooltip:SetAlpha(0)
    end
    local tooltip,maximum=reader.tooltip,0
    for slot=0,15 do
        local index=GetPlayerBuff(slot,"HELPFUL")
        if index and index>=0 then
            local success=pcall(function()
                tooltip:SetOwner(UIParent,"ANCHOR_NONE");tooltip:ClearLines();tooltip:SetPlayerBuff(index)
                local limit=math.min(30,tooltip.NumLines and tooltip:NumLines() or 30)
                for line=1,limit do
                    local label=getglobal("nfUIShieldScanTextLeft"..line)
                    local value=label and C.ParseShieldAmount(label:GetText())
                    if value and value>maximum then maximum=value end
                end
            end)
            tooltip:Hide();if not success then return nil end
        end
    end
    return maximum
end
function C.GetShield(unit)
    if UnitGetTotalAbsorbs then
        local success,value=pcall(UnitGetTotalAbsorbs,unit)
        if success and type(value)=="number" then return math.max(0,value) end
    end
    if unit~="player" then return nil end
    local now=GetTime()
    if not reader.at or now<reader.at or now-reader.at>=0.2 then reader.at=now;reader.value=AuraTotal() end
    return reader.value
end
