local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer
local clientEntities = workspace:WaitForChild("ClientEntities")

local WAYPOINTS_URL = "https://raw.githubusercontent.com/Nacy69/afer/refs/heads/main/MobWaypoints.json" -- Replace with your raw JSON URL
local BOSS_WAYPOINTS_URL = "https://raw.githubusercontent.com/Nacy69/afer/refs/heads/main/BossWaypoints.json" -- Replace with your raw Boss JSON URL
local QUESTS_URL = "https://raw.githubusercontent.com/Nacy69/afer/refs/heads/main/Quests.json" -- Replace with your raw Quests JSON URL

local currentTarget = nil
local isEnabled = false
local selectedEntities = {}
local isCurrentlyFighting = false

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
	Training = Window:AddTab({ Title = "Training", Icon = "dumbbell" }),
	Bosses = Window:AddTab({ Title = "Bosses", Icon = "skull" }),
	Kurama = Window:AddTab({ Title = "Kurama", Icon = "box" }),
	Brole = Window:AddTab({ Title = "Brole", Icon = "box" }),
	Dungeon = Window:AddTab({ Title = "Dungeon", Icon = "swords" }),
	Quests = Window:AddTab({ Title = "Quests", Icon = "scroll" }),
	AutoKey = Window:AddTab({ Title = "Auto Key", Icon = "keyboard" }),
	AutoTitan = Window:AddTab({ Title = "Auto Titan", Icon = "zap" }),
	Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

-- ==========================================
-- TRAINING TAB SETUP
-- ==========================================
local autoEquipTool = "None"
local isAutoEquipEnabled = false
local isAutoTrainEnabled = false

local toolKeybinds = {
	["Strength"] = Enum.KeyCode.One,
	["Durability"] = Enum.KeyCode.Two,
	["Chakra"] = Enum.KeyCode.Three,
	["Sword"] = Enum.KeyCode.Four
}

local function equipSelectedTool()
	if isAutoEquipEnabled and autoEquipTool ~= "None" then
		local key = toolKeybinds[autoEquipTool]
		if key then
			-- Send the key press to equip the tool
			VirtualInputManager:SendKeyEvent(true, key, false, game)
			task.wait(0.1)
			VirtualInputManager:SendKeyEvent(false, key, false, game)
		end
	end
end

local AutoEquipToggle = Tabs.Training:AddToggle("AutoEquipToggle", {
	Title = "Enable Auto Equip",
	Default = false,
	Description = "Automatically equips the selected tool on spawn"
})

AutoEquipToggle:OnChanged(function(Value)
	isAutoEquipEnabled = Value
	if isAutoEquipEnabled then
		equipSelectedTool()
	end
end)

local AutoEquipDropdown = Tabs.Training:AddDropdown("AutoEquipDropdown", {
	Title = "Training Tool",
	Description = "Select the tool to auto-equip",
	Values = {"None", "Strength", "Durability", "Chakra", "Sword"},
	Multi = false,
	Default = 1,
})

AutoEquipDropdown:OnChanged(function(Value)
	autoEquipTool = Value
	if isAutoEquipEnabled then
		equipSelectedTool()
	end
end)

local AutoTrainToggle = Tabs.Training:AddToggle("AutoTrainToggle", {
	Title = "Enable Auto Train (Auto Click)",
	Default = false,
	Description = "Automatically clicks to train the equipped tool"
})

AutoTrainToggle:OnChanged(function(Value)
	isAutoTrainEnabled = Value
end)

player.CharacterAdded:Connect(function(char)
	task.spawn(function()
		char:WaitForChild("HumanoidRootPart", 10)
		task.wait(2) -- Wait for character to fully initialize
		equipSelectedTool()
	end)
end)

task.spawn(function()
	while task.wait(0.1) do
		if isAutoTrainEnabled then
			VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
			task.wait(0.05)
			VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
		end
	end
end)

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
	Max = 100,
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

-- Toggle for Auto Look Down
local isAutoLookDownEnabled = false
local LookDownToggle = Tabs.Main:AddToggle("LookDownToggle", {
	Title = "Auto Look Down", 
	Default = false,
	Description = "Automatically points your camera straight down to reduce lag"
})

LookDownToggle:OnChanged(function(Value)
	isAutoLookDownEnabled = Value
end)

local isAimLockEnabled = false
local AimLockToggle = Tabs.Main:AddToggle("AimLockToggle", {
	Title = "Auto Aim Lock", 
	Default = false,
	Description = "Automatically locks camera to the target you are fighting"
})

AimLockToggle:OnChanged(function(Value)
	isAimLockEnabled = Value
end)

RunService.RenderStepped:Connect(function()
	if isAutoLookDownEnabled then
		local camera = workspace.CurrentCamera
		if camera and player.Character then
			-- Look straight down from current camera position
			local currentPos = camera.CFrame.Position
			camera.CFrame = CFrame.new(currentPos, currentPos + Vector3.new(0, -1, 0))
		end
	end
end)

local HttpService = game:GetService("HttpService")

local currentWaypointIndex = 1
local lastSpawnVisitTime = 0
local spawnVisitDelay = 0.1
local customWaypoints = {}
local bossWaypoints = {}
-- ==========================================
-- AUTO TITAN STATE
-- ==========================================
local isAutoTitanEnabled = false
-- These are the only two targets. No config needed — pure carnage.
local TITAN_TARGETS = { ["FoundingTitan"] = true, ["RumblingColossal"] = true }
local titanTeleportDistance = 5
local titanTeleportPosition = "Above"
local titanMovementMode = "Tween"
local isTitanSkillEnabled = false
local titanSkillKeys = {}
local titanSkillDelay = 0.1

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
local kuramaAimLock = false

local kuramaPriorityBosses = {["Igros"] = true}

local isBroleAutoEnabled = false
local broleSafetyThreshold = 30
local broleHighDistance = 100
local broleAlwaysBehind = false
local broleTeleportDistance = 5
local lastBroleSummonTime = 0
local broleSpawnTime = 0
local wasBroleAlive = false
local broleAimLock = false

