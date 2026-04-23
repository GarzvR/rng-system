local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local eventsFolder = ReplicatedStorage:WaitForChild("RNGEvents")
local RollEvent = eventsFolder:WaitForChild("RollEvent")
local EquipEvent = eventsFolder:WaitForChild("EquipEvent")
local UpdateDataEvent = eventsFolder:WaitForChild("UpdateDataEvent")
local BoostUpdateEvent = eventsFolder:WaitForChild("BoostUpdateEvent")

local LUCK_BOOST_PRODUCT_ID = 123456789

local gui = script.Parent
local hud = gui:WaitForChild("HUDFrame")
local rollButton = hud:WaitForChild("RollButton")
local autoRollBtn = hud:WaitForChild("AutoRollBtn")
local storeBtn = hud:WaitForChild("StoreBtn")
local resultLabel = hud:WaitForChild("ResultLabel")
local chanceLabel = hud:WaitForChild("ChanceLabel")
local luckLabel = hud:WaitForChild("LuckLabel")

local invToggleBtn = gui:WaitForChild("InvToggleBtn")
local invPanel = gui:WaitForChild("InventoryPanel")
local scrollList = invPanel:WaitForChild("ScrollingList")
local template = invPanel:WaitForChild("ItemTemplate")

local isRolling = false
local isAutoRolling = false
local currentBoostTime = 0
local totalSpinsCache = 0

local AuraColors = {
    Common = Color3.fromRGB(200, 200, 200),
    Uncommon = Color3.fromRGB(100, 255, 100),
    Rare = Color3.fromRGB(100, 100, 255)
}

local function updateLuckLabel()
    local luckMultiplier = 1 + (totalSpinsCache * 0.005)
    if currentBoostTime > 0 then luckMultiplier = luckMultiplier * 5 end
    luckLabel.Text = string.format("Spins: %d  |  Luck: %.2fx  |  Boost: %ds", totalSpinsCache, luckMultiplier, currentBoostTime)
    
    if currentBoostTime > 0 then
        luckLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
    else
        luckLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    end
end

local function doRoll()
    if isRolling then return end
    isRolling = true
    rollButton.TextTransparency = 0.5
    RollEvent:FireServer()
end

rollButton.MouseButton1Click:Connect(function()
    if not isAutoRolling then doRoll() end
end)

autoRollBtn.MouseButton1Click:Connect(function()
    isAutoRolling = not isAutoRolling
    if isAutoRolling then
        autoRollBtn.TextTransparency = 0
        autoRollBtn.BackgroundTransparency = 0.5
        task.spawn(function()
            while isAutoRolling do
                if not isRolling then doRoll() end
                task.wait(1.5)
            end
        end)
    else
        autoRollBtn.TextTransparency = 0.5
        autoRollBtn.BackgroundTransparency = 0.8
    end
end)

storeBtn.MouseButton1Click:Connect(function()
    MarketplaceService:PromptProductPurchase(player, LUCK_BOOST_PRODUCT_ID)
end)

RollEvent.OnClientEvent:Connect(function(auraName, chance, color)
    resultLabel.Text = auraName
    resultLabel.TextColor3 = color
    chanceLabel.Text = "1 in " .. tostring(chance)
    rollButton.TextTransparency = 0
    isRolling = false
end)

invToggleBtn.MouseButton1Click:Connect(function()
    invPanel.Visible = not invPanel.Visible
end)

invPanel:WaitForChild("UnequipBtn").MouseButton1Click:Connect(function()
    EquipEvent:FireServer(nil)
end)

local function getRarityOrder(auraName)
    local order = {Common=1, Uncommon=2, Rare=3}
    return order[auraName] or 0
end

UpdateDataEvent.OnClientEvent:Connect(function(data)
    totalSpinsCache = data.TotalSpins
    updateLuckLabel()
    
    for _, child in ipairs(scrollList:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    
    local sortedAuras = {}
    for name, count in pairs(data.Inventory) do
        table.insert(sortedAuras, {Name = name, Count = count, Order = getRarityOrder(name)})
    end
    table.sort(sortedAuras, function(a, b) return a.Order > b.Order end)
    
    local totalItems = 0
    for _, item in ipairs(sortedAuras) do
        if item.Count > 0 then
            totalItems += 1
            local clone = template:Clone()
            clone.Name = item.Name
            clone.AuraName.Text = item.Name
            clone.AuraName.TextColor3 = AuraColors[item.Name] or Color3.fromRGB(255, 255, 255)
            
            if data.Equipped == item.Name then
                clone.BackgroundTransparency = 0.8
            end
            
            clone.Visible = true
            clone.Parent = scrollList
            clone.MouseButton1Click:Connect(function() EquipEvent:FireServer(item.Name) end)
        end
    end
    scrollList.CanvasSize = UDim2.new(0, 0, 0, totalItems * 42)
end)

BoostUpdateEvent.OnClientEvent:Connect(function(timeRemaining)
    currentBoostTime = timeRemaining
    updateLuckLabel()
end)

task.spawn(function()
    while true do
        task.wait(1)
        if currentBoostTime > 0 then
            currentBoostTime = currentBoostTime - 1
            updateLuckLabel()
        end
    end
end)
