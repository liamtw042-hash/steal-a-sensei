--!strict
--[[
	MonetizationService
	===================
	Gamepass ownership (checked on join, cached in the profile so it survives API hiccups),
	purchase prompts, and developer-product receipts for the combat shop.
]]
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Config = require(ReplicatedStorage.Shared.Config)

local MonetizationService = Knit.CreateService({
	Name = "MonetizationService",
	Client = {
		Purchased = Knit.CreateSignal(), -- (kind, key)
	},
	GamepassGranted = Signal.new(), -- (player, key)
	ProductGranted = Signal.new(), -- (player, key)
})

local DataService: any

function MonetizationService:KnitInit()
	DataService = Knit.GetService("DataService")
end

function MonetizationService:KnitStart()
	DataService.Loaded:Connect(function(player: Player)
		task.spawn(function()
			self:_checkAllPasses(player)
		end)
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local def = Config.Monetization.gamepassById(passId)
		if def then
			self:GrantGamepass(player, def.key)
		end
	end)

	MarketplaceService.ProcessReceipt = function(receipt)
		return self:_processReceipt(receipt)
	end
end

function MonetizationService:_checkAllPasses(player: Player)
	local data = DataService:Get(player)
	if not data then
		return
	end
	local changed = false
	for _, def in Config.Monetization.Gamepasses do
		if def.id == 0 or data.gamepasses[def.key] then
			continue
		end
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, def.id)
		end)
		if ok and owns then
			data.gamepasses[def.key] = true
			changed = true
			self.GamepassGranted:Fire(player, def.key)
		end
	end
	if changed then
		DataService:Replicate(player)
	end
end

function MonetizationService:Owns(player: Player, key: string): boolean
	local data = DataService:Get(player)
	return data ~= nil and data.gamepasses[key] == true
end

function MonetizationService:GrantGamepass(player: Player, key: string)
	local data = DataService:Get(player)
	if not data or data.gamepasses[key] then
		return
	end
	data.gamepasses[key] = true
	DataService:Replicate(player)
	self.GamepassGranted:Fire(player, key)
	self.Client.Purchased:Fire(player, "gamepass", key)
end

function MonetizationService:GrantProduct(player: Player, key: string): boolean
	local data = DataService:Get(player)
	local def = Config.Monetization.product(key)
	if not data or not def then
		return false
	end
	local gear = data.gear :: any
	if def.kind == "permanent" then
		gear[key] = true
	else
		gear[key] = (gear[key] or 0) + (def.uses or 1)
	end
	DataService:Replicate(player)
	self.ProductGranted:Fire(player, key)
	self.Client.Purchased:Fire(player, "product", key)
	return true
end

function MonetizationService:_processReceipt(receipt: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = DataService:WaitFor(player, 10)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local def = Config.Monetization.productById(receipt.ProductId)
	if not def then
		warn(`[Monetization] unknown product id {receipt.ProductId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if self:GrantProduct(player, def.key) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

--------------------------------------------------------------------------------
-- Client API
--------------------------------------------------------------------------------

function MonetizationService.Client:PromptGamepass(player: Player, key: string): (boolean, string)
	local def = Config.Monetization.gamepass(key)
	if not def then
		return false, "Unknown gamepass"
	end
	if self.Server:Owns(player, key) then
		return false, "Already owned"
	end
	if def.id == 0 then
		return false, `"{def.name}" has no gamepass id yet (set it in Config/Monetization.luau)`
	end
	MarketplaceService:PromptGamePassPurchase(player, def.id)
	return true, "Prompted"
end

function MonetizationService.Client:PromptProduct(player: Player, key: string): (boolean, string)
	local def = Config.Monetization.product(key)
	if not def then
		return false, "Unknown product"
	end
	local data = DataService:Get(player)
	if def.kind == "permanent" and data and (data.gear :: any)[key] == true then
		return false, "Already owned"
	end
	if def.id == 0 then
		return false, `"{def.name}" has no product id yet (set it in Config/Monetization.luau)`
	end
	MarketplaceService:PromptProductPurchase(player, def.id)
	return true, "Prompted"
end

return MonetizationService