local brolePriorityBosses = {["Igros"] = true}
local isDungeonAutoEnabled = false
local lastDungeonEnterTime = 0
local lastDungeonTimeLeftText = ""
local lastDungeonTimeLeftChangeTime = 0
local lastDungeonStartClickTime = 0
local dungeonSafetyThreshold = 0
local dungeonSafeDistance = 50

local isAutoQuestEnabled = false
local lastQuestClickTime = 0
local loadedQuests = {}
local selectedQuest = nil

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
	isCurrentlyFighting = false

	-- ══════════════════════════════════════════
	-- AUTO TITAN — ABSOLUTE HIGHEST PRIORITY
	-- Kills FoundingTitan & RumblingColossal first,
	-- no questions asked, everything else can wait.
	-- ══════════════════════════════════════════
	if isAutoTitanEnabled then
		local character = player.Character
		if character then
			local rootPart = character:FindFirstChild("HumanoidRootPart")
			if rootPart then
				local titanTarget = nil
				-- Scan ClientEntities for any living titan target
				for _, entity in ipairs(clientEntities:GetChildren()) do
					if TITAN_TARGETS[entity.Name] then
						local humanoid = entity:FindFirstChildOfClass("Humanoid")
						if not humanoid or humanoid.Health > 0 then
							titanTarget = entity
							break
						end
					end
				end
				
				if titanTarget then
					local targetCFrame = getTargetCFrame(titanTarget)
					if targetCFrame then
						isCurrentlyFighting = true
						local pos
						if titanTeleportPosition == "Above" then
							pos = targetCFrame.Position + Vector3.new(0, titanTeleportDistance, 0)
						elseif titanTeleportPosition == "Below" then
							pos = targetCFrame.Position + Vector3.new(0, -titanTeleportDistance, 0)
						elseif titanTeleportPosition == "Behind" then
							pos = targetCFrame.Position + (targetCFrame.LookVector * -titanTeleportDistance)
						else
							pos = targetCFrame.Position + Vector3.new(0, titanTeleportDistance, 0)
						end
						local newCFrame = CFrame.lookAt(pos, targetCFrame.Position)
						
						if titanMovementMode == "Tween" then
							local currentPos = rootPart.Position
							local dist = (newCFrame.Position - currentPos).Magnitude
							local maxMove = tweenSpeed * deltaTime
							if dist > maxMove then
								local dir = (newCFrame.Position - currentPos).Unit
								rootPart.CFrame = CFrame.new(currentPos + dir * maxMove) * newCFrame.Rotation
							else
								rootPart.CFrame = newCFrame
							end
						else
							rootPart.CFrame = newCFrame
						end
						
						rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
						rootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
						return -- nuke everything else this frame
					end
				end
			end
		end
	end
	-- ══════════════════════════════════════════
	local character = player.Character
	if not character then return end
	
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end
	
	if isKuramaAutoEnabled then
		-- Check for Priority Bosses
		local priorityTargetCFrame = nil
		local isPriorityFighting = false
		
		for bossName, isEnabled in pairs(kuramaPriorityBosses) do
			if isEnabled then
				local scrollingFrame = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Boards") and workspace.Map.Boards:FindFirstChild("BossRates") and workspace.Map.Boards.BossRates:FindFirstChild("Board") and workspace.Map.Boards.BossRates.Board:FindFirstChild("Display") and workspace.Map.Boards.BossRates.Board.Display:FindFirstChild("ScrollingFrame")
				
				if scrollingFrame and scrollingFrame:FindFirstChild(bossName) and scrollingFrame[bossName]:FindFirstChild("Time") then
					local timeLabel = scrollingFrame[bossName].Time
					if timeLabel:IsA("TextLabel") and timeLabel.Text == "Spawned" then
						local bossEntity = clientEntities:FindFirstChild(bossName)
						if bossEntity then
							local humanoid = bossEntity:FindFirstChildOfClass("Humanoid")
							if not humanoid or humanoid.Health > 0 then
								priorityTargetCFrame = getTargetCFrame(bossEntity)
								isPriorityFighting = true
							end
						end
						
						if not priorityTargetCFrame then
							-- Teleport to waypoint first so boss can render
							local bossWaypoint = nil
							for _, wp in ipairs(bossWaypoints) do
								if wp.Name == bossName then bossWaypoint = wp break end
							end
							if not bossWaypoint then
								for _, wp in ipairs(customWaypoints) do
									if wp.Name == bossName then bossWaypoint = wp break end
								end
							end
							
							if bossWaypoint then
								priorityTargetCFrame = CFrame.new(bossWaypoint.Position)
							end
						end
						
						if priorityTargetCFrame then
							break -- Found a spawned priority boss, break loop to go to it
						end
					end
				end
			end
		end
		
		if priorityTargetCFrame then
			isCurrentlyFighting = isPriorityFighting
			local newCFrame
			if isPriorityFighting then
				local activePosition = teleportPosition
				if activePosition == "Above" then
					local pos = priorityTargetCFrame.Position + Vector3.new(0, teleportDistance, 0)
					newCFrame = CFrame.lookAt(pos, priorityTargetCFrame.Position)
				elseif activePosition == "Below" then
					local pos = priorityTargetCFrame.Position + Vector3.new(0, -teleportDistance, 0)
					newCFrame = CFrame.lookAt(pos, priorityTargetCFrame.Position)
				elseif activePosition == "Behind" then
					local pos = priorityTargetCFrame.Position + (priorityTargetCFrame.LookVector * -teleportDistance)
					newCFrame = CFrame.lookAt(pos, priorityTargetCFrame.Position)
				else
					local pos = priorityTargetCFrame.Position + Vector3.new(0, teleportDistance, 0)
					newCFrame = CFrame.lookAt(pos, priorityTargetCFrame.Position)
				end
			else
				newCFrame = priorityTargetCFrame
			end
			
			if movementMode == "Tween" then
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
			return -- Skip Kurama logic entirely for this frame while finding/fighting priority boss
		end

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
				isCurrentlyFighting = true
				local playerHumanoid = character:FindFirstChildOfClass("Humanoid")
				local healthPercent = playerHumanoid and (playerHumanoid.Health / playerHumanoid.MaxHealth) * 100 or 100
				
				local newCFrame
				local currentDistance = (healthPercent < kuramaSafetyThreshold) and kuramaHighDistance or kuramaTeleportDistance
				local activePosition = kuramaAlwaysBehind and "Behind" or teleportPosition
				
				if activePosition == "Above" then
					local pos = targetCFrame.Position + Vector3.new(0, currentDistance, 0)
					newCFrame = CFrame.lookAt(pos, targetCFrame.Position)
				elseif activePosition == "Below" then
					local pos = targetCFrame.Position + Vector3.new(0, -currentDistance, 0)
					newCFrame = CFrame.lookAt(pos, targetCFrame.Position)
				elseif activePosition == "Behind" then
					local pos = targetCFrame.Position + (targetCFrame.LookVector * -currentDistance)
					newCFrame = CFrame.lookAt(pos, targetCFrame.Position)
				else
					local pos = targetCFrame.Position + Vector3.new(0, currentDistance, 0)
					newCFrame = CFrame.lookAt(pos, targetCFrame.Position)
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
				
				-- Camera aim lock: always face Kurama
				if kuramaAimLock then
					local camera = workspace.CurrentCamera
					if camera then
						camera.CFrame = CFrame.lookAt(camera.CFrame.Position, targetCFrame.Position)
					end
				end
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

	if isBroleAutoEnabled then
		-- Check for Priority Bosses
		local priorityTargetCFrame = nil
		local isPriorityFighting = false
		
		for bossName, isEnabled in pairs(brolePriorityBosses) do
			if isEnabled then
				local scrollingFrame = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Boards") and workspace.Map.Boards:FindFirstChild("BossRates") and workspace.Map.Boards.BossRates:FindFirstChild("Board") and workspace.Map.Boards.BossRates.Board:FindFirstChild("Display") and workspace.Map.Boards.BossRates.Board.Display:FindFirstChild("ScrollingFrame")
				
				if scrollingFrame and scrollingFrame:FindFirstChild(bossName) and scrollingFrame[bossName]:FindFirstChild("Time") then
					local timeLabel = scrollingFrame[bossName].Time
					if timeLabel:IsA("TextLabel") and timeLabel.Text == "Spawned" then
						local bossEntity = clientEntities:FindFirstChild(bossName)
						if bossEntity then
							local humanoid = bossEntity:FindFirstChildOfClass("Humanoid")
							if not humanoid or humanoid.Health > 0 then
								priorityTargetCFrame = getTargetCFrame(bossEntity)
								isPriorityFighting = true
							end
						end
						
						if not priorityTargetCFrame then
							-- Teleport to waypoint first so boss can render
							local bossWaypoint = nil
							for _, wp in ipairs(bossWaypoints) do
								if wp.Name == bossName then bossWaypoint = wp break end
							end
							if not bossWaypoint then
								for _, wp in ipairs(customWaypoints) do
									if wp.Name == bossName then bossWaypoint = wp break end
								end
							end
							
							if bossWaypoint then
								priorityTargetCFrame = CFrame.new(bossWaypoint.Position)
							end
						end
						
						if priorityTargetCFrame then
							break -- Found a spawned priority boss, break loop to go to it
						end
					end
				end
			end
		end
		
		if priorityTargetCFrame then
			isCurrentlyFighting = isPriorityFighting
			local newCFrame
			if isPriorityFighting then
				local activePosition = teleportPosition
				if activePosition == "Above" then
					local pos = priorityTargetCFrame.Position + Vector3.new(0, teleportDistance, 0)
					newCFrame = CFrame.lookAt(pos, priorityTargetCFrame.Position)
				elseif activePosition == "Below" then
					local pos = priorityTargetCFrame.Position + Vector3.new(0, -teleportDistance, 0)
					newCFrame = CFrame.lookAt(pos, priorityTargetCFrame.Position)
				elseif activePosition == "Behind" then
					local pos = priorityTargetCFrame.Position + (priorityTargetCFrame.LookVector * -teleportDistance)
					newCFrame = CFrame.lookAt(pos, priorityTargetCFrame.Position)
				else
					local pos = priorityTargetCFrame.Position + Vector3.new(0, teleportDistance, 0)
					newCFrame = CFrame.lookAt(pos, priorityTargetCFrame.Position)
				end
			else
				newCFrame = priorityTargetCFrame
			end
			
			if movementMode == "Tween" then
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
			return -- Skip Brole logic entirely for this frame while finding/fighting priority boss
		end

		local brole = clientEntities:FindFirstChild("Brole")
		local isBroleAlive = false
		if brole then
			local humanoid = brole:FindFirstChildOfClass("Humanoid")
			if not humanoid or humanoid.Health > 0 then
				isBroleAlive = true
			end
		end

		if isBroleAlive then
			if not wasBroleAlive then
				broleSpawnTime = os.clock()
				wasBroleAlive = true
			end

			if os.clock() - broleSpawnTime < 3 then
				return -- Wait 3 seconds before locking on
			end

			local humanoid = brole:FindFirstChildOfClass("Humanoid")
			local targetCFrame = getTargetCFrame(brole)
			if targetCFrame then
				isCurrentlyFighting = true
				local playerHumanoid = character:FindFirstChildOfClass("Humanoid")
				local healthPercent = playerHumanoid and (playerHumanoid.Health / playerHumanoid.MaxHealth) * 100 or 100
				
				local newCFrame
				local currentDistance = (healthPercent < broleSafetyThreshold) and broleHighDistance or broleTeleportDistance
				local activePosition = broleAlwaysBehind and "Behind" or teleportPosition
				
				if activePosition == "Above" then
					local pos = targetCFrame.Position + Vector3.new(0, currentDistance, 0)
					newCFrame = CFrame.lookAt(pos, targetCFrame.Position)
				elseif activePosition == "Below" then
					local pos = targetCFrame.Position + Vector3.new(0, -currentDistance, 0)
					newCFrame = CFrame.lookAt(pos, targetCFrame.Position)
				elseif activePosition == "Behind" then
					local pos = targetCFrame.Position + (targetCFrame.LookVector * -currentDistance)
					newCFrame = CFrame.lookAt(pos, targetCFrame.Position)
				else
					local pos = targetCFrame.Position + Vector3.new(0, currentDistance, 0)
					newCFrame = CFrame.lookAt(pos, targetCFrame.Position)
				end
				
				local activeMovement = (broleAlwaysBehind and healthPercent >= broleSafetyThreshold) and "Instant" or movementMode
				
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
				
				-- Camera aim lock: always face Brole
				if broleAimLock then
					local camera = workspace.CurrentCamera
					if camera then
						camera.CFrame = CFrame.lookAt(camera.CFrame.Position, targetCFrame.Position)
					end
				end
			end
		else
			wasBroleAlive = false

			if os.clock() - lastBroleSummonTime < 20 then
				return -- Wait in the arena for Brole to spawn, don't teleport back to Totem
			end
			
			local mapFolder = workspace:FindFirstChild("Map")
			local totem = nil
			if mapFolder then
				local arenas = mapFolder:FindFirstChild("Arenas")
				if arenas and arenas:FindFirstChild("Boss") and arenas.Boss:FindFirstChild("BroleArena") then
					totem = arenas.Boss.BroleArena:FindFirstChild("Totem")
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
							
							lastBroleSummonTime = os.clock()
						end
					end
				end
			end
		end
		return -- Skip boss/mob farm while Brole farm is active
	end

	if isDungeonAutoEnabled then
		local mapFolder = workspace:FindFirstChild("Map")
		local interactive = mapFolder and mapFolder:FindFirstChild("Interactive")
		local dungeonGate = interactive and interactive:FindFirstChild("DungeonGate")
		
		if dungeonGate then
			if os.clock() - lastDungeonEnterTime > 5 then
				lastDungeonEnterTime = os.clock()
				
				local targetCFrame
				if dungeonGate:IsA("Model") then
					local root = dungeonGate.PrimaryPart or dungeonGate:FindFirstChildWhichIsA("BasePart")
					if root then targetCFrame = root.CFrame end
				elseif dungeonGate:IsA("BasePart") then
					targetCFrame = dungeonGate.CFrame
				end
				
				if targetCFrame then
					rootPart.CFrame = targetCFrame
					rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
					rootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
					
					local prompt = dungeonGate:FindFirstChildWhichIsA("ProximityPrompt", true)
					if prompt then
						if type(fireproximityprompt) == "function" then
							pcall(function() fireproximityprompt(prompt, 1, true) end)
							pcall(function() fireproximityprompt(prompt) end)
						end
						VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
						task.delay(0.2, function()
							VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
						end)
					end
					
					task.delay(1, function()
						local playerGui = player:FindFirstChild("PlayerGui")
						if not playerGui then return end
						
						local function fireClick(guiElement)
							if guiElement then
								pcall(function()
									if guiElement.AbsoluteSize and guiElement.AbsolutePosition then
										local x = guiElement.AbsolutePosition.X + (guiElement.AbsoluteSize.X / 2)
										local y = guiElement.AbsolutePosition.Y + (guiElement.AbsoluteSize.Y / 2) + 58
										VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
										task.wait(0.05)
										VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
									end
								end)
							end
						end
						
						local main = playerGui:FindFirstChild("Main")
						local pages = main and main:FindFirstChild("Pages")
						local dungeon = pages and pages:FindFirstChild("Dungeon")
						
						if dungeon then
							local creation = dungeon:FindFirstChild("Creation")
							local jeju = creation and creation:FindFirstChild("Page") and creation.Page:FindFirstChild("Main") and creation.Page.Main:FindFirstChild("Dungeons") and creation.Page.Main.Dungeons:FindFirstChild("Main") and creation.Page.Main.Dungeons.Main:FindFirstChild("List") and creation.Page.Main.Dungeons.Main.List:FindFirstChild("JejuIsland")
							if jeju then fireClick(jeju) end
							
							task.wait(0.5)
							
							local selection = dungeon:FindFirstChild("Selection")
							local hard = selection and selection:FindFirstChild("Page") and selection.Page:FindFirstChild("Main") and selection.Page.Main:FindFirstChild("Difficulty") and selection.Page.Main.Difficulty:FindFirstChild("Frame") and selection.Page.Main.Difficulty.Frame:FindFirstChild("Hard")
							if hard then fireClick(hard) end
							
							task.wait(0.5)
							
							local skipBtn = selection and selection:FindFirstChild("Page") and selection.Page:FindFirstChild("Main") and selection.Page.Main:FindFirstChild("Interact") and selection.Page.Main.Interact:FindFirstChild("Options") and selection.Page.Main.Interact.Options:FindFirstChild("SkipButton")
							if skipBtn then fireClick(skipBtn) end
						end
					end)
				end
			end
		else
			local playerGui = player:FindFirstChild("PlayerGui")
			local isDungeonStarted = false
			
			if playerGui then
				local main = playerGui:FindFirstChild("Main")
				local hud = main and main:FindFirstChild("HUD")
				local dungeonTimer = hud and hud:FindFirstChild("DungeonTimer")
				local timeLeft = dungeonTimer and dungeonTimer:FindFirstChild("TimeLeft")
				
				if timeLeft and timeLeft:IsA("TextLabel") then
					if timeLeft.Text ~= lastDungeonTimeLeftText then
						lastDungeonTimeLeftText = timeLeft.Text
						lastDungeonTimeLeftChangeTime = os.clock()
					end
					-- If the text changed within the last 2 seconds, assume the dungeon has started.
					if (os.clock() - lastDungeonTimeLeftChangeTime) < 2 then
						isDungeonStarted = true
					end
				end
			end
			
			if not isDungeonStarted then
				if os.clock() - lastDungeonStartClickTime > 1.5 then
					lastDungeonStartClickTime = os.clock()
					if playerGui then
						local main = playerGui:FindFirstChild("Main")
						local pages = main and main:FindFirstChild("Pages")
						local dungeon = pages and pages:FindFirstChild("Dungeon")
						local info = dungeon and dungeon:FindFirstChild("Info")
						local page = info and info:FindFirstChild("Page")
						local options = page and page:FindFirstChild("Options")
						local startBtn = options and options:FindFirstChild("StartButton")
						
						if startBtn then
							pcall(function()
								if startBtn.AbsoluteSize and startBtn.AbsolutePosition then
									local x = startBtn.AbsolutePosition.X + (startBtn.AbsoluteSize.X / 2)
									local y = startBtn.AbsolutePosition.Y + (startBtn.AbsoluteSize.Y / 2) + 58
									VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
									task.wait(0.05)
									VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
								end
							end)
						end
					end
				end
			else
				local foundEntity = nil
				
				for _, entity in ipairs(clientEntities:GetChildren()) do
					local humanoid = entity:FindFirstChildOfClass("Humanoid")
					if not humanoid or humanoid.Health > 0 then
						foundEntity = entity
						break
					end
				end
				
				if foundEntity then
					local targetCFrame = getTargetCFrame(foundEntity)
					if targetCFrame then
						isCurrentlyFighting = true
						
						local playerHumanoid = character:FindFirstChildOfClass("Humanoid")
						local healthPercent = playerHumanoid and (playerHumanoid.Health / playerHumanoid.MaxHealth) * 100 or 100
						local currentTeleportDistance = (dungeonSafetyThreshold > 0 and healthPercent <= dungeonSafetyThreshold) and dungeonSafeDistance or teleportDistance
						
						local newCFrame
						
						if teleportPosition == "Above" then
							local pos = targetCFrame.Position + Vector3.new(0, currentTeleportDistance, 0)
							newCFrame = CFrame.lookAt(pos, targetCFrame.Position)
						elseif teleportPosition == "Below" then
							local pos = targetCFrame.Position + Vector3.new(0, -currentTeleportDistance, 0)
							newCFrame = CFrame.lookAt(pos, targetCFrame.Position)
						elseif teleportPosition == "Behind" then
							local pos = targetCFrame.Position + (targetCFrame.LookVector * -currentTeleportDistance)
							newCFrame = CFrame.lookAt(pos, targetCFrame.Position)
						else
							local pos = targetCFrame.Position + Vector3.new(0, currentTeleportDistance, 0)
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
							else
								rootPart.CFrame = newCFrame
							end
						else
							rootPart.CFrame = newCFrame
						end
						
						rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
						rootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
					end
				end
			end
		end
		
		return -- Skip boss/mob farm while dungeon farm is active
	end

	if isAutoQuestEnabled and selectedQuest then
		local playerGui = player:FindFirstChild("PlayerGui")
		local questProgress = playerGui and playerGui:FindFirstChild("Main") and playerGui.Main:FindFirstChild("HUD") and playerGui.Main.HUD:FindFirstChild("QuestTracker") and playerGui.Main.HUD.QuestTracker:FindFirstChild("Main") and playerGui.Main.HUD.QuestTracker.Main:FindFirstChild("Holder") and playerGui.Main.HUD.QuestTracker.Main.Holder:FindFirstChild("List") and playerGui.Main.HUD.QuestTracker.Main.Holder.List:FindFirstChild(selectedQuest.TrackerFolder) and playerGui.Main.HUD.QuestTracker.Main.Holder.List[selectedQuest.TrackerFolder]:FindFirstChild("QuestBar") and playerGui.Main.HUD.QuestTracker.Main.Holder.List[selectedQuest.TrackerFolder].QuestBar:FindFirstChild("QuestBarProgressAmount")
		
		local hasCompletedQuest = false
		local hasQuest = false

		if questProgress and questProgress:IsA("TextLabel") then
			hasQuest = true
			if questProgress.ContentText:find("100%%") or questProgress.Text:find("100%%") then
				hasCompletedQuest = true
			end
		end
		
		if not hasQuest or hasCompletedQuest then
			local npc = workspace:FindFirstChild("Quests") and workspace.Quests:FindFirstChild(selectedQuest.NPCName)
			if npc then
				local targetCFrame
				if npc:IsA("Model") then
					local root = npc.PrimaryPart or npc:FindFirstChildWhichIsA("BasePart")
					if root then targetCFrame = root.CFrame * CFrame.new(3, 0, 0) end
				elseif npc:IsA("BasePart") then
					targetCFrame = npc.CFrame * CFrame.new(3, 0, 0)
				end
				
				if targetCFrame then
					rootPart.CFrame = targetCFrame
					rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
					rootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
					
					if os.clock() - lastQuestClickTime > 2 then
						lastQuestClickTime = os.clock()
						
						local prompt = npc:FindFirstChildWhichIsA("ProximityPrompt", true)
						if prompt then
							if type(fireproximityprompt) == "function" then
								pcall(function() fireproximityprompt(prompt, 1, true) end)
								pcall(function() fireproximityprompt(prompt) end)
							end
						end
						VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
						task.delay(0.2, function()
							VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
						end)
						
						task.delay(0.5, function()
							local dialogueOptions = playerGui and playerGui:FindFirstChild("Main") and playerGui.Main:FindFirstChild("HUD") and playerGui.Main.HUD:FindFirstChild("Dialogue") and playerGui.Main.HUD.Dialogue:FindFirstChild("Options")
							if dialogueOptions then
								for _, opt in ipairs(dialogueOptions:GetChildren()) do
									local main = opt:FindFirstChild("Main")
									local label = main and main:FindFirstChild("Label")
									if label and label:IsA("TextLabel") and (label.Text == selectedQuest.DialogueOption or label.ContentText == selectedQuest.DialogueOption) then
										local x = label.AbsolutePosition.X + (label.AbsoluteSize.X / 2)
										local y = label.AbsolutePosition.Y + (label.AbsoluteSize.Y / 2) + 58
										VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
										task.wait(0.05)
										VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
										break
									end
								end
								task.wait(0.5)
								local template = dialogueOptions:FindFirstChild("Template")
								local mainFrame = template and template:FindFirstChild("Main")
								local label = mainFrame and mainFrame:FindFirstChild("Label")
								if label and label:IsA("TextLabel") and (label.Text == "Accept" or label.ContentText == "Accept") then
									local x = label.AbsolutePosition.X + (label.AbsoluteSize.X / 2)
									local y = label.AbsolutePosition.Y + (label.AbsoluteSize.Y / 2) + 58
									VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
									task.wait(0.05)
									VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
								end
							end
						end)
					end
				end
			end
		else
			local foundEntity = nil
			for _, entity in ipairs(clientEntities:GetChildren()) do
				if entity.Name == selectedQuest.TargetMob then
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
				isCurrentlyFighting = true
			else
				local destWaypoint = nil
				for _, wp in ipairs(customWaypoints) do
					if wp.Name == selectedQuest.TargetMob then
						destWaypoint = wp
						break
					end
				end
				if destWaypoint then
					targetCFrame = CFrame.new(destWaypoint.Position)
				end
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
					else
						rootPart.CFrame = newCFrame
					end
				else
					rootPart.CFrame = newCFrame
				end
				
				rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
				rootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
			end
		end
		
		return -- Skip boss/mob farm while Auto Quest is active
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
			isCurrentlyFighting = true
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

			if isAimLockEnabled and isFighting and targetCFrame then
				local camera = workspace.CurrentCamera
				if camera then
					camera.CFrame = CFrame.lookAt(camera.CFrame.Position, targetCFrame.Position)
				end
			end
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
		isCurrentlyFighting = true
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

		if isAimLockEnabled and isFighting and targetCFrame then
			local camera = workspace.CurrentCamera
			if camera then
				camera.CFrame = CFrame.lookAt(camera.CFrame.Position, targetCFrame.Position)
			end
		end
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

