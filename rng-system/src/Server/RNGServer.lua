local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")

local PlayerDataStore = DataStoreService:GetDataStore("RNGPlayerData_V2")
local eventsFolder = ReplicatedStorage:WaitForChild("RNGEvents")
local RollEvent = eventsFolder:WaitForChild("RollEvent")
local EquipEvent = eventsFolder:WaitForChild("EquipEvent")
local UpdateDataEvent = eventsFolder:WaitForChild("UpdateDataEvent")
local BoostUpdateEvent = eventsFolder:WaitForChild("BoostUpdateEvent")

local LUCK_BOOST_PRODUCT_ID = 123456789

local Auras = {
    {Name = "Common", BaseChance = 1, Color = Color3.fromRGB(200, 200, 200)},
    {Name = "Uncommon", BaseChance = 5, Color = Color3.fromRGB(100, 255, 100)},
    {Name = "Rare", BaseChance = 25, Color = Color3.fromRGB(100, 100, 255)}
}

table.sort(Auras, function(a, b) return a.BaseChance > b.BaseChance end)

local PlayerData = {}
local PlayerBoosts = {}

local function getPlayerData(player)
    if not PlayerData[player.UserId] then
        PlayerData[player.UserId] = {TotalSpins = 0, Inventory = {}, Equipped = nil}
    end
    return PlayerData[player.UserId]
end

local function updateClientData(player)
    local data = getPlayerData(player)
    UpdateDataEvent:FireClient(player, data)
    
    local boostEnd = PlayerBoosts[player.UserId] or 0
    local timeRemaining = math.max(0, boostEnd - os.time())
    BoostUpdateEvent:FireClient(player, timeRemaining)
end

Players.PlayerAdded:Connect(function(player)
    local data = getPlayerData(player)
    local success, savedData = pcall(function()
        return PlayerDataStore:GetAsync("Player_" .. player.UserId)
    end)
    
    if success and savedData then
        data.TotalSpins = savedData.TotalSpins or 0
        data.Inventory = savedData.Inventory or {}
        data.Equipped = savedData.Equipped
    end
    
    task.wait(1)
    updateClientData(player)
    
    player.CharacterAdded:Connect(function(char)
        if data.Equipped then
            local auraData = nil
            for _, a in ipairs(Auras) do
                if a.Name == data.Equipped then auraData = a break end
            end
            if auraData then _G.ApplyVisualEffect(char, auraData) end
        end
    end)
end)

local function savePlayerData(player)
    if PlayerData[player.UserId] then
        pcall(function() PlayerDataStore:SetAsync("Player_" .. player.UserId, PlayerData[player.UserId]) end)
    end
end

Players.PlayerRemoving:Connect(function(player)
    savePlayerData(player)
    PlayerData[player.UserId] = nil
    PlayerBoosts[player.UserId] = nil
end)

_G.ApplyVisualEffect = function(character, aura)
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    for _, child in ipairs(hrp:GetChildren()) do
        if child.Name == "RNGAuraEffect" then child:Destroy() end
    end
    
    if aura then
        local attachment = Instance.new("Attachment")
        attachment.Name = "RNGAuraEffect"
        attachment.Parent = hrp
        
        local particle = Instance.new("ParticleEmitter")
        particle.Color = ColorSequence.new(aura.Color)
        particle.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 3), NumberSequenceKeypoint.new(1, 0)})
        particle.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.5), NumberSequenceKeypoint.new(0.8, 0.5), NumberSequenceKeypoint.new(1, 1)})
        particle.EmissionDirection = Enum.NormalId.Top
        particle.Speed = NumberRange.new(2, 5)
        particle.Lifetime = NumberRange.new(1, 2)
        particle.Rate = 20
        particle.Parent = attachment
    end
end

RollEvent.OnServerEvent:Connect(function(player)
    local data = getPlayerData(player)
    data.TotalSpins += 1
    
    local luckMultiplier = 1 + (data.TotalSpins * 0.005)
    local boostEnd = PlayerBoosts[player.UserId] or 0
    if os.time() < boostEnd then
        luckMultiplier = luckMultiplier * 5
    end
    
    local rolledAura = Auras[#Auras]
    for _, aura in ipairs(Auras) do
        local effectiveChance = math.max(1, aura.BaseChance / luckMultiplier)
        if math.random(1, math.floor(effectiveChance)) == 1 then
            rolledAura = aura
            break
        end
    end
    
    if not data.Inventory[rolledAura.Name] then data.Inventory[rolledAura.Name] = 0 end
    data.Inventory[rolledAura.Name] += 1
    
    RollEvent:FireClient(player, rolledAura.Name, rolledAura.BaseChance, rolledAura.Color)
    updateClientData(player)
end)

EquipEvent.OnServerEvent:Connect(function(player, auraName)
    local data = getPlayerData(player)
    if auraName == nil then
        data.Equipped = nil
        _G.ApplyVisualEffect(player.Character, nil)
    elseif data.Inventory[auraName] and data.Inventory[auraName] > 0 then
        data.Equipped = auraName
        local auraData = nil
        for _, a in ipairs(Auras) do if a.Name == auraName then auraData = a break end end
        if player.Character and auraData then _G.ApplyVisualEffect(player.Character, auraData) end
    end
    updateClientData(player)
end)

MarketplaceService.ProcessReceipt = function(receiptInfo)
    local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
    if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
    
    if receiptInfo.ProductId == LUCK_BOOST_PRODUCT_ID then
        local currentEnd = PlayerBoosts[player.UserId] or os.time()
        if currentEnd < os.time() then currentEnd = os.time() end
        PlayerBoosts[player.UserId] = currentEnd + 300
        updateClientData(player)
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end
    return Enum.ProductPurchaseDecision.NotProcessedYet
end

task.spawn(function()
    while true do
        task.wait(1)
        for _, player in ipairs(Players:GetPlayers()) do
            local boostEnd = PlayerBoosts[player.UserId] or 0
            if boostEnd > 0 and os.time() <= boostEnd then
                BoostUpdateEvent:FireClient(player, boostEnd - os.time())
            else
                BoostUpdateEvent:FireClient(player, 0)
            end
        end
    end
end)
