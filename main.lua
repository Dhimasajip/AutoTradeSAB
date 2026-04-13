-- Sinkronisasi dengan Loader
local TARGET_LIST = getgenv().TARGET_LIST or {"Secret Lucky Block"}
local FPS_CAP = getgenv().FPS_CAP or 12
local WALK_SPEED = 45
local HOLD_DURATION = 5.5

if setfpscap then setfpscap(FPS_CAP) end

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local lp = Players.LocalPlayer
local loopID = 0
local spawnPos = nil

local function getChar() return lp.Character or lp.CharacterAdded:Wait() end
local function getHum() return getChar():WaitForChild("Humanoid") end
local function getHrp() return getChar():WaitForChild("HumanoidRootPart") end

-- Fungsi Jalan yang lebih stabil
local function walkTo(destination)
    local h = getHum()
    local r = getHrp()
    local path = PathfindingService:CreatePath({AgentRadius = 2, AgentHeight = 5, AgentCanJump = true})
    
    local success, _ = pcall(function() path:ComputeAsync(r.Position, destination) end)
    if success and path.Status == Enum.PathStatus.Success then
        local waypoints = path:GetWaypoints()
        for i = 1, #waypoints do
            local wp = waypoints[i]
            if wp.Action == Enum.PathWaypointAction.Jump then h.Jump = true end
            h:MoveTo(wp.Position)
            
            -- Timeout jika karakter tersangkut
            local timedOut = not h.MoveToFinished:Wait(2)
            if timedOut then 
                h.Jump = true
                r.CFrame = r.CFrame * CFrame.new(0,0,-1) -- Dorong sedikit ke depan
                break 
            end
        end
    end
end

-- 1. AUTO SPEED COIL
task.spawn(function()
    while true do
        pcall(function()
            local bp = lp:FindFirstChild("Backpack")
            local h = getHum()
            if bp and h then
                for _, tool in ipairs(bp:GetChildren()) do
                    if tool:IsA("Tool") and string.find(string.lower(tool.Name), "speed") then
                        h:EquipTool(tool)
                    end
                end
            end
        end)
        task.wait(2)
    end
end)

-- 2. AUTO JUMP (Loncat-loncat)
task.spawn(function()
    while true do
        pcall(function()
            local h = getHum()
            if h and h.FloorMaterial ~= Enum.Material.Air then
                h.Jump = true
            end
        end)
        task.wait(0.7)
    end
end)

-- 3. AUTO STEAL (Deteksi Tombol)
ProximityPromptService.PromptShown:Connect(function(prompt)
    if prompt.ActionText == "Steal" or prompt.ObjectText == "Item" then
        task.wait(0.3)
        pcall(function()
            prompt:InputHoldBegin(lp)
            task.wait(HOLD_DURATION + 0.5)
            prompt:InputHoldEnd(lp)
        end)
    end
end)

-- 4. FUNGSI MENCARI ITEM
local function findItem()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end
    
    for _, name in ipairs(TARGET_LIST) do
        for _, plot in ipairs(plots:GetChildren()) do
            -- Jangan curi dari plot sendiri jika bisa dideteksi (opsional)
            local item = plot:FindFirstChild(name, true)
            if item and item:IsA("Model") then
                return item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart")
            end
        end
    end
    return nil
end

-- 5. LOOP UTAMA
local function main()
    loopID += 1
    local myID = loopID
    
    -- Tunggu karakter siap dan ambil posisi Spawn
    task.wait(2)
    spawnPos = getHrp().Position
    getHum().WalkSpeed = WALK_SPEED
    
    while myID == loopID do
        local target = findItem()
        if target then
            -- Pergi ke Item
            walkTo(target.Position)
            
            -- Tunggu proses steal (PromptShown akan menangani sisanya)
            task.wait(HOLD_DURATION + 1)
            
            -- Balik ke Spawn
            if spawnPos then
                walkTo(spawnPos)
            end
        end
        task.wait(2) -- Jeda antar pencarian
    end
end

-- Jalankan
task.spawn(main)
lp.CharacterAdded:Connect(main)
