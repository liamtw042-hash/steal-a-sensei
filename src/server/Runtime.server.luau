--!strict
-- Server bootstrap: builds the dev map if there's no real one, then starts every Knit service.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local DevMap = require(script.Parent.Util.DevMap)
DevMap.ensure()

Knit.AddServices(script.Parent.Services)

Knit.Start()
	:andThen(function()
		print("[StealASensei] server started")
	end)
	:catch(function(err)
		warn("[StealASensei] server failed to start:", err)
	end)
