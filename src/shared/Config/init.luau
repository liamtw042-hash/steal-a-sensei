--!strict
-- Single entry point for all tuning. `local Config = require(ReplicatedStorage.Shared.Config)`
local Config = {
	Zones = require(script.Zones),
	Fighters = require(script.Fighters),
	Speed = require(script.Speed),
	Base = require(script.Base),
	Rebirth = require(script.Rebirth),
	Monetization = require(script.Monetization),
	Events = require(script.Events),

	General = {
		startingCash = 0,
		-- Data store name. Change it to reset everyone's data (e.g. "Player_v2").
		dataStoreName = "Player_v1",
		-- How often the full profile snapshot is pushed to the client (structural changes push immediately).
		snapshotIntervalSeconds = 5,
	},
}

return Config
