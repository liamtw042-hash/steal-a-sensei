--!strict
--[[
	ZoneController: zone gate walls are walk-through locally once you meet the speed
	requirement (the server still validates on pickup), and a prompt shows the requirement
	when you're near an entrance.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- Knit's package entry is typed as the server half; the client half is dynamic, so treat it as `any`.
local Knit = require(ReplicatedStorage.Packages.Knit) :: any
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Make = require(script.Parent.Parent.UI.Make)
local Theme = require(script.Parent.Parent.UI.Theme)

local ZoneController = Knit.CreateController({ Name = "ZoneController" })

type Entry = { zoneId: number, name: string, requirement: number, entrance: BasePart }

local entries: { Entry } = {}
local promptFrame: Frame
local promptTitle: TextLabel
local promptBody: TextLabel

function ZoneController:KnitInit()
	local gui = Make.screen("ZonePrompt", 2)
	promptFrame = Make.frame({
		Size = UDim2.fromOffset(360, 74),
		Position = UDim2.new(0.5, 0, 1, -230),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Theme.panel,
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = gui,
	})
	Make.corner(promptFrame)
	Make.stroke(promptFrame, Theme.accent2, 2, 0.4)
	Make.padding(promptFrame, 14, 8)
	Make.list(promptFrame, 2)
	promptTitle = Make.text({
		Text = "",
		TextSize = 20,
		Font = Theme.fontBlack,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 26),
		Parent = promptFrame,
	})
	promptBody = Make.text({
		Text = "",
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 22),
		Parent = promptFrame,
	})
end

function ZoneController:KnitStart()
	local DataController = Knit.GetController("DataController")
	local zonesFolder = Workspace:WaitForChild("Zones", 60)
	if not zonesFolder then
		warn("[ZoneController] Workspace.Zones never appeared")
		return
	end

	local function scan()
		table.clear(entries)
		for _, def in Config.Zones.List do
			local folder = zonesFolder:FindFirstChild(def.folderName)
			local entrance = if folder then folder:FindFirstChild("Entrance") else nil
			if entrance and entrance:IsA("BasePart") then
				table.insert(
					entries,
					{ zoneId = def.id, name = def.name, requirement = def.speedRequirement, entrance = entrance }
				)
			end
		end
	end
	scan()
	zonesFolder.DescendantAdded:Connect(function()
		task.defer(scan)
	end)

	local player = Players.LocalPlayer
	task.spawn(function()
		while true do
			local speed = DataController.Speed
			local char = player.Character
			local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
			local nearest: Entry? = nil
			local nearestDist = 30
			for _, e in entries do
				local unlocked = speed >= e.requirement
				e.entrance.CanCollide = not unlocked
				e.entrance.CanTouch = false
				if root and root:IsA("BasePart") then
					local d = (e.entrance.Position - root.Position).Magnitude
					if d < nearestDist then
						nearestDist = d
						nearest = e
					end
				end
			end
			if nearest then
				local unlocked = speed >= nearest.requirement
				promptFrame.Visible = true
				promptTitle.Text = nearest.name
				promptTitle.TextColor3 = if unlocked then Theme.green else Theme.red
				promptBody.Text = if unlocked
					then "Gate open — grab a scroll and run home!"
					else `🔒 Requires {Format.short(nearest.requirement)} speed (you have {Format.short(speed)})`
			else
				promptFrame.Visible = false
			end
			task.wait(0.2)
		end
	end)
end

return ZoneController
