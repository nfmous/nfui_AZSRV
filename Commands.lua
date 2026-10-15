-- nfUI command dispatch and live layout refresh.
local C=nfUIConfig
local settingsCommand=SlashCmdList.NFUI
local function Mode(mode)
    if mode=="quick" then
        if nfUIModules.SelectDamageMode then nfUIModules.SelectDamageMode("off") end
        nfUIDB.damageMode="quick"; nfUIDB.damageText=true; C.ApplyDamageText()
    elseif nfUIModules.SelectDamageMode then
        nfUIModules.SelectDamageMode(mode=="sct" and "on" or mode)
    else
        nfUIDB.damageMode=mode; nfUIDB.damageText=mode~="off"; C.ApplyDamageText()
    end
end
SLASH_NFUI1="/nfui"
SlashCmdList.NFUI=function(message)
    local text=string.lower(string.gsub(message or "","^%s*(.-)%s*$","%1"))
    local _,_,command,argument=string.find(text,"^(%S*)%s*(.*)$")
    if command=="dps" and C.SetDPSCollapsed then
        C.SetDPSCollapsed(argument=="close" or argument=="collapse")
    elseif text=="run" then nfUI_ToggleRun()
    elseif text=="run reset" then nfUI_ResetRun()
    elseif command=="damage" then
        local mode=argument
        if mode=="" then mode=nfUIDB.damageMode=="default" and "sct" or "default" end
        if mode=="sct" or mode=="quick" or mode=="default" or mode=="off" then Mode(mode)
        else DEFAULT_CHAT_FRAME:AddMessage("nfUI: /nfui damage sct | quick | default | off") end
    elseif command=="chat" and tonumber(argument) then
        C.Settings().chat.font=math.max(8,math.min(24,tonumber(argument))); C.Apply()
    elseif command=="compass" then
        if argument=="on" then nfUIDB.compass=true
        elseif argument=="off" then nfUIDB.compass=false
        else nfUIDB.compass=not nfUIDB.compass end
        if C.UpdateCompass then C.UpdateCompass() end
    elseif command=="plates" then SlashCmdList.NFUIPLATES(argument)
    else settingsCommand(text) end
end
local apply=C.Apply
C.Apply=function()
    apply()
    if nfUIModules.AttachRunTally then nfUIModules.AttachRunTally() end
    if C.ApplyMapFeather then C.ApplyMapFeather() end
    if C.LayoutStats then C.LayoutStats() end
    if C.RefreshRunPanel then C.RefreshRunPanel() end
    if C.RefreshDPSMeter then C.RefreshDPSMeter() end
    if C.ApplyNameplates then C.ApplyNameplates() end
end
