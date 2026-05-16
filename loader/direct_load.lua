getgenv().Enviro = getgenv().Enviro or {debug = false, safe_load = false, direct_load = false}
local request = (syn and syn.request) or (http and http.request) or http_request
local queueteleport = (syn and syn.queue_on_teleport) or queue_on_teleport or (fluxus and fluxus.queue_on_teleport)
local loader = {}
local req = nil

loader["request_url"] = function(url)
	req = request({Url = url, Method = "GET"})
	if req.StatusCode ~= 200 then return nil, req.StatusCode; end
	return req.Body
end

loader["check_script"] = function(url)
	local body, statuscode = loader["request_url"](url)
	if body then
		return true, body; else return false, statuscode
	end
end

loader["load_script"] = function(url, content)
	local scriptcontent = content; if not scriptcontent then
		local body, statuscode = loader["request_url"](url)
		if not body then return end
		scriptcontent = body
	end; local success, result = pcall(function() return loadstring(scriptcontent)() end)
end

loader["init"] = function()
	local githuburl = "https://raw.githubusercontent.com/nfpw/Enviro/refs/heads/main/games/"
	local gameid = githuburl .. tonumber(game.GameId) .. ".lua"
	local universal = githuburl .. "universal.lua"
	local gamescriptexist, gamecontent = loader["check_script"](gameid)
	if gamescriptexist then
		loader["load_script"](gameid, gamecontent) else loader["load_script"](universal, nil)
	end
end

loader["init"]()
