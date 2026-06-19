local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer
local clientEntities = workspace:WaitForChild("ClientEntities")

local WAYPOINTS_URL = "https://raw.githubusercontent.com/Nacy69/afer/refs/heads/main/MobWaypoints.json" -- Replace with your raw JSON URL

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
	
	if isBossAutoEnabled then
		local aggroZones = workspace:FindFirstChild("Zones") and workspace.Zones:FindFirstChild("Aggro")
		if not aggroZones then return end
		
		local validBosses = {}
		for _, zone in ipairs(aggroZones:GetChildren()) do
			if selectedBosses[zone.Name] then
				table.insert(validBosses, zone)
			end
		end
		
		if #validBosses == 0 then return end
		
		if currentBossIndex > #validBosses then
			currentBossIndex = 1
		end
		
		local targetZone = validBosses[currentBossIndex]
		local zonePos = targetZone:IsA("Model") and (targetZone.PrimaryPart and targetZone.PrimaryPart.Position or targetZone:GetModelCFrame().Position) or targetZone.Position
		
		local foundEntity = nil
		
		-- First check if the zone itself is the boss (has a humanoid)
		local zoneHumanoid = targetZone:FindFirstChildOfClass("Humanoid")
		if zoneHumanoid and zoneHumanoid.Health > 0 then
			foundEntity = targetZone
		else
			-- Otherwise check ClientEntities
			for _, entity in ipairs(clientEntities:GetChildren()) do
				if entity.Name == targetZone.Name then
					local humanoid = entity:FindFirstChildOfClass("Humanoid")
					if not humanoid or humanoid.Health > 0 then
						local eCFrame = getTargetCFrame(entity)
						if eCFrame and (eCFrame.Position - zonePos).Magnitude < 100 then
							foundEntity = entity
							break
						end
					end
				end
			end
		end
		
		local targetCFrame
		local isFighting = false
		
		if foundEntity then
			targetCFrame = getTargetCFrame(foundEntity)
			isFighting = true
		else
			targetCFrame = CFrame.new(zonePos)
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
				local eCFrame = getTargetCFrame(entity)
				if eCFrame and (eCFrame.Position - targetWaypoint.Position).Magnitude < 50 then
					foundEntity = entity
					break
				end
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
local isBossAutoEnabled = false
local selectedBosses = {}
local currentBossIndex = 1
local lastBossVisitTime = 0

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

local function updateBossList()
	local aggroZones = workspace:FindFirstChild("Zones") and workspace.Zones:FindFirstChild("Aggro")
	if aggroZones then
		local names = {}
		local added = {}
		for _, zone in ipairs(aggroZones:GetChildren()) do
			if not added[zone.Name] then
				added[zone.Name] = true
				table.insert(names, zone.Name)
			end
		end
		table.sort(names)
		BossDropdown:SetValues(names)
	else
		Fluent:Notify({ Title = "Error", Content = "workspace.Zones.Aggro not found!", Duration = 3 })
	end
end

Tabs.Bosses:AddButton({
	Title = "Refresh Bosses",
	Description = "Refresh the boss list from workspace.Zones.Aggro",
	Callback = function()
		updateBossList()
		Fluent:Notify({ Title = "Refreshed", Content = "Boss list has been updated.", Duration = 2 })
	end
})

-- Initial population
task.spawn(function()
	task.wait(2) -- Wait for game to fully load
	updateBossList()
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
