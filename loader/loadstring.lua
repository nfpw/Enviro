getgenv().Enviro = getgenv().Enviro or {
    direct_load = false, -- use this if you entered a key before or when using a keyless version
    safe_load = false, -- if script version doesnt match with the game version then it will not load it
    debug = false, -- for development purposes, will print some debug info
    key = "none" -- the key to load the script, if you dont have a key then it will be "none"
}

if getgenv().Enviro.direct_load then
    loadstring(((syn and syn.request) or (http and http.request) or http_request or request)({Url = "https://raw.githubusercontent.com/nfpw/Enviro/refs/heads/main/loader/direct_load.lua"}).Body)()
else
    loadstring(((syn and syn.request) or (http and http.request) or http_request or request)({Url = "https://raw.githubusercontent.com/nfpw/Enviro/refs/heads/main/loader/key_ui.lua"}).Body)()
end
