getgenv().Enviro = getgenv().Enviro or {debug = false, safe_load = false, direct_load = false, key = "none"}
local request = (syn and syn.request) or (http and http.request) or http_request or request
local loader = {}
local req = nil

local print = function(...)
	if getgenv().Enviro.debug then print("Enviro ", ...); end
end

local warn = function(...)
	if getgenv().Enviro.debug then warn("Enviro ", ...); end
end

local error = function(string)
	if getgenv().Enviro.debug then error("Enviro " .. " " .. string); end
end

loader["request_url"] = function(url)
	req = request({Url = url, Method = "GET"})
	if req.StatusCode ~= 200 then return nil, req.StatusCode end
	return req.Body
end

loader["check_script"] = function(url)
	local body, status_code = loader["request_url"](url)
	if body then
		return true, body
	else
		return false, status_code
	end
end

loader["load_script"] = function(url, content)
	local script_content = content
	if not script_content then
		local body, status_code = loader["request_url"](url)
		if not body then return end
		script_content = body
	end
	local success, result = pcall(function() return loadstring(script_content)() end)
	if not success and getgenv().Enviro.debug then
		warn("Script load error: " .. tostring(result))
	end
end

loader["games"] = {
	{
		Name = "Turkish Jailbreak",
		PlaceId = 89924130669271,
		Status = "comingsoon",
		Features = {"RageBot", "KillAura", "SilentAim", "Visuals", "Farm"},
		Executors = {"Wave", "Madium", "Cosmic"},
		Script = "https://raw.githubusercontent.com/nfpw/Enviro/refs/heads/main/games/universal.lua"
	},
}

loader["load_ui"] = function()
	local ui_url = "https://raw.githubusercontent.com/nfpw/Enviro/main/ui_library/module.lua"
	local body, status_code = loader["request_url"](ui_url)
	if body then
		local success, result = pcall(function() return loadstring(body)() end)
		if not success then
			warn("UI Library load error: " .. tostring(result))
		end
	else
		warn("Failed to load UI Library, status code: " .. tostring(status_code))
	end
end

loader["init"] = function()
	loader["load_ui"]()

	for _, game in ipairs(loader["games"]) do
		if game.Script and game.Status ~= "patched" and game.Status ~= "comingsoon" then
			game.Execute = function()
				loader["load_script"](game.Script, nil)
			end
		end
	end

	Library:Loader({
		Title = "Enviro Loader v0.3.3",
		Games = loader["games"]
	})
end

loader["init"]()
