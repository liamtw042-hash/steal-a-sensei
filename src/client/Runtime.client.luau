--!strict
-- Client bootstrap: loads every controller and starts Knit.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- Knit's package entry is typed as the server half; the client half is dynamic, so treat it as `any`.
local Knit = require(ReplicatedStorage.Packages.Knit) :: any

Knit.AddControllers(script.Parent.Controllers)

Knit.Start({ ServicePromises = false })
	:andThen(function()
		print("[StealASensei] client started")
	end)
	:catch(function(err)
		warn("[StealASensei] client failed to start:", err)
	end)
