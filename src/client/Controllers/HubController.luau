--!strict
-- HubController: hub props (shop stall, fuse machine, rebirth shrine, index board) carry a
-- ProximityPrompt with a HubAction attribute; triggering one opens the matching window.
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Knit's package entry is typed as the server half; the client half is dynamic, so treat it as `any`.
local Knit = require(ReplicatedStorage.Packages.Knit) :: any

local HubController = Knit.CreateController({ Name = "HubController" })

function HubController:KnitStart()
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		if prompt.Name ~= "HubPrompt" then
			return
		end
		local part = prompt.Parent
		local action = if part then part:GetAttribute("HubAction") else nil
		if action == "Shop" then
			Knit.GetController("ShopController"):Open()
		elseif action == "Index" then
			Knit.GetController("IndexController"):Open()
		elseif action == "Rebirth" then
			Knit.GetController("RebirthController"):Open()
		elseif action == "Fuse" then
			Knit.GetController("BaseController"):Open("Inventory")
		end
	end)
end

return HubController
