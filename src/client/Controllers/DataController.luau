--!strict
-- Mirrors the player's profile snapshot on the client and fires Changed when it updates.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Knit's package entry is typed as the server half; the client half is dynamic, so treat it as `any`.
local Knit = require(ReplicatedStorage.Packages.Knit) :: any
local Signal = require(ReplicatedStorage.Packages.Signal)
local Types = require(ReplicatedStorage.Shared.Types)

local DataController = Knit.CreateController({
	Name = "DataController",
	Data = nil :: Types.PlayerData?,
	Changed = Signal.new(), -- (data)
	Cash = 0,
	Tokens = 0,
	Rebirths = 0,
	Speed = 0, -- effective speed stat
	CashChanged = Signal.new(),
	SpeedChanged = Signal.new(),
})

function DataController:KnitStart()
	local DataService = Knit.GetService("DataService")
	local SpeedService = Knit.GetService("SpeedService")

	DataService.Snapshot:Observe(function(data: Types.PlayerData?)
		if data then
			self.Data = data
			self.Changed:Fire(data)
		end
	end)
	DataService.Cash:Observe(function(v: number)
		self.Cash = v or 0
		self.CashChanged:Fire(self.Cash)
	end)
	DataService.Tokens:Observe(function(v: number)
		self.Tokens = v or 0
	end)
	DataService.Rebirths:Observe(function(v: number)
		self.Rebirths = v or 0
	end)
	SpeedService.Speed:Observe(function(v: number)
		self.Speed = v or 0
		self.SpeedChanged:Fire(self.Speed)
	end)
end

function DataController:Get(): Types.PlayerData?
	return self.Data
end

-- Convenience: run fn now (if data exists) and on every change
function DataController:Observe(fn: (Types.PlayerData) -> ())
	if self.Data then
		task.spawn(fn, self.Data)
	end
	return self.Changed:Connect(fn)
end

return DataController
