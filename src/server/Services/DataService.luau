--!strict
--[[
	DataService
	===========
	ProfileService-backed player data with session locking, retries and safe shutdown.
	Other services read/modify `DataService:Get(player)` and call `Replicate(player)` after
	structural changes. Cash/tokens/rebirths have their own live properties for the HUD.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local ProfileService = require(ServerStorage.ServerPackages.ProfileService)
local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)

type PlayerData = Types.PlayerData

local function template(): PlayerData
	return {
		version = 1,
		cash = Config.General.startingCash,
		speed = 0,
		tokens = 0,
		rebirths = 0,
		treadmillLevel = 1,
		nextFighterId = 1,
		fighters = {},
		hatching = {},
		scrollBag = {},
		index = {},
		indexClaimed = {},
		skins = {},
		freeRewards = { like = false, favourite = false, group = false },
		gear = { Slap = false, Trap = 0, SmokeBomb = 0, Grapple = false, BodySwap = 0, Shield = false },
		gamepasses = {},
		alarmTrap = false,
		friends = {},
		stats = { scrollsSecured = 0, fightersStolen = 0, timesCaught = 0, playtime = 0 },
	}
end

local DataService = Knit.CreateService({
	Name = "DataService",
	Client = {
		Snapshot = Knit.CreateProperty(nil),
		Cash = Knit.CreateProperty(0),
		Tokens = Knit.CreateProperty(0),
		Rebirths = Knit.CreateProperty(0),
	},
	-- Signals other services hook
	Loaded = Signal.new(), -- (player, data)
	Released = Signal.new(), -- (player)
	CashChanged = Signal.new(), -- (player, newCash)
})

local profiles: { [Player]: any } = {}
local profileStore: any = nil

function DataService:KnitInit()
	profileStore = (ProfileService :: any).GetProfileStore(Config.General.dataStoreName, template())
	assert(profileStore, "ProfileStore failed to initialise")
end

function DataService:KnitStart()
	Players.PlayerAdded:Connect(function(player)
		self:_load(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			self:_load(player)
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		self:_release(player)
	end)

	-- playtime + periodic snapshot push
	task.spawn(function()
		while true do
			task.wait(Config.General.snapshotIntervalSeconds)
			for player, profile in profiles do
				local data = profile.Data :: PlayerData
				data.stats.playtime += Config.General.snapshotIntervalSeconds
				self:Replicate(player)
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() then
			-- ProfileService releases on its own; give it a moment in Studio so the mock store persists
			task.wait(1)
			return
		end
		for player, _ in profiles do
			self:_release(player)
		end
		-- ProfileService blocks the close until saves finish
	end)
end

function DataService:_load(player: Player)
	if profiles[player] then
		return
	end
	local key = `Player_{player.UserId}`
	local profile = (profileStore :: any):LoadProfileAsync(key, "ForceLoad")
	if not profile then
		player:Kick("Your data could not be loaded. Please rejoin in a moment.")
		return
	end
	profile:AddUserId(player.UserId)
	profile:Reconcile()
	profile:ListenToRelease(function()
		profiles[player] = nil
		if player.Parent then
			player:Kick("Your data was loaded on another server. Please rejoin.")
		end
	end)
	if not player:IsDescendantOf(Players) then
		profile:Release()
		return
	end
	profiles[player] = profile
	local data = profile.Data :: PlayerData
	self:_setupLeaderstats(player, data)
	self.Client.Cash:SetFor(player, data.cash)
	self.Client.Tokens:SetFor(player, data.tokens)
	self.Client.Rebirths:SetFor(player, data.rebirths)
	self:Replicate(player)
	self.Loaded:Fire(player, data)
end

function DataService:_release(player: Player)
	local profile = profiles[player]
	if profile then
		self.Released:Fire(player)
		profiles[player] = nil
		profile:Release()
	end
end

function DataService:_setupLeaderstats(player: Player, data: PlayerData)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local cash = Instance.new("NumberValue")
	cash.Name = "Cash"
	cash.Value = data.cash
	cash.Parent = ls
	local rb = Instance.new("IntValue")
	rb.Name = "Rebirths"
	rb.Value = data.rebirths
	rb.Parent = ls
	ls.Parent = player
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

function DataService:Get(player: Player): PlayerData?
	local profile = profiles[player]
	return if profile then profile.Data :: PlayerData else nil
end

function DataService:IsLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

-- Yields until the player's data is loaded (or they leave). Returns nil if they left.
function DataService:WaitFor(player: Player, timeout: number?): PlayerData?
	local deadline = os.clock() + (timeout or 30)
	while not profiles[player] do
		if not player.Parent or os.clock() > deadline then
			return nil
		end
		task.wait(0.1)
	end
	return self:Get(player)
end

function DataService:Replicate(player: Player)
	local data = self:Get(player)
	if data then
		self.Client.Snapshot:SetFor(player, data)
	end
end

function DataService:SetCash(player: Player, amount: number)
	local data = self:Get(player)
	if not data then
		return
	end
	data.cash = math.max(0, math.floor(amount))
	self.Client.Cash:SetFor(player, data.cash)
	local ls = player:FindFirstChild("leaderstats")
	local v = if ls then ls:FindFirstChild("Cash") else nil
	if v and v:IsA("NumberValue") then
		v.Value = data.cash
	end
	self.CashChanged:Fire(player, data.cash)
end

function DataService:AddCash(player: Player, amount: number)
	local data = self:Get(player)
	if data then
		self:SetCash(player, data.cash + amount)
	end
end

-- Returns true if the cash was taken
function DataService:SpendCash(player: Player, amount: number): boolean
	local data = self:Get(player)
	if not data or data.cash < amount then
		return false
	end
	self:SetCash(player, data.cash - amount)
	return true
end

function DataService:AddTokens(player: Player, amount: number)
	local data = self:Get(player)
	if data then
		data.tokens = math.max(0, math.floor(data.tokens + amount))
		self.Client.Tokens:SetFor(player, data.tokens)
	end
end

function DataService:SpendTokens(player: Player, amount: number): boolean
	local data = self:Get(player)
	if not data or data.tokens < amount then
		return false
	end
	self:AddTokens(player, -amount)
	return true
end

function DataService:SetRebirths(player: Player, n: number)
	local data = self:Get(player)
	if not data then
		return
	end
	data.rebirths = n
	self.Client.Rebirths:SetFor(player, n)
	local ls = player:FindFirstChild("leaderstats")
	local v = if ls then ls:FindFirstChild("Rebirths") else nil
	if v and v:IsA("IntValue") then
		v.Value = n
	end
end

function DataService.Client:GetData(player: Player): PlayerData?
	return self.Server:Get(player)
end

return DataService
