setfenv(1, nfUIModules:GetEnv())

function HookScript(frame, script, handler)
    if not frame then return end
    local previous = frame:GetScript(script)
    frame:SetScript(script, function(a1,a2,a3,a4,a5,a6,a7,a8,a9)
        if previous then previous(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
        handler(a1,a2,a3,a4,a5,a6,a7,a8,a9)
    end)
end

function hooksecurefunc(name, handler)
    local previous = _G[name]
    if type(previous) ~= "function" then return end
    _G[name] = function(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10)
        previous(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10)
        handler(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10)
    end
end
