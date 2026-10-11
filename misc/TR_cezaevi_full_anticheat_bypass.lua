-- made by @nfpw
local hooked = {}
for _, obj in pairs(filtergc("function", {}, false)) do
    if islclosure(obj) then
        local info = debug.getinfo(obj)
        if info and info.source then
            local c, cons = pcall(debug.getconstants, obj)
            local uv, ups = pcall(debug.getupvalues, obj)
            if not c or not cons then continue end

            if info.source:match("Cloudash%.Client$") then
                if cons[1] == "pcall" and uv and ups and type(ups[3]) == "userdata" and ups[3].Name == "VoiceChat3" then
                    hookfunction(obj, function() return true end)
                    print("[@nfpw bypass] blocked report")
                elseif cons[8] == "VoiceChat3" and cons[9] == "FireServer" then
                    hookfunction(obj, function() return true end)
                    print("[@nfpw bypass] blocked VoiceChat3 sender")
                end

                if uv and ups and type(ups[1]) == "function" and not hooked[ups[1]] then
                    hooked[ups[1]] = true
                    hookfunction(ups[1], function() return true end)
                    print("[@nfpw bypass] blocked crash (upvalue 1)")
                end
            end

            if info.source:match("LocalScript$") then
                if cons[1] == "ClassName" and cons[2] == "BodyGyro" and cons[3] == "BodyVelocity" then
                    hookfunction(obj, function() return true end)
                    print("[@nfpw bypass] blocked fly kick callback")
                end
            end
        end
    end
end

local lp = cloneref(game.GetService(game, "Players")).LocalPlayer

local function sigma_function(char)
    if not char or not char.Parent then return end
    local hrp = char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart", 5)
    if not hrp then return end
    for _, connection in pairs(getconnections(hrp.ChildAdded)) do
        pcall(function() connection:Disconnect() end)
        print("[@nfpw bypass] fly connection removed")
    end
end

if lp.Character then
    sigma_function(lp.Character)
    lp.Character.Destroying:Connect(function()
        print("[@nfpw bypass] character destroying, waiting for respawn")
    end)
end

lp.CharacterAdded:Connect(function(char)
    print("[@nfpw bypass] character added, waiting for HRP")
    sigma_function(char)

    char.ChildAdded:Connect(function(c)
        if c.Name == "HumanoidRootPart" then
            sigma_function(char)
        end
    end)
end); print("[@nfpw bypass] anticheat disabled")
