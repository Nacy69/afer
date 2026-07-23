local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Simple Auto Farm",
    SubTitle = "Teleport & Skill",
    TabWidth = 160,
    Size = UDim2.fromOffset(480, 360),
    Acrylic = true, 
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "Main Settings", Icon = "home" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

-- Variables
local isAutoFarm = false
local autoLookDown = false
local attackDistance = 10
local teleportPosition = "Above"
local selectedKeys = {}
local skillDelay = 0.1
local safeModeEnabled = false
local healthThreshold = 20
local hasTarget = false

local player = game:GetService("Players").LocalPlayer
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local clientEntities = workspace:WaitForChild("ClientEntities", 10)

if not clientEntities then
    Fluent:Notify({
        Title = "Error",
        Content = "ClientEntities folder not found in workspace!",
        Duration = 5
    })
end

local function getTargetCFrame(target)
    if target:IsA("Model") then
        local root = target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart")
        if root then return root.CFrame end
    elseif target:IsA("BasePart") then
        return target.CFrame
    end
    return nil
end

local function pressKey(keyStr)
    local key = keyStr
    local numMap = { ["1"]="One", ["2"]="Two", ["3"]="Three", ["4"]="Four", ["5"]="Five", ["6"]="Six", ["7"]="Seven", ["8"]="Eight", ["9"]="Nine", ["0"]="Zero" }
    if #key == 1 and numMap[key] then
        key = numMap[key]
    elseif #key == 1 then
        key = string.upper(key)
    end
    
    local keyCode = Enum.KeyCode[key]
    if keyCode then
        VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
        task.wait(0.01)
        VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
    end
end

-- UI Elements
local FarmToggle = Tabs.Main:AddToggle("FarmToggle", {
    Title = "Enable Auto Farm", 
    Default = false 
})
FarmToggle:OnChanged(function(Value)
    isAutoFarm = Value
end)

local LookDownToggle = Tabs.Main:AddToggle("LookDownToggle", {
    Title = "Auto Look Down (Camera)", 
    Default = false 
})
LookDownToggle:OnChanged(function(Value)
    autoLookDown = Value
end)

local DistInput = Tabs.Main:AddInput("DistInput", {
    Title = "Attack Distance",
    Default = "10",
    Numeric = true,
    Finished = false,
    Placeholder = "Enter distance",
    Callback = function(Value)
        attackDistance = tonumber(Value) or 10
    end
})

local PosDropdown = Tabs.Main:AddDropdown("PosDropdown", {
    Title = "Teleport Position",
    Values = {"Above", "Below", "Behind", "Front", "Orbit"},
    Multi = false,
    Default = 1,
})
PosDropdown:OnChanged(function(Value)
    teleportPosition = Value
end)

local SafeModeToggle = Tabs.Main:AddToggle("SafeModeToggle", {
    Title = "Enable Safe Mode",
    Default = false
})
SafeModeToggle:OnChanged(function(Value)
    safeModeEnabled = Value
end)

local HealthThresholdInput = Tabs.Main:AddInput("HealthThresholdInput", {
    Title = "Health Threshold (Safe Mode)",
    Default = "20",
    Numeric = true,
    Finished = false,
    Placeholder = "Enter health % or value",
    Callback = function(Value)
        healthThreshold = tonumber(Value) or 20
    end
})

local KeysInput = Tabs.Main:AddInput("KeysInput", {
    Title = "Skills (Comma separated)",
    Description = "e.g., 1, 2, 3, E, R",
    Default = "1, 2, 3, 4, E, R, F, C, V, X, Z",
    Placeholder = "1, 2, 3",
    Numeric = false,
    Finished = false,
    Callback = function(Value)
        selectedKeys = {}
        if Value then
            for keyStr in string.gmatch(Value, "[^,]+") do
                local key = keyStr:match("^%s*(.-)%s*$")
                if key and key ~= "" then
                    table.insert(selectedKeys, key)
                end
            end
        end
    end
})

-- Initialize default keys
for keyStr in string.gmatch("1, 2, 3, 4, E, R, F, C, V, X, Z", "[^,]+") do
    local key = keyStr:match("^%s*(.-)%s*$")
    if key and key ~= "" then
        table.insert(selectedKeys, key)
    end
end

local DelaySlider = Tabs.Main:AddSlider("DelaySlider", {
    Title = "Skill Delay",
    Default = 0.1,
    Min = 0.01,
    Max = 2,
    Rounding = 2,
    Callback = function(Value)
        skillDelay = Value
    end
})

-- Loops
task.spawn(function()
    while true do
        task.wait(skillDelay)
        if isAutoFarm and hasTarget and #selectedKeys > 0 then
            for _, keyStr in ipairs(selectedKeys) do
                if not isAutoFarm then break end
                pressKey(keyStr)
            end
        end
    end
end)

