-- made by @nfpw
for _, obj in pairs(filtergc("function", { IgnoreExecutor = false }, false)) do
    if islclosure(obj) then
        local info = debug.getinfo(obj)
        if info and info.source and (info.source:find("Cloudash.Client") or info.source:find("haha") or info.source:find("LocalScript")) then
            local success, upvalues = pcall(debug.getupvalues, obj)
            if success and upvalues then
                for i, upval in ipairs(upvalues) do
                    if type(upval) == "table" then
                        for _, v in pairs(upval) do
                            if type(v) == "string" and (v:find("AppUpdateService") or v:find("UGCValidationService") or v:find("VoiceChat2") or v:find("VoiceChat3")) then
                                for idx, val in ipairs(debug.getupvalues(obj)) do
                                    if type(val) == "function" then
                                        hookfunction(val, function() return true end)
                                        print("[cezaevi anticheat] crash hooked ".. idx)
                                    elseif type(val) == "table" then
                                        if rawget(val, "FireServer") then hookfunction(val.FireServer, function(...) return true end) end
                                        if rawget(val, "InvokeServer") then hookfunction(val.InvokeServer, function(...) return true end) end
                                        print("[cezaevi anticheat] events hooked [1]".. idx)
                                    end
                                end
                                if rawget(upval, "FireServer") then hookfunction(upval.FireServer, function(...) return true end) end
                                if rawget(upval, "InvokeServer") then hookfunction(upval.InvokeServer, function(...) return true end) end
                                print("[cezaevi anticheat] events hooked [2] ".. v)
                            end
                        end
                    end
                end
            end
        end
    end
end; print("[cezaevi anticheat] hooked")

local lp = cloneref(game.GetService(game, "Players")).LocalPlayer; if lp and lp.Character then
    local hrp = lp.Character.FindFirstChild(lp.Character, "HumanoidRootPart") or lp.Character.WaitForChild(lp.Character, "HumanoidRootPart", 5)
    if hrp then
        for _, connection in pairs(getconnections(hrp.ChildAdded)) do
            connection:Disconnect()
            print("fly check hooked [2]")
        end
    end
end

lp.CharacterAdded:Connect(function(char)
    local hrp = char.FindFirstChild(char, "HumanoidRootPart") or char.WaitForChild(char, "HumanoidRootPart", 5)
    if hrp then
        for _, connection in pairs(getconnections(hrp.ChildAdded)) do
            connection:Disconnect()
            print("fly check hooked [1]")
        end
    end
end)
