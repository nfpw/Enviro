for _, obj in pairs(getgc()) do
    if type(obj) == "function" and islclosure(obj) then
        local info = debug.getinfo(obj)
        if info and info.source and (info.source:find("Cloudash.Client") or info.source:find("haha") or info.source:find("LocalScript")) then
            local success, upvalues = pcall(debug.getupvalues, obj)
            if success and upvalues then
                for i, upval in ipairs(upvalues) do
                    if type(upval) == "table" then
                        for _, v in pairs(upval) do
                            if type(v) == "string" and (v:find("AppUpdateService") or v:find("UGCValidationService") or v:find("VoiceChat2") or v:find("VoiceChat3")) then
                                local func = obj
                                local upv = debug.getupvalues(func)
                                for idx, val in ipairs(upv) do
                                    if type(val) == "function" then
                                        hookfunction(val, function() warn("blocked crash/voicechat") end)
                                    elseif type(val) == "table" then
                                        if rawget(val, "FireServer") then
                                            hookfunction(val.FireServer, function(...) warn("blocked remote") end)
                                        end
                                        if rawget(val, "InvokeServer") then
                                            hookfunction(val.InvokeServer, function(...) warn("blocked remote") end)
                                        end
                                    end
                                end
                            end
                        end
                    elseif type(upval) == "table" then
                        if rawget(upval, "FireServer") then
                            hookfunction(upval.FireServer, function(...) warn("blocked remote") end)
                        end
                        if rawget(upval, "InvokeServer") then
                            hookfunction(upval.InvokeServer, function(...) warn("blocked remote") end)
                        end
                    end
                end
            end
        end
    end
end

local player = game:GetService("Players").LocalPlayer
if player and player.Character then
    local hrp = player.Character:WaitForChild("HumanoidRootPart")
    for _, connection in pairs(getconnections(hrp.ChildAdded)) do
        connection:Disconnect()
    end
end

player.CharacterAdded:Connect(function(char)
    local hrp = char:WaitForChild("HumanoidRootPart")
    for _, connection in pairs(getconnections(hrp.ChildAdded)) do
        connection:Disconnect()
    end
end)
