local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer
local clientEntities = workspace:WaitForChild("ClientEntities")

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
	Size = UDim2.fromOffset(500, 520),
	Acrylic = true, 
	Theme = "Dark",
	MinimizeKey = Enum.KeyCode.RightControl
})

local Tabs = {
	Main = Window:AddTab({ Title = "Main", Icon = "home" })
}

-- Toggle for auto teleport
local EnableToggle = Tabs.Main:AddToggle("EnableToggle", {
	Title = "Enable Auto Teleport", 
	Default = false 
})

EnableToggle:OnChanged(function(Value)
	isEnabled = Value
	if not isEnabled then
		currentTarget = nil -- Clear target when disabled
	end
end)

-- Dropdown to select preferred entity names
local EntityDropdown = Tabs.Main:AddDropdown("EntityDropdown", {
	Title = "Preferred Entities",
	Description = "Select which entities to target (groups by name)",
	Values = {},
	Multi = true,
	Default = {},
})

EntityDropdown:OnChanged(function(Value)
	selectedEntities = Value
	
	-- If our current target's name is no longer selected, clear it
	if currentTarget and not selectedEntities[currentTarget.Name] then
		currentTarget = nil
	end
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
	Max = 300,
	Rounding = 1,
	Callback = function(Value)
		tweenSpeed = Value
	end
})

SpeedSlider:OnChanged(function(Value)
	tweenSpeed = Value
end)

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

-- Function to extract unique entity names from the workspace
local function updateEntityList()
	local entityNames = {}
	local added = {}
	
	for _, entity in ipairs(clientEntities:GetChildren()) do
		local name = entity.Name
		if not added[name] then
			added[name] = true
			table.insert(entityNames, name)
		end
	end
	
	table.sort(entityNames)
	EntityDropdown:SetValues(entityNames)
end

-- Refresh Button
Tabs.Main:AddButton({
	Title = "Refresh Entities List",
	Description = "Updates the dropdown with current entities in workspace",
	Callback = function()
		updateEntityList()
		Fluent:Notify({
			Title = "Refreshed",
			Content = "Entity list has been updated.",
			Duration = 3
		})
	end
})

-- Initial population of the dropdown
updateEntityList()

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

-- Checks if a target is valid
local function isValidTarget(target)
	if not target or not target.Parent or target.Parent ~= clientEntities then
		return false
	end
	
	if not selectedEntities[target.Name] then
		return false
	end
	
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health <= 0 then
		return false
	end
	
	if not getTargetCFrame(target) then
		return false
	end
	
	return true
end

-- Continuous RenderStepped Loop for smooth tweening/teleporting
RunService.RenderStepped:Connect(function(deltaTime)
	if not isEnabled then return end
	
	local character = player.Character
	if not character then return end
	
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end
	
	if not isValidTarget(currentTarget) then
		currentTarget = nil
		
		for _, entity in ipairs(clientEntities:GetChildren()) do
			if isValidTarget(entity) then
				currentTarget = entity
				break
			end
		end
	end
	
	if currentTarget then
		local targetCFrame = getTargetCFrame(currentTarget)
		if targetCFrame then
			local newCFrame
			
			-- Look At the target so our attacks/hitboxes actually hit them
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
				-- Calculate distance and how much we can move this frame based on speed
				local currentPos = rootPart.Position
				local targetPos = newCFrame.Position
				local distance = (targetPos - currentPos).Magnitude
				local maxMove = tweenSpeed * deltaTime
				
				if distance > maxMove then
					-- Glide towards the target
					local direction = (targetPos - currentPos).Unit
					local nextPos = currentPos + (direction * maxMove)
					-- Move position but maintain the lookAt rotation
					rootPart.CFrame = CFrame.new(nextPos) * newCFrame.Rotation
				else
					-- We reached the target, snap exactly to it
					rootPart.CFrame = newCFrame
				end
			else
				-- Instant Teleport
				rootPart.CFrame = newCFrame
			end
			
			-- Reset velocity to prevent falling/flinging during the tween
			rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			rootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
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
	VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.RightControl, false, game)
	task.wait(0.01)
	VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.RightControl, false, game)
end)

Window:SelectTab(1)
