getgenv().Enviro = getgenv().Enviro or {debug = false, safe_load = false, direct_load = false, key = "none"}
local request = (syn and syn.request) or (http and http.request) or http_request or request
local loader = {}
local req = nil

local print = function(...)
	if getgenv().Enviro.debug then print("Enviro", ...); end
end

local warn = function(...)
	if getgenv().Enviro.debug then warn("Enviro", ...); end
end

local error = function(string)
	if getgenv().Enviro.debug then error("Enviro" .. " " .. string); end
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

loader["check_game_exists"] = function()
	local game_script_url = "https://raw.githubusercontent.com/nfpw/Enviro/refs/heads/main/games/"..tostring(game.GameId)..".lua"
	local exists, content = loader["check_script"](game_script_url)
	return exists, content
end

loader["init"] = function()
	loader["load_ui"]()

	Library:KeySystem({
		Key = "",
		Title = "Enviro Key System",
		Description = "Enter key on discord to load script or u get nothing :)",
		SaveKey = true,
		Discord = "https://discord.gg/M7cSuuqY5a",
		GetKey = "https://discord.gg/M7cSuuqY5a",
		Callback = function(success, entered_key)
			if success then
				getgenv().Enviro.key = entered_key or "none"
				print("Saved key: " .. tostring(getgenv().Enviro.key))
				if getgenv().Enviro.direct_load then
					local game_exists, game_content = loader["check_game_exists"]()
					if game_exists then
						print("Game script found. Loading direct game script...")
						loader["load_script"]("https://raw.githubusercontent.com/nfpw/Enviro/refs/heads/main/games/" .. tostring(game.GameId) .. ".lua", game_content)
					else
						print("Game script not found. Loading GUI loader...")
						loader["load_script"]("https://raw.githubusercontent.com/nfpw/Enviro/refs/heads/main/loader/gui_load.lua", nil)
					end
				else
					print("Loading GUI loader...")
					loader["load_script"]("https://raw.githubusercontent.com/nfpw/Enviro/refs/heads/main/loader/gui_load.lua", nil)
				end
			else
				warn("what")
			end
		end
	})
end

loader["init"]()
