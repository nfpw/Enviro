getgenv().Enviro = getgenv().Enviro or {debug = false, safe_load = false, direct_load = false, key = "none"}
local request = (syn and syn.request) or (http and http.request) or http_request or request
local loader = {}
local req = nil

loader["request_url"] = function(url)
	req = request({Url = url, Method = "GET"})
	if req.StatusCode ~= 200 then return nil, req.StatusCode; end
	return req.Body
end

loader["check_script"] = function(url)
	local body, status_code = loader["request_url"](url)
	if body then
		return true, body; else return false, status_code
	end
end

loader["load_script"] = function(url, content)
	local script_content = content; if not script_content then
		local body, status_code = loader["request_url"](url)
		if not body then return end
		script_content = body
	end; local success, result = pcall(function() return loadstring(script_content)() end)
end

loader["init"] = function()
	local github_url = "https://raw.githubusercontent.com/nfpw/Enviro/refs/heads/main/games/"
	local game_id = github_url .. tonumber(game.GameId) .. ".lua"
	local gui_load_url = "https://raw.githubusercontent.com/nfpw/Enviro/refs/heads/main/loader/gui_load.lua"
	
	local game_script_exist, game_content = loader["check_script"](game_id)
	if game_script_exist then
		loader["load_script"](game_id, game_content)
	else
		loader["load_script"](gui_load_url, nil)
	end
end

loader["init"]()
