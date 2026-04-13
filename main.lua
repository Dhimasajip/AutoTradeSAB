local TARGET_LIST = getgenv().TARGET_LIST or {"Secret Lucky Block"}
local FPS_CAP = getgenv().FPS_CAP or 60
if setfpscap then setfpscap(FPS_CAP) end

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local lp = Players.LocalPlayer
local loopID = 0
local myPlotFolder
local isStealing, returning, autoJumpEnabled = false, false, true
local cameraConnection = nil 

local function getChar() return lp.Character or lp.CharacterAdded:Wait() end
local function getHum() return getChar():WaitForChild("Humanoid") end
local function getHrp() return getChar():WaitForChild("HumanoidRootPart") end

local function toggleTopDownCamera(enable)
    local cam = workspace.CurrentCamera
    if cameraConnection then cameraConnection:Disconnect() cameraConnection = nil end
    if enable then
        cam.CameraType = Enum.CameraType.Scriptable
        cameraConnection = RunService.RenderStepped:Connect(function()
            local root = getHrp()
            if root then
                cam.CFrame = CFrame.new(root.Position + Vector3.new(0, 9, 0)) * CFrame.Angles(math.rad(-90), 0, 0)
            end
        end)
    else cam.CameraType = Enum.CameraType.Custom end
end

local function walkTo(dest, myID)
    local path = PathfindingService:CreatePath({AgentRadius = 3, AgentHeight = 5, AgentCanJump = true})
    pcall(function() path:ComputeAsync(getHrp().Position, dest) end)
    if path.Status == Enum.PathStatus.Success then
        for _, wp in ipairs(path:GetWaypoints()) do
            if myID ~= loopID then return end
            if wp.Action == Enum.PathWaypointAction.Jump then getHum().Jump = true end
            getHum():MoveTo(wp.Position)
            getHum().MoveToFinished:Wait()
        end
    end
end

ProximityPromptService.PromptShown:Connect(function(prompt)
    if prompt.ActionText ~= "Steal" then return end
    toggleTopDownCamera(true)
    autoJumpEnabled = false 
    task.wait(1)
    pcall(function()
        prompt:InputHoldBegin(lp)
        task.wait(5.5)
        prompt:InputHoldEnd(lp)
        toggleTopDownCamera(false)
        autoJumpEnabled = true
    end)
end)

local function findTarget()
    for _, name in ipairs(TARGET_LIST) do
        for _, plot in ipairs(workspace.Plots:GetChildren()) do
            if plot ~= myPlotFolder then
                local obj = plot:FindFirstChild(name, true)
                if obj and obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")) then return obj end
            end
        end
    end
end

local function startLoop()
    loopID += 1
    local myID = loopID
    task.spawn(function()
        while myID == loopID do
            if not isStealing and not returning then
                local t = findTarget()
                if t then
                    walkTo(t.PrimaryPart.Position, myID)
                    isStealing = true task.wait(6) isStealing = false
                    if myPlotFolder and myPlotFolder:FindFirstChild("Floor") then
                        returning = true walkTo(myPlotFolder.Floor.Position, myID) returning = false
                    end
                end
            end
            task.wait(1)
        end
    end)
end

lp.CharacterAdded:Connect(function() 
    task.wait(1) 
    getHum().WalkSpeed = 45
    myPlotFolder = nil -- Reset plot agar deteksi ulang
    startLoop() 
end)

-- Auto Jump & Speed Coil
task.spawn(function()
    while true do
        if autoJumpEnabled and getHum().FloorMaterial ~= Enum.Material.Air then getHum().Jump = true end
        local bp = lp:FindFirstChild("Backpack")
        if bp then
            for _, t in ipairs(bp:GetChildren()) do
                if string.find(string.lower(t.Name), "speed") then getHum():EquipTool(t) break end
            end
        end
        task.wait(0.8)
    end
end)

getHum().WalkSpeed = 45
startLoop()
