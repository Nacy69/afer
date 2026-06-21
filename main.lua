local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer
local clientEntities = workspace:WaitForChild("ClientEntities")

local WAYPOINTS_URL = "https://raw.githubusercontent.com/Nacy69/afer/refs/heads/main/MobWaypoints.json" -- Replace with your raw JSON URL
local BOSS_WAYPOINTS_URL = "https://raw.githubusercontent.com/Nacy69/afer/refs/heads/main/BossWaypoints.json" -- Replace with your raw Boss JSON URL

local currentTarget = nil
local isEnabled = false
local selectedEntities = {}

local teleportDistance = 5
local teleportPosition = "Above"

local movementMode = "Tween"
local tweenSpeed = 50

-- Load Fluent UI Library (Requires an executor that supports game:HttpGet)
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local Window = Fluent:CreateWindow({
	Title = "Auto Teleporter",
	SubTitle = "Entity Selector",
	TabWidth = 160,
	Size = UDim2.fromOffset(520, 600),
	Acrylic = true, 
	Theme = "Dark",
	MinimizeKey = Enum.KeyCode.RightControl
})

local Tabs = {
	Main = Window:AddTab({ Title = "Main", Icon = "home" }),
	Bosses = Window:AddTab({ Title = "Bosses", Icon = "skull" }),
	Kurama = Window:AddTab({ Title = "Kurama", Icon = "box" }),
	AutoKey = Window:AddTab({ Title = "Auto Key", Icon = "keyboard" }),
	Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

-- Toggle for auto teleport
local EnableToggle = Tabs.Main:AddToggle("EnableToggle", {
	Title = "Enable Auto Teleport", 
	Default = false 
})

EnableToggle:OnChanged(function(Value)
	isEnabled = Value
end)

-- Dropdown to select preferred entity names
local EntityDropdown = Tabs.Main:AddDropdown("EntityDropdown", {
	Title = "Preferred Entities",
	Description = "Select which entities to target from the loaded waypoints",
	Values = {},
	Multi = true,
	Default = {},
})

EntityDropdown:OnChanged(function(Value)
	selectedEntities = Value
end)

-- Dropdown for Movement Mode
local MovementDropdown = Tabs.Main:AddDropdown("MovementDropdown", {
	Title = "Movement Mode",
	Description = "How you move to the entity. Tween glides smoothly.",
	Values = {"Instant", "Tween"},
	Multi = false,
	Default = 2,
})

MovementDropdown:OnChanged(function(Value)
	movementMode = Value
end)

-- Slider for Tween Speed
local SpeedSlider = Tabs.Main:AddSlider("SpeedSlider", {
	Title = "Tween Speed",
	Description = "How fast you glide (studs/sec). Only for Tween mode.",
	Default = 50,
	Min = 10,
	Max = 500,
	Rounding = 1,
	Callback = function(Value)
		tweenSpeed = Value
	end
})

SpeedSlider:OnChanged(function(Value)
	tweenSpeed = Value
end)

-- Input field for Tween Speed
local SpeedInput = Tabs.Main:AddInput("SpeedInput", {
	Title = "Type Exact Tween Speed",
	Default = "50",
	Placeholder = "Enter speed...",
	Numeric = true,
	Finished = true,
	Callback = function(Value)
		local num = tonumber(Value)
		if num then
			tweenSpeed = num
			SpeedSlider:SetValue(num)
		end
	end
})

-- Slider for Distance
local DistanceSlider = Tabs.Main:AddSlider("DistanceSlider", {
	Title = "Attack Distance",
	Description = "Distance from the target entity",
	Default = 5,
	Min = 0,
	Max = 50,
	Rounding = 1,
	Callback = function(Value)
		teleportDistance = Value
	end
})

DistanceSlider:OnChanged(function(Value)
	teleportDistance = Value
end)

-- Input field for Distance
local DistanceInput = Tabs.Main:AddInput("DistanceInput", {
	Title = "Type Exact Attack Distance",
	Default = "5",
	Placeholder = "Enter distance...",
	Numeric = true,
	Finished = true,
	Callback = function(Value)
		local num = tonumber(Value)
		if num then
			teleportDistance = num
			DistanceSlider:SetValue(num)
		end
	end
})

-- Dropdown for Position
local PositionDropdown = Tabs.Main:AddDropdown("PositionDropdown", {
	Title = "Target Position",
	Description = "Where to hover relative to the target",
	Values = {"Above", "Below", "Behind"},
	Multi = false,
	Default = 1,
})

PositionDropdown:OnChanged(function(Value)
	teleportPosition = Value
end)

local HttpService = game:GetService("HttpService")

local currentWaypointIndex = 1
local lastSpawnVisitTime = 0
local spawnVisitDelay = 0.1
local customWaypoints = {}
local bossWaypoints = {}
local isBossAutoEnabled = false
local selectedBosses = {}
local currentBossIndex = 1
local lastBossVisitTime = 0

local isKuramaAutoEnabled = false
local kuramaSafetyThreshold = 30
local kuramaHighDistance = 100
local kuramaAlwaysBehind = false
local kuramaTeleportDistance = 5
local lastKuramaSummonTime = 0
local kuramaSpawnTime = 0
local wasKuramaAlive = false

-- Auto-load waypoints from URL on startup
if WAYPOINTS_URL ~= "" and WAYPOINTS_URL ~= "PUT_YOUR_JSON_URL_HERE" then
	task.spawn(function()
		local success, res = pcall(function()
			return game:HttpGet(WAYPOINTS_URL)
		end)
		if success and res then
			local decodeSuccess, decoded = pcall(function()
				return HttpService:JSONDecode(res)
			end)
			if decodeSuccess and type(decoded) == "table" then
				customWaypoints = {}
				local uniqueMobNames = {}
				local addedNames = {}
				
				for _, wp in ipairs(decoded) do
					if wp.X and wp.Y and wp.Z and wp.Name then
						table.insert(customWaypoints, {Name = wp.Name, Position = Vector3.new(wp.X, wp.Y, wp.Z)})
						
						if not addedNames[wp.Name] then
							addedNames[wp.Name] = true
							table.insert(uniqueMobNames, wp.Name)
						end
					end
				end
				
				table.sort(uniqueMobNames)
				EntityDropdown:SetValues(uniqueMobNames)
				
				Fluent:Notify({ Title = "Success", Content = "Loaded " .. #customWaypoints .. " online waypoints!", Duration = 3 })
			else
				Fluent:Notify({ Title = "Error", Content = "Failed to parse online waypoints JSON.", Duration = 5 })
			end
		else
			Fluent:Notify({ Title = "Error", Content = "Failed to fetch online waypoints.", Duration = 5 })
		end
	end)
end

-- Gets the CFrame of the target entity
local function getTargetCFrame(target)
	if target:IsA("Model") then
		local root = target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart")
		if root then
			return root.CFrame
		end
	elseif target:IsA("BasePart") then
		return target.CFrame
	end
	return nil
end

-- Continuous RenderStepped Loop for smooth tweening/teleporting
RunService.RenderStepped:Connect(function(deltaTime)
	local character = player.Character
	if not character then return end
	
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end
	
	if isKuramaAutoEnabled then
		local kurama = clientEntities:FindFirstChild("Kurama")
		local isKuramaAlive = false
		if kurama then
			local humanoid = kurama:FindFirstChildOfClass("Humanoid")
			if not humanoid or humanoid.Health > 0 then
				isKuramaAlive = true
			end
		end

		if isKuramaAlive then
			if not wasKuramaAlive then
				kuramaSpawnTime = os.clock()
				wasKuramaAlive = true
			end

			if os.clock() - kuramaSpawnTime < 3 then
				return -- Wait 3 seconds before locking on
			end

			local humanoid = kurama:FindFirstChildOfClass("Humanoid")
			local targetCFrame = getTargetCFrame(kurama)
			if targetCFrame then
				local playerHumanoid = character:FindFirstChildOfClass("Humanoid")
				local healthPercent = playerHumanoid and (playerHumanoid.Health / playerHumanoid.MaxHealth) * 100 or 100
				
				local newCFrame
				if healthPercent < kuramaSafetyThreshold then
					-- Safety High
					local pos = targetCFrame.Position + Vector3.new(0, kuramaHighDistance, 0)
					newCFrame = CFrame.lookAt(pos, targetCFrame.Position)
				else
					-- Normal teleport
					local activePosition = kuramaAlwaysBehind and "Behind" or teleportPosition
					if activePosition == "Above" then
						local pos = targetCFrame.Position + Vector3.new(0, kuramaTeleportDistance, 0)
						newCFrame = CFrame.lookAt(pos, targetCFrame.Position)
					elseif activePosition == "Below" then
						local pos = targetCFrame.Position + Vector3.new(0, -kuramaTeleportDistance, 0)
						newCFrame = CFrame.lookAt(pos, targetCFrame.Position)
					elseif activePosition == "Behind" then
						local pos = targetCFrame.Position + (targetCFrame.LookVector * -kuramaTeleportDistance)
						newCFrame = CFrame.lookAt(pos, targetCFrame.Position)
					else
						local pos = targetCFrame.Position + Vector3.new(0, kuramaTeleportDistance, 0)
						newCFrame = CFrame.lookAt(pos, targetCFrame.Position)
					end
				end
				
				local activeMovement = (kuramaAlwaysBehind and healthPercent >= kuramaSafetyThreshold) and "Instant" or movementMode
				
				if activeMovement == "Tween" then
					local currentPos = rootPart.Position
					local distance = (newCFrame.Position - currentPos).Magnitude
					local maxMove = tweenSpeed * deltaTime
					
					if distance > maxMove then
						local direction = (newCFrame.Position - currentPos).Unit
						local nextPos = currentPos + (direction * maxMove)
						rootPart.CFrame = CFrame.new(nextPos) * newCFrame.Rotation
					else
						rootPart.CFrame = newCFrame
					end
				else
					rootPart.CFrame = newCFrame
				end
				
				rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
				rootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
			end
		else
			wasKuramaAlive = false

			if os.clock() - lastKuramaSummonTime < 20 then
				return -- Wait in the arena for Kurama to spawn, don't teleport back to Totem
			end
			
			local mapFolder = workspace:FindFirstChild("Map")
			local totem = nil
			if mapFolder then
				local arenas = mapFolder:FindFirstChild("Arenas")
				if arenas and arenas:FindFirstChild("Boss") and arenas.Boss:FindFirstChild("KuramaArena") then
					totem = arenas.Boss.KuramaArena:FindFirstChild("Totem")
				end
			end
			
			if totem then
				local targetCFrame
				if totem:IsA("Model") then
					local part = totem.PrimaryPart or totem:FindFirstChildWhichIsA("BasePart")
					if part then targetCFrame = part.CFrame end
				elseif totem:IsA("BasePart") then
					targetCFrame = totem.CFrame
				else
					targetCFrame = totem:GetPivot()
				end
				
				if targetCFrame then
					local distance = (rootPart.Position - targetCFrame.Position).Magnitude
					
					if movementMode == "Tween" then
						local maxMove = tweenSpeed * deltaTime
						if distance > maxMove then
							local direction = (targetCFrame.Position - rootPart.Position).Unit
							local nextPos = rootPart.Position + (direction * maxMove)
							rootPart.CFrame = CFrame.new(nextPos) * targetCFrame.Rotation
						else
							rootPart.CFrame = targetCFrame
						end
					else
						rootPart.CFrame = targetCFrame
					end
					
					rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
					rootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
					
					if distance <= 15 then
						local prompt = totem:FindFirstChildWhichIsA("ProximityPrompt", true)
						if prompt then
							if type(fireproximityprompt) == "function" then
								pcall(function() fireproximityprompt(prompt, 1, true) end)
								pcall(function() fireproximityprompt(prompt) end)
							end
							
							VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
							task.delay(0.2, function()
								VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
							end)
							
							lastKuramaSummonTime = os.clock()
						end
					end
				end
			end
		end
		return -- Skip boss/mob farm while Kurama farm is active
	end

	if isBossAutoEnabled then
		if #bossWaypoints == 0 then return end
		
		local validBosses = {}
		for _, wp in ipairs(bossWaypoints) do
			if selectedBosses[wp.Name] then
				table.insert(validBosses, wp)
			end
		end
		
		if #validBosses == 0 then return end
		
		if currentBossIndex > #validBosses then
			currentBossIndex = 1
		end
		
		local targetWaypoint = validBosses[currentBossIndex]
		
		local foundEntity = nil
		
		-- Search ClientEntities for the boss model matching the waypoint's name
		for _, entity in ipairs(clientEntities:GetChildren()) do
			if entity.Name == targetWaypoint.Name then
				local humanoid = entity:FindFirstChildOfClass("Humanoid")
				if not humanoid or humanoid.Health > 0 then
					foundEntity = entity
					break
				end
			end
		end
		
		local targetCFrame
		local isFighting = false
		
		if foundEntity then
			targetCFrame = getTargetCFrame(foundEntity)
			isFighting = true
		else
			targetCFrame = CFrame.new(targetWaypoint.Position)
		end
		
		if targetCFrame then
			local newCFrame
			
			if teleportPosition == "Above" then
				local pos = targetCFrame.Position + Vector3.new(0, teleportDistance, 0)
				newCFrame = CFrame.lookAt(pos, targetCFrame.Position)
			elseif teleportPosition == "Below" then
				local pos = targetCFrame.Position + Vector3.new(0, -teleportDistance, 0)
				newCFrame = CFrame.lookAt(pos, targetCFrame.Position)
			elseif teleportPosition == "Behind" then
				local pos = targetCFrame.Position + (targetCFrame.LookVector * -teleportDistance)
				newCFrame = CFrame.lookAt(pos, targetCFrame.Position)
			else
				local pos = targetCFrame.Position + Vector3.new(0, teleportDistance, 0)
				newCFrame = CFrame.lookAt(pos, targetCFrame.Position)
			end
			
			if movementMode == "Tween" then
				local currentPos = rootPart.Position
				local distance = (newCFrame.Position - currentPos).Magnitude
				local maxMove = tweenSpeed * deltaTime
				
				if distance > maxMove then
					local direction = (newCFrame.Position - currentPos).Unit
					local nextPos = currentPos + (direction * maxMove)
					rootPart.CFrame = CFrame.new(nextPos) * newCFrame.Rotation
					lastBossVisitTime = os.clock()
				else
					rootPart.CFrame = newCFrame
					if not isFighting then
						if os.clock() - lastBossVisitTime >= spawnVisitDelay then
							currentBossIndex = currentBossIndex + 1
							lastBossVisitTime = os.clock()
						end
					else
						lastBossVisitTime = os.clock()
					end
				end
			else
				rootPart.CFrame = newCFrame
				if not isFighting then
					if os.clock() - lastBossVisitTime >= spawnVisitDelay then
						currentBossIndex = currentBossIndex + 1
						lastBossVisitTime = os.clock()
					end
				else
					lastBossVisitTime = os.clock()
				end
			end
			
			rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			rootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
		end
		
		return -- Skip normal mob farm while boss farm is active
	end

	if not isEnabled or #customWaypoints == 0 then return end
	
	local validWaypoints = {}
	for _, wp in ipairs(customWaypoints) do
		if selectedEntities[wp.Name] then
			table.insert(validWaypoints, wp)
		end
	end
	
	if #validWaypoints == 0 then return end
	
	if currentWaypointIndex > #validWaypoints then
		currentWaypointIndex = 1
	end
	
	local targetWaypoint = validWaypoints[currentWaypointIndex]
	
	-- Look for the specific mob at this waypoint
	local foundEntity = nil
	for _, entity in ipairs(clientEntities:GetChildren()) do
		if entity.Name == targetWaypoint.Name then
			local humanoid = entity:FindFirstChildOfClass("Humanoid")
			if not humanoid or humanoid.Health > 0 then
				foundEntity = entity
				break
			end
		end
	end
	
	local targetCFrame
	local isFighting = false
	
	if foundEntity then
		targetCFrame = getTargetCFrame(foundEntity)
		isFighting = true
	else
		targetCFrame = CFrame.new(targetWaypoint.Position)
	end
	
	if targetCFrame then
		local newCFrame
		
		if teleportPosition == "Above" then
			local pos = targetCFrame.Position + Vector3.new(0, teleportDistance, 0)
			newCFrame = CFrame.lookAt(pos, targetCFrame.Position)
		elseif teleportPosition == "Below" then
			local pos = targetCFrame.Position + Vector3.new(0, -teleportDistance, 0)
			newCFrame = CFrame.lookAt(pos, targetCFrame.Position)
		elseif teleportPosition == "Behind" then
			local pos = targetCFrame.Position + (targetCFrame.LookVector * -teleportDistance)
			newCFrame = CFrame.lookAt(pos, targetCFrame.Position)
		else
			local pos = targetCFrame.Position + Vector3.new(0, teleportDistance, 0)
			newCFrame = CFrame.lookAt(pos, targetCFrame.Position)
		end
		
		if movementMode == "Tween" then
			local currentPos = rootPart.Position
			local distance = (newCFrame.Position - currentPos).Magnitude
			local maxMove = tweenSpeed * deltaTime
			
			if distance > maxMove then
				local direction = (newCFrame.Position - currentPos).Unit
				local nextPos = currentPos + (direction * maxMove)
				rootPart.CFrame = CFrame.new(nextPos) * newCFrame.Rotation
				lastSpawnVisitTime = os.clock() -- Reset timer while moving
			else
				rootPart.CFrame = newCFrame
				if not isFighting then
					if os.clock() - lastSpawnVisitTime >= spawnVisitDelay then
						currentWaypointIndex = currentWaypointIndex + 1
						lastSpawnVisitTime = os.clock()
					end
				else
					lastSpawnVisitTime = os.clock() -- Keep timer reset while fighting
				end
			end
		else
			rootPart.CFrame = newCFrame
			if not isFighting then
				if os.clock() - lastSpawnVisitTime >= spawnVisitDelay then
					currentWaypointIndex = currentWaypointIndex + 1
					lastSpawnVisitTime = os.clock()
				end
			else
				lastSpawnVisitTime = os.clock()
			end
		end
		
		rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		rootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
	end
end)

-- ==========================================
-- BOSSES TAB
-- ==========================================

local BossToggle = Tabs.Bosses:AddToggle("BossToggle", {
	Title = "Enable Boss Auto Farm", 
	Default = false,
	Description = "Continuously teleports to selected bosses (overrides normal mob farm)"
})

BossToggle:OnChanged(function(Value)
	isBossAutoEnabled = Value
end)

local BossDropdown = Tabs.Bosses:AddDropdown("BossDropdown", {
	Title = "Select Boss Zones",
	Description = "Select boss zones to auto farm",
	Values = {},
	Multi = true,
	Default = {},
})

BossDropdown:OnChanged(function(Value)
	selectedBosses = Value
end)

-- Auto-load boss waypoints from URL
if BOSS_WAYPOINTS_URL ~= "" and BOSS_WAYPOINTS_URL ~= "PUT_YOUR_BOSS_JSON_URL_HERE" then
	task.spawn(function()
		local success, res = pcall(function()
			return game:HttpGet(BOSS_WAYPOINTS_URL)
		end)
		if success and res then
			local decodeSuccess, decoded = pcall(function()
				return HttpService:JSONDecode(res)
			end)
			if decodeSuccess and type(decoded) == "table" then
				bossWaypoints = {}
				local uniqueBossNames = {}
				local addedNames = {}
				
				for _, wp in ipairs(decoded) do
					if wp.X and wp.Y and wp.Z and wp.Name then
						table.insert(bossWaypoints, {Name = wp.Name, Position = Vector3.new(wp.X, wp.Y, wp.Z)})
						
						if not addedNames[wp.Name] then
							addedNames[wp.Name] = true
							table.insert(uniqueBossNames, wp.Name)
						end
					end
				end
				
				table.sort(uniqueBossNames)
				BossDropdown:SetValues(uniqueBossNames)
				
				Fluent:Notify({ Title = "Success", Content = "Loaded " .. #bossWaypoints .. " online boss waypoints!", Duration = 3 })
			else
				Fluent:Notify({ Title = "Error", Content = "Failed to parse online boss waypoints JSON.", Duration = 5 })
			end
		else
			Fluent:Notify({ Title = "Error", Content = "Failed to fetch online boss waypoints.", Duration = 5 })
		end
	end)
end

-- ==========================================
-- KURAMA TAB
-- ==========================================

local KuramaToggle = Tabs.Kurama:AddToggle("KuramaToggle", {
	Title = "Enable Auto Kurama", 
	Default = false,
	Description = "Continuously teleports to Kurama"
})

KuramaToggle:OnChanged(function(Value)
	isKuramaAutoEnabled = Value
end)

local KuramaBehindToggle = Tabs.Kurama:AddToggle("KuramaBehindToggle", {
	Title = "Always Behind (Auto Dodge)", 
	Default = false,
	Description = "Overrides settings to instantly teleport behind Kurama at all times."
})

KuramaBehindToggle:OnChanged(function(Value)
	kuramaAlwaysBehind = Value
end)

local KuramaDistanceSlider = Tabs.Kurama:AddSlider("KuramaDistanceSlider", {
	Title = "Attack Distance",
	Description = "Distance from Kurama",
	Default = 66,
	Min = 0,
	Max = 100,
	Rounding = 1,
	Callback = function(Value)
		kuramaTeleportDistance = Value
	end
})

KuramaDistanceSlider:OnChanged(function(Value)
	kuramaTeleportDistance = Value
end)

local KuramaDistanceInput = Tabs.Kurama:AddInput("KuramaDistanceInput", {
	Title = "Type Exact Attack Distance",
	Default = "66",
	Placeholder = "Enter distance...",
	Numeric = true,
	Finished = true,
	Callback = function(Value)
		local num = tonumber(Value)
		if num then
			kuramaTeleportDistance = num
			KuramaDistanceSlider:SetValue(num)
		end
	end
})

local KuramaHealthSlider = Tabs.Kurama:AddSlider("KuramaHealthSlider", {
	Title = "Safety Health Threshold (%)",
	Description = "If health drops below this %, teleports high above Kurama.",
	Default = 30,
	Min = 0,
	Max = 100,
	Rounding = 0,
	Callback = function(Value)
		kuramaSafetyThreshold = Value
	end
})

KuramaHealthSlider:OnChanged(function(Value)
	kuramaSafetyThreshold = Value
end)

local KuramaHighDistanceSlider = Tabs.Kurama:AddSlider("KuramaHighDistanceSlider", {
	Title = "Safety High Distance",
	Description = "How high to teleport when health is low.",
	Default = 150,
	Min = 50,
	Max = 1000,
	Rounding = 0,
	Callback = function(Value)
		kuramaHighDistance = Value
	end
})

KuramaHighDistanceSlider:OnChanged(function(Value)
	kuramaHighDistance = Value
end)

-- ==========================================
-- AUTO KEY TAB
-- ==========================================
local isAutoKeyEnabled = false
local autoKeyDelay = 0.1
local selectedKeys = {}

local AutoKeyToggle = Tabs.AutoKey:AddToggle("AutoKeyToggle", {
	Title = "Enable Auto Key", 
	Default = false 
})

AutoKeyToggle:OnChanged(function(Value)
	isAutoKeyEnabled = Value
end)

local alphabetList = {"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"}

local KeysDropdown = Tabs.AutoKey:AddDropdown("KeysDropdown", {
	Title = "Select Keys",
	Description = "Select which alphabet keys to auto press",
	Values = alphabetList,
	Multi = true,
	Default = {},
})

KeysDropdown:OnChanged(function(Value)
	selectedKeys = Value
end)

local KeyDelaySlider = Tabs.AutoKey:AddSlider("KeyDelaySlider", {
	Title = "Key Press Delay",
	Description = "Delay between each cycle of key presses (in seconds)",
	Default = 0.1,
	Min = 0.01,
	Max = 5,
	Rounding = 2,
	Callback = function(Value)
		autoKeyDelay = Value
	end
})

KeyDelaySlider:OnChanged(function(Value)
	autoKeyDelay = Value
end)

task.spawn(function()
	while true do
		if isAutoKeyEnabled then
			local pressedAny = false
			for key, isSelected in pairs(selectedKeys) do
				if isSelected then
					pressedAny = true
					local keyCode = Enum.KeyCode[key]
					if keyCode then
						VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
						task.wait(0.01)
						VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
					end
				end
			end
			if pressedAny then
				task.wait(autoKeyDelay)
			else
				task.wait(0.1)
			end
		else
			task.wait(0.1)
		end
	end
end)

-- ==========================================
-- FLOATING TOGGLE BUTTON
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "FluentToggleGui"
ScreenGui.ResetOnSpawn = false

local targetGui = (gethui and gethui()) or game:GetService("CoreGui")
local success = pcall(function() ScreenGui.Parent = targetGui end)
if not success then
	ScreenGui.Parent = player:WaitForChild("PlayerGui")
end

local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Parent = ScreenGui
ToggleBtn.Size = UDim2.new(0, 100, 0, 40)
ToggleBtn.Position = UDim2.new(0, 15, 0, 15)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.Text = "Toggle UI"
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.TextSize = 14
ToggleBtn.AutoButtonColor = true

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = ToggleBtn

local dragging = false
local dragStart = nil
local startPos = nil

ToggleBtn.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = ToggleBtn.Position
		
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
			end
		end)
	end
end)

ToggleBtn.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		if dragging then
			local delta = input.Position - dragStart
			ToggleBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end
end)

ToggleBtn.MouseButton1Click:Connect(function()
	VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.LeftControl, false, game)
	task.wait(0.01)
	VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.LeftControl, false, game)
end)

-- ==========================================
-- SAVE MANAGER (SETTINGS)
-- ==========================================
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})

InterfaceManager:SetFolder("AutoTeleportSettings")
SaveManager:SetFolder("AutoTeleportSettings/Configs")

InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)

SaveManager:LoadAutoloadConfig()
