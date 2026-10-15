-- Initialize only nfUI-owned saved variables. Existing profiles are retained.
if type(nfUIDB)~="table" or not next(nfUIDB) then
    nfUIDB=nfUIBuildStarterProfile(UIParent:GetWidth(),UIParent:GetHeight())
end
if type(nfUIPlatesDB)~="table" then nfUIPlatesDB={} end
if nfUIDB.damageText==nil then nfUIDB.damageText=true end
if nfUIDB.damageMode==nil then nfUIDB.damageMode=nfUIDB.damageText and "sct" or "off" end
if nfUIDB.sctStyle~="Methodical" and nfUIDB.sctStyle~="Biggest Hit" then nfUIDB.sctStyle="Explosive" end
if nfUIDB.compass==nil then nfUIDB.compass=true end

-- Apply the user's verified zoom limit after saved client settings load.
local camera=CreateFrame("Frame","nfUICameraStartup",UIParent)
camera:RegisterEvent("VARIABLES_LOADED")
camera:RegisterEvent("PLAYER_LOGIN")
camera:RegisterEvent("ADDON_LOADED")
camera:SetScript("OnEvent",function()
    if event=="ADDON_LOADED" and arg1~="nfUI" then return end
    if GetCVar("cameraDistanceMaxFactor")~="5" then SetCVar("cameraDistanceMaxFactor","5") end
end)
