-- Memastikan variabel sinkron dengan loader
local TARGET_LIST = getgenv().TARGET_LIST
local FPS_CAP = getgenv().FPS_CAP or 60
local WALK_SPEED = 45
local HOLD_DURATION = 5.5

if setfpscap then setfpscap(FPS_CAP) end

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local lp = Players.LocalPlayer
local loopID = 0
local spawnPos = nil
local isStealing = false

local function getChar() return lp.Character or lp.CharacterAdded:Wait() end
local function getHum() return getChar():WaitForChild("Humanoid") end
local function getHrp() return getChar():WaitForChild("HumanoidRootPart") end

-- Fungsi Jalan (Pathfinding)
local function walkTo(destination, myID)
    local path = PathfindingService:CreatePath({AgentRadius = 3, AgentHeight = 5, AgentCanJump = true})
    local success, _ = pcall(function() path:ComputeAsync(getHrp().Position, destination) end)
    
    if success and path.Status == Enum.PathStatus.Success then
        for _, wp in ipairs(path:GetWaypoints()) do
            if myID ~= loopID then return end
            if wp.Action == Enum.PathWaypointAction.Jump then getHum().Jump = true end
            getHum():MoveTo(wp.Position)
            getHum().MoveToFinished:Wait(1)
        end
    end
end

-- AUTO STEAL (Deteksi Prompt)
ProximityPromptService.PromptShown:Connect(function(prompt)
    if prompt.ActionText == "Steal" then
        task.wait(0.3)
        pcall(function()
            prompt:InputHoldBegin(lp)
            task.wait(HOLD_DURATION)
            prompt:InputHoldEnd(lp)
        end)
    end
end)

-- AUTO SPEED COIL
task.spawn(function()
    while true do
        pcall(function()
            local bp = lp:FindFirstChild("Backpack")
            local hum = getHum()
            if bp and hum then
                for _, tool in ipairs(bp:GetChildren()) do
                    if string.find(string.lower(tool.Name), "speed") then
                        hum:EquipTool(tool)
                        break
                    end
                end
            end
        end)
        task.wait(3)
    end
end)

-- AUTO JUMP
task.spawn(function()
    while true do
        pcall(function()
            local h = getHum()
            if h and h.FloorMaterial ~= Enum.Material.Air then
                h.Jump = true
            end
        end)
        task.wait(0.8)
    end
end)

-- MENCARI TARGET
local function findTarget()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return end
    for _, name in ipairs(TARGET_LIST) do
        for _, plot in ipairs(plots:GetChildren()) do
            local obj = plot:FindFirstChild(name, true)
            if obj and obj:IsA("Model") then
                return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
            end
        end
    end
end

-- LOOP UTAMA
local function startLoop()
    loopID += 1
    local myID = loopID
    task.spawn(function()
        while myID == loopID do
            local target = findTarget()
            if target and not isStealing then
                -- Pergi ke item
                walkTo(target.Position, myID)
                
                -- Tunggu proses Steal selesai
                isStealing = true
                task.wait(HOLD_DURATION + 1)
                isStealing = false
                
                -- Balik ke tempat awal (Spawn)
                if spawnPos then
                    walkTo(spawnPos, myID)
                end
            end
            task.wait(1)
        end
    end)
end

-- Inisialisasi awal
task.spawn(function()
    task.wait(2)
    spawnPos = getHrp().Position -- Simpan posisi berdiri sekarang sebagai tempat balik
    getHum().WalkSpeed = WALK_SPEED
    startLoop()
end)

lp.CharacterAdded:Connect(function()
    loopID += 1
    task.wait(2)
    spawnPos = getHrp().Position
    getHum().WalkSpeed = WALK_SPEED
    startLoop()
end)
