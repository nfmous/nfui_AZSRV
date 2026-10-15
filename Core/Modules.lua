-- Shared module environment and tools for nfUI's native-data integrations.
nfUIModules = CreateFrame("Frame", nil, UIParent)
nfUIModules.env = {}
nfUIModules.tools = {}
nfUIModules.modules = {}

setmetatable(nfUIModules.env, {__index = getfenv(0)})

function nfUIModules:GetEnv()
    self.env._G = getfenv(0)
    self.env.T = self.tools
    return self.env
end

function nfUIModules:GetInfoOrCons(kind)
    local path = "Interface\\AddOns\\nfUI\\"
    if kind == "tex" then return path .. "Resources\\media\\tex\\" end
    return path
end

function nfUIModules:NewMod(name, priority, initialize)
    table.insert(self.modules, {name = name, priority = priority, initialize = initialize})
end

local booted = false
local function Initialize()
    if booted then return end
    booted = true
    table.sort(nfUIModules.modules, function(a, b)
        if a.priority == b.priority then return a.name < b.name end
        return a.priority < b.priority
    end)
    for _, module in ipairs(nfUIModules.modules) do
        setfenv(module.initialize, nfUIModules:GetEnv())
        local success, message = pcall(module.initialize)
        if not success then geterrorhandler()(module.name .. ": " .. tostring(message)) end
    end
    nfUIModules.modules = nil
    nfUIModules:UnregisterAllEvents()
end

-- The port may load loose addons after stock FrameXML has already initialized.
nfUIModules:RegisterEvent("ADDON_LOADED")
nfUIModules:RegisterEvent("PLAYER_LOGIN")
nfUIModules:SetScript("OnEvent", function()
    if event == "PLAYER_LOGIN" or (event == "ADDON_LOADED" and arg1 == "nfUI") then
        Initialize()
    end
end)