local KuramaBossPriorityDropdown = Tabs.Kurama:AddDropdown("KuramaBossPriorityDropdown", {
	Title = "Prioritize Bosses",
	Description = "Stops Kurama farm to kill selected bosses if they spawn, then returns.",
	Values = {"Igros", "Puya", "GreatApe", "Crocodile", "ArmoredTitan"},
	Multi = true,
	Default = {"Igros"},
})

KuramaBossPriorityDropdown:OnChanged(function(Value)
	kuramaPriorityBosses = Value
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

local KuramaPressEToggle = Tabs.Kurama:AddToggle("KuramaPressEToggle", {
	Title = "Always Press E", 
	Default = true,
	Description = "Automatically presses E while Kurama farm is on."
})

local kuramaAlwaysPressE = true
KuramaPressEToggle:OnChanged(function(Value)
	kuramaAlwaysPressE = Value
end)

local KuramaAimLockToggle = Tabs.Kurama:AddToggle("KuramaAimLockToggle", {
	Title = "Camera Aim Lock", 
	Default = false,
	Description = "Locks camera to always face Kurama while farming."
})

KuramaAimLockToggle:OnChanged(function(Value)
	kuramaAimLock = Value
end)

task.spawn(function()
	while true do
		if isKuramaAutoEnabled and kuramaAlwaysPressE then
			VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
			task.wait(0.01)
			VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
			task.wait(0.1)
		else
			task.wait(0.1)
		end
	end
end)

-- ==========================================
-- BROLE TAB
-- ==========================================

local BroleToggle = Tabs.Brole:AddToggle("BroleToggle", {
	Title = "Enable Auto Brole", 
	Default = false,
	Description = "Continuously teleports to Brole"
})

BroleToggle:OnChanged(function(Value)
	isBroleAutoEnabled = Value
end)

local BroleBossPriorityDropdown = Tabs.Brole:AddDropdown("BroleBossPriorityDropdown", {
	Title = "Prioritize Bosses",
	Description = "Stops Brole farm to kill selected bosses if they spawn, then returns.",
	Values = {"Igros", "Puya", "GreatApe", "Crocodile", "ArmoredTitan"},
	Multi = true,
	Default = {"Igros"},
})

BroleBossPriorityDropdown:OnChanged(function(Value)
	brolePriorityBosses = Value
end)

local BroleBehindToggle = Tabs.Brole:AddToggle("BroleBehindToggle", {
	Title = "Always Behind (Auto Dodge)", 
	Default = false,
	Description = "Overrides settings to instantly teleport behind Brole at all times."
})

BroleBehindToggle:OnChanged(function(Value)
	broleAlwaysBehind = Value
end)

local BroleDistanceSlider = Tabs.Brole:AddSlider("BroleDistanceSlider", {
	Title = "Attack Distance",
	Description = "Distance from Brole",
	Default = 66,
	Min = 0,
	Max = 100,
	Rounding = 1,
	Callback = function(Value)
		broleTeleportDistance = Value
	end
})

BroleDistanceSlider:OnChanged(function(Value)
	broleTeleportDistance = Value
end)

local BroleDistanceInput = Tabs.Brole:AddInput("BroleDistanceInput", {
	Title = "Type Exact Attack Distance",
	Default = "66",
	Placeholder = "Enter distance...",
	Numeric = true,
	Finished = true,
	Callback = function(Value)
		local num = tonumber(Value)
		if num then
			broleTeleportDistance = num
			BroleDistanceSlider:SetValue(num)
		end
	end
})

local BroleHealthSlider = Tabs.Brole:AddSlider("BroleHealthSlider", {
	Title = "Safety Health Threshold (%)",
	Description = "If health drops below this %, teleports high above Brole.",
	Default = 30,
	Min = 0,
	Max = 100,
	Rounding = 0,
	Callback = function(Value)
		broleSafetyThreshold = Value
	end
})

BroleHealthSlider:OnChanged(function(Value)
	broleSafetyThreshold = Value
end)

local BroleHighDistanceSlider = Tabs.Brole:AddSlider("BroleHighDistanceSlider", {
	Title = "Safety High Distance",
	Description = "How high to teleport when health is low.",
	Default = 150,
	Min = 50,
	Max = 1000,
	Rounding = 0,
	Callback = function(Value)
		broleHighDistance = Value
	end
})

BroleHighDistanceSlider:OnChanged(function(Value)
	broleHighDistance = Value
end)

local BrolePressEToggle = Tabs.Brole:AddToggle("BrolePressEToggle", {
	Title = "Always Press E", 
	Default = true,
	Description = "Automatically presses E while Brole farm is on."
})

local broleAlwaysPressE = true
BrolePressEToggle:OnChanged(function(Value)
	broleAlwaysPressE = Value
end)

local BroleAimLockToggle = Tabs.Brole:AddToggle("BroleAimLockToggle", {
	Title = "Camera Aim Lock", 
	Default = false,
	Description = "Locks camera to always face Brole while farming."
})

BroleAimLockToggle:OnChanged(function(Value)
	broleAimLock = Value
end)

task.spawn(function()
	while true do
		if isBroleAutoEnabled and broleAlwaysPressE then
			VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
			task.wait(0.01)
			VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
			task.wait(0.1)
		else
			task.wait(0.1)
		end
	end
end)

-- ==========================================
-- DUNGEON TAB
-- ==========================================

local DungeonToggle = Tabs.Dungeon:AddToggle("DungeonToggle", {
	Title = "Enable Auto Dungeon", 
	Default = false,
	Description = "Continuously teleports to ALL entities in ClientEntities"
})

DungeonToggle:OnChanged(function(Value)
	isDungeonAutoEnabled = Value
end)

local DungeonHealthSlider = Tabs.Dungeon:AddSlider("DungeonHealthSlider", {
	Title = "Safety Health Threshold (%)",
	Description = "If health drops below this %, changes attack distance. Set to 0 to disable.",
	Default = 0,
	Min = 0,
	Max = 100,
	Rounding = 0,
	Callback = function(Value)
		dungeonSafetyThreshold = Value
	end
})

DungeonHealthSlider:OnChanged(function(Value)
	dungeonSafetyThreshold = Value
end)

local DungeonSafeDistanceSlider = Tabs.Dungeon:AddSlider("DungeonSafeDistanceSlider", {
	Title = "Safety Distance",
	Description = "Distance to use when health is low.",
	Default = 50,
	Min = 0,
	Max = 200,
	Rounding = 1,
	Callback = function(Value)
		dungeonSafeDistance = Value
	end
})

DungeonSafeDistanceSlider:OnChanged(function(Value)
	dungeonSafeDistance = Value
end)

-- ==========================================
-- QUESTS TAB
-- ==========================================

local QuestToggle = Tabs.Quests:AddToggle("QuestToggle", {
	Title = "Enable Auto Quest", 
	Default = false,
	Description = "Auto fetches and farms the selected quest."
})

QuestToggle:OnChanged(function(Value)
	isAutoQuestEnabled = Value
end)

local QuestDropdown = Tabs.Quests:AddDropdown("QuestDropdown", {
	Title = "Select Quest",
	Description = "Select which quest to auto complete",
	Values = {},
	Multi = false,
	Default = 1,
})

QuestDropdown:OnChanged(function(Value)
	if loadedQuests[Value] then
		selectedQuest = loadedQuests[Value]
	end
end)

if QUESTS_URL ~= "" and QUESTS_URL ~= "PUT_YOUR_QUESTS_JSON_URL_HERE" then
	task.spawn(function()
		local success, res = pcall(function()
			return game:HttpGet(QUESTS_URL)
		end)
		if success and res then
			local decodeSuccess, decoded = pcall(function()
				return HttpService:JSONDecode(res)
			end)
			if decodeSuccess and type(decoded) == "table" then
				loadedQuests = {}
				local questNames = {}
				
				for _, q in ipairs(decoded) do
					if q.QuestName and q.NPCName and q.TrackerFolder and q.TargetMob then
						loadedQuests[q.QuestName] = q
						table.insert(questNames, q.QuestName)
					end
				end
				
				table.sort(questNames)
				QuestDropdown:SetValues(questNames)
				
				if #questNames > 0 then
					QuestDropdown:SetValue(questNames[1])
					selectedQuest = loadedQuests[questNames[1]]
				end
				
				Fluent:Notify({ Title = "Success", Content = "Loaded " .. #questNames .. " online quests!", Duration = 3 })
			else
				Fluent:Notify({ Title = "Error", Content = "Failed to parse online quests JSON.", Duration = 5 })
			end
		else
			Fluent:Notify({ Title = "Error", Content = "Failed to fetch online quests.", Duration = 5 })
		end
	end)
end

-- ==========================================
-- AUTO TITAN TAB
-- ==========================================

local AutoTitanToggle = Tabs.AutoTitan:AddToggle("AutoTitanToggle", {
	Title = "Enable Auto Titan",
	Default = false,
	Description = "HIGHEST PRIORITY — Locks onto FoundingTitan & RumblingColossal above all other modes."
})

AutoTitanToggle:OnChanged(function(Value)
	isAutoTitanEnabled = Value
	if Value then
		Fluent:Notify({ Title = "⚠ AUTO TITAN ACTIVE", Content = "Hunting FoundingTitan & RumblingColossal — all other modes suspended while titans are alive.", Duration = 5 })
	end
end)

-- Dropdown for Titan Position
local TitanPositionDropdown = Tabs.AutoTitan:AddDropdown("TitanPositionDropdown", {
	Title = "Titan Target Position",
	Description = "Where to hover relative to the titan",
	Values = {"Above", "Below", "Behind"},
	Multi = false,
	Default = 1,
})

TitanPositionDropdown:OnChanged(function(Value)
	titanTeleportPosition = Value
end)

-- Dropdown for Titan Movement Mode
local TitanMovementDropdown = Tabs.AutoTitan:AddDropdown("TitanMovementDropdown", {
	Title = "Titan Movement Mode",
	Description = "How you move to the titan. Tween glides, Instant snaps.",
	Values = {"Instant", "Tween"},
	Multi = false,
	Default = 2,
})

TitanMovementDropdown:OnChanged(function(Value)
	titanMovementMode = Value
end)

-- Slider for Titan Distance
local TitanDistanceSlider = Tabs.AutoTitan:AddSlider("TitanDistanceSlider", {
	Title = "Titan Attack Distance",
	Description = "Distance from the titan (studs)",
	Default = 5,
	Min = 0,
	Max = 200,
	Rounding = 1,
	Callback = function(Value)
		titanTeleportDistance = Value
	end
})

TitanDistanceSlider:OnChanged(function(Value)
	titanTeleportDistance = Value
end)

-- Input for exact Titan Distance
local TitanDistanceInput = Tabs.AutoTitan:AddInput("TitanDistanceInput", {
	Title = "Type Exact Titan Attack Distance",
	Default = "5",
	Placeholder = "Enter distance...",
	Numeric = true,
	Finished = true,
	Callback = function(Value)
		local num = tonumber(Value)
		if num then
			titanTeleportDistance = num
			TitanDistanceSlider:SetValue(num)
		end
	end
})

Tabs.AutoTitan:AddParagraph({
	Title = "Targets",
	Content = "• FoundingTitan\n• RumblingColossal"
})

Tabs.AutoTitan:AddParagraph({
	Title = "Priority",
	Content = "This mode runs BEFORE Kurama, Dungeon, Quest, Boss, and normal Mob farm. When a titan is alive, every other mode yields."
})

-- Titan Skill Toggle
local TitanSkillToggle = Tabs.AutoTitan:AddToggle("TitanSkillToggle", {
	Title = "Enable Auto Skills",
	Default = false,
	Description = "Auto-presses skill keys while actively fighting a titan."
})

TitanSkillToggle:OnChanged(function(Value)
	isTitanSkillEnabled = Value
end)

-- Titan Skill Keys Input
local TitanSkillKeysInput = Tabs.AutoTitan:AddInput("TitanSkillKeysInput", {
	Title = "Skill Keys",
	Description = "Keys to spam during titan fight. Comma-separated (e.g., Z, X, C, One, F1)",
	Default = "",
	Placeholder = "e.g., Z, X, C",
	Numeric = false,
	Finished = true,
	Callback = function(Value)
		titanSkillKeys = {}
		if Value then
			local numMap = {
				["1"]="One", ["2"]="Two", ["3"]="Three", ["4"]="Four", ["5"]="Five",
				["6"]="Six", ["7"]="Seven", ["8"]="Eight", ["9"]="Nine", ["0"]="Zero"
			}
			for keyStr in string.gmatch(Value, "[^,]+") do
				local key = keyStr:match("^%s*(.-)%s*$")
				if key and key ~= "" then
					if numMap[key] then
						key = numMap[key]
					elseif #key == 1 then
						key = string.upper(key)
					end
					titanSkillKeys[key] = true
				end
			end
		end
	end
})

-- Titan Skill Delay Slider
local TitanSkillDelaySlider = Tabs.AutoTitan:AddSlider("TitanSkillDelaySlider", {
	Title = "Skill Press Delay",
	Description = "Delay between each skill cycle (seconds)",
	Default = 0.1,
	Min = 0.01,
	Max = 5,
	Rounding = 2,
	Callback = function(Value)
		titanSkillDelay = Value
	end
})

TitanSkillDelaySlider:OnChanged(function(Value)
	titanSkillDelay = Value
end)

-- Titan Skill Loop — only fires when titan mode is on AND actively fighting
task.spawn(function()
	while true do
		if isTitanSkillEnabled and isAutoTitanEnabled and isCurrentlyFighting then
			local pressedAny = false
			for key, isSelected in pairs(titanSkillKeys) do
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
				task.wait(titanSkillDelay)
			else
				task.wait(0.1)
			end
		else
			task.wait(0.1)
		end
	end
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

local KeysInput = Tabs.AutoKey:AddInput("KeysInput", {
	Title = "Keys to Auto Press",
	Description = "Enter keys separated by commas (e.g., A, B, C, One, F1)",
	Default = "",
	Placeholder = "e.g., A, B, C",
	Numeric = false,
	Finished = true,
	Callback = function(Value)
		selectedKeys = {}
		if Value then
			local numMap = {
				["1"]="One", ["2"]="Two", ["3"]="Three", ["4"]="Four", ["5"]="Five",
				["6"]="Six", ["7"]="Seven", ["8"]="Eight", ["9"]="Nine", ["0"]="Zero"
			}
			for keyStr in string.gmatch(Value, "[^,]+") do
				local key = keyStr:match("^%s*(.-)%s*$")
				if key and key ~= "" then
					if numMap[key] then
						key = numMap[key]
					elseif #key == 1 then
						key = string.upper(key)
					end
					selectedKeys[key] = true
				end
			end
		end
	end
})

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
		if isAutoKeyEnabled and isCurrentlyFighting then
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

-- Automatically minimize GUI by default upon execution
task.spawn(function()
	task.wait(1.5)
	local success = pcall(function()
		-- Some forks of Fluent have Window:Minimize() or Window:Toggle()
		if Window.Minimize then
			Window:Minimize()
		elseif Window.Toggle then
			Window:Toggle()
		else
			error("No minimize method")
		end
	end)
	
	if not success then
		-- Fallback to simulating the minimize key (LeftControl is what the ToggleBtn uses)
		VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.LeftControl, false, game)
		task.wait(0.01)
		VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.LeftControl, false, game)
	end
end)
