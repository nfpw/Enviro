local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local lp = Players.LocalPlayer

local function target()
	local cp = nil
	local sd = math.huge
	if not lp.Character or not lp.Character:FindFirstChild("HumanoidRootPart") then
		return nil
	end
	local h = lp.Character.HumanoidRootPart
	for _, player in pairs(Players:GetPlayers()) do
		if player ~= lp and player.Character then
			local char = player.Character
			local hrp = char:FindFirstChild("HumanoidRootPart")
			local humanoid = char:FindFirstChild("Humanoid")
			if hrp and humanoid then
				local health = humanoid.Health
				if health == health and health ~= math.huge and health > 0 then
					local distance = (h.Position - hrp.Position).Magnitude
					if distance < sd then
						sd = distance
						cp = player
					end
				end
			end
		end
	end
	return cp
end

local function hmm()
	while task.wait() do
		local target = target()
		if target and target.Character then
			local head = target.Character:FindFirstChild("Head")
			if head then
				ReplicatedStorage:WaitForChild("GunEvents"):WaitForChild("Render"):FireServer({{Norm = Vector3.new(-0.0094, -0.0691, -0.9975), Hit = head, Position = vector.create(0/0, 0/0, 0/0)}})
			end
		end
	end
end

task.spawn(hmm())
