-- Konfigurasi dari Loader
local TARGET_LIST = getgenv().TARGET_LIST or {"Secret Lucky Block"}
local HOLD_DURATION = getgenv().HOLD_DURATION or 5.5
local WALK_SPEED = getgenv().WALK_SPEED or 45
local FPS_CAP = getgenv().FPS_CAP or 60

if setfpscap then setfpscap(FPS_CAP) end

local task_wait = task.wait
task_wait(2)

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local workspace = game:GetService("Workspace")

local lp = Players.LocalPlayer
local loopID = 0
local myPlotFolder
local isStealing = false
local returning = false
local autoJumpEnabled = true
local cameraConnection = nil 

local function getChar() return lp.Character or lp.CharacterAdded:Wait() end
local function getHum() return getChar():WaitForChild("Humanoid") end
local function getHrp() return getChar():WaitForChild("HumanoidRootPart") end

local function toggleTopDownCamera(enable)
    local cam = workspace.CurrentCamera
    if not cam then return end
    if cameraConnection then 
        cameraConnection:Disconnect()
        cameraConnection = nil
    end
    if enable then
        cam.CameraType = Enum.CameraType.Scriptable
        cameraConnection = RunService.RenderStepped:Connect(function()
            local root = getHrp()
            if root then
                local basePos = root.Position + Vector3.new(0, 9, 0)
                cam.CFrame = CFrame.new(basePos) * CFrame.Angles(math.rad(-90), 0, 0)
            end
        end)
    else
        cam.CameraType = Enum.CameraType.Custom
    end
end

local function isObstacleInFront()
    local character = getChar()
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {character}
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    local result = workspace:Raycast(root.Position, root.CFrame.LookVector * 6, rayParams)
    return result ~= nil and result.Instance.CanCollide
end

local function getMyPlot()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return end
    local r = getHrp()
    local closestPlot
    local dist = math.huge
    for _, plot in ipairs(plots:GetChildren()) do
        local ref = plot:FindFirstChild("Floor") or plot:FindFirstChild("PlotSign", true) or plot:FindFirstChildWhichIsA("BasePart")
        if ref then
            local d = (r.Position - ref.Position).Magnitude
            if d < dist then
                dist = d
                closestPlot = plot
            end
        end 
    end
    return closestPlot
end

local function setup()
    local h = getHum()
    h.WalkSpeed = WALK_SPEED
    if not myPlotFolder or not myPlotFolder.Parent then
        myPlotFolder = getMyPlot()
    end
end

local function walkTo(destination, myID)
    local retry = 0
    while retry < 3 and myID == loopID do
        local path = PathfindingService:CreatePath({AgentRadius = 3, AgentHeight = 5, AgentCanJump = true})
        local success = pcall(function() path:ComputeAsync(getHrp().Position, destination) end)
        if success and path.Status == Enum.PathStatus.Success then
            for _, wp in ipairs(path:GetWaypoints()) do
                if myID ~= loopID then return end
                if wp.Action == Enum.PathWaypointAction.Jump or isObstacleInFront() then
                    getHum().Jump = true
                end
                getHum():MoveTo(wp.Position)
                local reached = getHum().MoveToFinished:Wait(1)
                if not reached then break end
            end
            if (getHrp().Position - destination).Magnitude < 5 then return true end
        end
        retry += 1
        task_wait(0.3)
    end
end

ProximityPromptService.PromptShown:Connect(function(prompt)
    if prompt.ActionText ~= "Steal" then return end
    toggleTopDownCamera(true)
    autoJumpEnabled = false 
    task_wait(1)
    pcall(function()
        prompt:InputHoldBegin(lp)
        task_wait(HOLD_DURATION)
        prompt:InputHoldEnd(lp)
        toggleTopDownCamera(false)
        autoJumpEnabled = true
    end)
end)

local function findTarget()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return end
    for _, name in ipairs(TARGET_LIST) do
        for _, plot in ipairs(plots:GetChildren()) do
            if plot ~= myPlotFolder then
                local obj = plot:FindFirstChild(name, true)
                if obj and obj:IsA("Model") then
                    local part = obj.PrimaryPart or obj:FindFirstChild("RootPart") or obj:FindFirstChildWhichIsA("BasePart")
                    if part then return obj end
                end
            end
        end
    end
end

local function steal(target)
    if isStealing then return end
    isStealing = true
    autoJumpEnabled = false 
    task_wait(HOLD_DURATION)
    autoJumpEnabled = true
    isStealing = false
end

local function returnSpawn(myID)
    returning = true
    if myPlotFolder then
        local floor = myPlotFolder:FindFirstChild("Floor")
        if floor then walkTo(floor.Position, myID) end
    end
    returning = false
end

local function startLoop()
    loopID += 1
    local myID = loopID
    task.spawn(function()
        while myID == loopID do
            if not isStealing and not returning then
                local target = findTarget()
                if target then
                    walkTo(target.PrimaryPart.Position, myID)
                    steal(target)
                    returnSpawn(myID)
                end
            end
            task_wait(0.3)
        end
    end)
end

task.spawn(function()
    while true do
        local c = lp.Character
        if c then
            local h = c:FindFirstChildOfClass("Humanoid")
            local bp = lp:FindFirstChildOfClass("Backpack")
            if h and bp then
                for _, tool in ipairs(bp:GetChildren()) do
                    if tool:IsA("Tool") and string.find(string.lower(tool.Name), "speed") then
                        h:EquipTool(tool)
                        break
                    end
                end
            end
        end
        task_wait(3)
    end
end)

setup()
startLoop()

lp.CharacterRemoving:Connect(function() loopID += 1 end)
lp.CharacterAdded:Connect(function()
    loopID += 1
    isStealing = false
    returning = false
    task_wait(0.5)
    setup()
    startLoop()
end)

task.spawn(function()
    while true do
        if autoJumpEnabled then
            local h = getHum()
            if h and h.FloorMaterial ~= Enum.Material.Air and h:GetState() ~= Enum.HumanoidStateType.Dead then
                h:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
        task_wait(0.8)
    end
end)
