-- Mengambil data dari loader
local TARGET_LIST = getgenv().TARGET_LIST or {"Secret Lucky Block"}
local FPS_CAP = getgenv().FPS_CAP or 60
if setfpscap then setfpscap(FPS_CAP) end

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local lp = Players.LocalPlayer
local spawnPos = nil
local loopID = 0
local isStealing = false

local function getChar() return lp.Character or lp.CharacterAdded:Wait() end
local function getHum() return getChar():WaitForChild("Humanoid") end
local function getHrp() return getChar():WaitForChild("HumanoidRootPart") end

-- Fungsi jalan kaki
local function walkTo(dest, myID)
    local path = PathfindingService:CreatePath({AgentRadius = 3, AgentHeight = 5, AgentCanJump = true})
    local success, _ = pcall(function() path:ComputeAsync(getHrp().Position, dest) end)
    
    if success and path.Status == Enum.PathStatus.Success then
        for _, wp in ipairs(path:GetWaypoints()) do
            if myID ~= loopID then return end
            if wp.Action == Enum.PathWaypointAction.Jump then getHum().Jump = true end
            getHum():MoveTo(wp.Position)
            getHum().MoveToFinished:Wait()
        end
    end
end

-- Fungsi mencari target
local function findTarget()
    for _, name in ipairs(TARGET_LIST) do
        for _, plot in ipairs(workspace.Plots:GetChildren()) do
            local obj = plot:FindFirstChild(name, true)
            if obj and obj:IsA("Model") then
                return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
            end
        end
    end
end

-- Loop Utama
local function startLoop()
    loopID += 1
    local myID = loopID
    task.spawn(function()
        while myID == loopID do
            if not isStealing then
                local targetPart = findTarget()
                if targetPart then
                    -- Jalan ke target
                    walkTo(targetPart.Position, myID)
                    
                    -- Proses mencuri (diam sebentar)
                    isStealing = true
                    task.wait(6) 
                    isStealing = false
                    
                    -- Balik ke posisi awal
                    if spawnPos then
                        walkTo(spawnPos, myID)
                    end
                end
            end
            task.wait(1)
        end
    end)
end

-- Auto Jump Loop (Loncat-loncat)
task.spawn(function()
    while true do
        local h = getHum()
        if h and h.FloorMaterial ~= Enum.Material.Air then
            h.Jump = true
        end
        task.wait(0.8)
    end
end)

-- Setup Awal
task.spawn(function()
    task.wait(1)
    spawnPos = getHrp().Position
    getHum().WalkSpeed = 45
    startLoop()
end)

-- Reset saat karakter mati/respawn
lp.CharacterAdded:Connect(function()
    loopID += 1
    task.wait(1)
    spawnPos = getHrp().Position
    getHum().WalkSpeed = 45
    startLoop()
end)
