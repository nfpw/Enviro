-- made by @nfpw
local detected = nil; local crash = nil
for _, v in pairs(filtergc("table", {}, false)) do
    if not detected and rawget(v, "Detected") and typeof(v.Detected) == "function" then
        detected = v.Detected
        hookfunction(detected, function(Action, Info, NoCrash) return true end)
        --print("detect hooked")
    end
    if not crash and rawget(v, "Kill") and typeof(v.Kill) == "function" then
        crash = v.Kill
        hookfunction(crash, function(Info) print(Info) end)
        --print("crash hooked")
    end
    if detected and crash then break end
end; --print("adonis hooked")
