--[[
This script is responsible for handling developer product transactions securely. It uses a table of functions to reference product ids to unique callback functions.

--]]

------------------// PRIVATE VARIABLES \\------------------

--Services
local MarketplaceService = game:GetService("MarketplaceService")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

--Modules
local PlayerData = require(ServerScriptService:WaitForChild("PlayerData"))

--Manipulated
local idToCallback = {} --Callbacks receive the DataObject

------------------// PRIVATE FUNCTIONS \\------------------

--Main callback function to process purchases
local function handlePurchase(receipt : table)
    --Get player object from receipt's PlayerId
    local playerKey = receipt.PlayerId
    local player = Players:GetPlayerByUserId(playerKey)
    --Make sure player is still in game
    if player then
        --Get player data and make sure it loads
        local dataObject = PlayerData.getDataObject(player)
        if dataObject then
            --Get purchase history and the current purchase id
            local purchaseHistory = dataObject:GetData("PurchaseHistory")
            local purchaseId = receipt.PurchaseId
            --Return success if purchase was already processed
            if table.find(purchaseHistory, purchaseId) then
                return Enum.ProductPurchaseDecision.PurchaseGranted
            else
                --Get product id and callback function
                local productId = receipt.ProductId
                local callback = idToCallback[productId]
                --Check that callback exists and fulfilled the purchase
                if callback and callback(dataObject) then
                    --Record the purchase
                    dataObject:ArrayInsert("PurchaseHistory", purchaseId)
                    --Indicate that the purchase was successful
                    return Enum.ProductPurchaseDecision.PurchaseGranted
                else
                    --Failed or no callback function
                    return Enum.ProductPurchaseDecision.NotProcessedYet
                end
            end
        end
    end
    --Something went wrong, indicate that purchase should be processed again
    return nil
end

--Double paycheck dev product
idToCallback[1576724296] = function(dataObject)
    --Multiply paycheck by 2 and return result
    return dataObject:MultiplyData("Paycheck", 2)
end

---------------------// PRIVATE CODE \\--------------------

--Connect callback to purchases
MarketplaceService.ProcessReceipt = handlePurchase