RunService.RenderStepped:Connect(function()
    if not isAutoFarm or not clientEntities then return end
    
    local foundEntity = nil
    for _, entity in ipairs(clientEntities:GetChildren()) do
        local humanoid = entity:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health > 0 then
            foundEntity = entity
            break
        end
    end
    
    hasTarget = (foundEntity ~= nil)
    
    if foundEntity then
        local targetCFrame = getTargetCFrame(foundEntity)
        local character = player.Character
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")
        
        if targetCFrame and rootPart then
            local newCFrame
            
            local human = character:FindFirstChild("Humanoid")
            local isLowHealth = human and (human.Health / human.MaxHealth) * 100 <= healthThreshold
            
            if safeModeEnabled and isLowHealth then
                newCFrame = CFrame.lookAt(targetCFrame.Position + Vector3.new(0, 100, 0), targetCFrame.Position)
            elseif teleportPosition == "Above" then
                newCFrame = CFrame.lookAt(targetCFrame.Position + Vector3.new(0, attackDistance, 0), targetCFrame.Position)
            elseif teleportPosition == "Below" then
                newCFrame = CFrame.lookAt(targetCFrame.Position + Vector3.new(0, -attackDistance, 0), targetCFrame.Position)
            elseif teleportPosition == "Behind" then
                newCFrame = CFrame.lookAt(targetCFrame.Position + (targetCFrame.LookVector * -attackDistance), targetCFrame.Position)
            elseif teleportPosition == "Front" then
                newCFrame = CFrame.lookAt(targetCFrame.Position + (targetCFrame.LookVector * attackDistance), targetCFrame.Position)
            elseif teleportPosition == "Orbit" then
                local orbitSpeed = 10 -- Fast orbit speed
                local rad = tick() * orbitSpeed
                local offset = Vector3.new(math.cos(rad) * attackDistance, 0, math.sin(rad) * attackDistance)
                newCFrame = CFrame.lookAt(targetCFrame.Position + offset, targetCFrame.Position)
            else
                newCFrame = targetCFrame
            end
            
            rootPart.CFrame = newCFrame
            rootPart.AssemblyLinearVelocity = Vector3.new(0,0,0)
            rootPart.AssemblyAngularVelocity = Vector3.new(0,0,0)
            
            -- Handle camera
            if autoLookDown then
                local camera = workspace.CurrentCamera
                if camera then
                    camera.CFrame = CFrame.lookAt(camera.CFrame.Position, targetCFrame.Position)
                end
            end
        end
    end
end)

-- Config System
local configName = "SimpleAutoFarm_Config.json"

Tabs.Settings:AddButton({
    Title = "Save Config",
    Description = "Saves your current settings to file",
    Callback = function()
        local config = {
            FarmToggle = FarmToggle.Value,
            LookDownToggle = LookDownToggle.Value,
            DistInput = DistInput.Value,
            PosDropdown = PosDropdown.Value,
            SafeModeToggle = SafeModeToggle.Value,
            HealthThresholdInput = HealthThresholdInput.Value,
            KeysInput = KeysInput.Value,
            DelaySlider = DelaySlider.Value
        }
        if writefile then
            local success = pcall(function()
                writefile(configName, HttpService:JSONEncode(config))
            end)
            if success then
                Fluent:Notify({ Title = "Config", Content = "Configuration saved successfully.", Duration = 3 })
            else
                Fluent:Notify({ Title = "Error", Content = "Failed to save configuration file.", Duration = 3 })
            end
        else
            Fluent:Notify({ Title = "Error", Content = "Your executor does not support writefile.", Duration = 3 })
        end
    end
})

Tabs.Settings:AddButton({
    Title = "Load Config",
    Description = "Loads your settings from file",
    Callback = function()
        if isfile and isfile(configName) then
            local success, data = pcall(function()
                return HttpService:JSONDecode(readfile(configName))
            end)
            if success and type(data) == "table" then
                if data.FarmToggle ~= nil then FarmToggle:SetValue(data.FarmToggle) end
                if data.LookDownToggle ~= nil then LookDownToggle:SetValue(data.LookDownToggle) end
                if data.DistInput ~= nil then DistInput:SetValue(tostring(data.DistInput)) end
                if data.PosDropdown ~= nil then PosDropdown:SetValue(data.PosDropdown) end
                if data.SafeModeToggle ~= nil then SafeModeToggle:SetValue(data.SafeModeToggle) end
                if data.HealthThresholdInput ~= nil then HealthThresholdInput:SetValue(tostring(data.HealthThresholdInput)) end
                if data.KeysInput ~= nil then KeysInput:SetValue(tostring(data.KeysInput)) end
                if data.DelaySlider ~= nil then DelaySlider:SetValue(tonumber(data.DelaySlider) or 0.1) end
                Fluent:Notify({ Title = "Config", Content = "Configuration loaded successfully.", Duration = 3 })
            else
                Fluent:Notify({ Title = "Error", Content = "Failed to parse configuration file.", Duration = 3 })
            end
        else
            Fluent:Notify({ Title = "Error", Content = "No configuration file found.", Duration = 3 })
        end
    end
})

Window:SelectTab(1)
Fluent:Notify({
    Title = "Loaded",
    Content = "Simple Teleport & Skill script has loaded successfully.",
    Duration = 3
})

