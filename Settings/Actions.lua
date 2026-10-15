-- Shared settings actions and live layout refresh.
local C=nfUIConfig
function C.SetDamageMode(mode)
    if mode=="quick" then
        if nfUIModules.SelectDamageMode then nfUIModules.SelectDamageMode("off") end
        nfUIDB.damageMode="quick"; nfUIDB.damageText=true; C.ApplyDamageText()
    elseif nfUIModules.SelectDamageMode then
        nfUIModules.SelectDamageMode(mode=="sct" and "on" or mode)
    else
        nfUIDB.damageMode=mode; nfUIDB.damageText=mode~="off"; C.ApplyDamageText()
    end
end
function C.SetSCTStyle(style)
    if style~="Explosive" and style~="Methodical" and style~="Biggest Hit" then return end
    nfUIDB.sctStyle=style
    if nfUIModules.ApplySCTStyle then nfUIModules.ApplySCTStyle() end
end
local apply=C.Apply
C.Apply=function()
    apply()
    if nfUIModules.AttachRunTally then nfUIModules.AttachRunTally() end
    if C.ApplyMapFeather then C.ApplyMapFeather() end
    if C.UpdateCompass then C.UpdateCompass() end
    if C.LayoutStats then C.LayoutStats() end
    if C.RefreshRunPanel then C.RefreshRunPanel() end
    if C.RefreshDPSMeter then C.RefreshDPSMeter() end
    if C.ApplyNameplates then C.ApplyNameplates() end
end
