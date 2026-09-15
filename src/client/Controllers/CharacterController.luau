--!strict
--[[
	CharacterController: player animation extras. Walk/run/jump come from Roblox's default
	Animate script. This adds a looped "carry" pose (arms up) while holding a scroll or
	fighter, using Roblox's built-in tool-hold animation.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Knit's package entry is typed as the server half; the client half is dynamic, so treat it as `any`.
local Knit = require(ReplicatedStorage.Packages.Knit) :: any

local CharacterController = Knit.CreateController({ Name = "CharacterController" })

local CARRY_ANIM = "rbxassetid://507768375" -- R15 "tool none" hold pose

local localPlayer = Players.LocalPlayer
local carryTrack: AnimationTrack? = nil
local carrying = false

local function loadCarry(char: Model): AnimationTrack?
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local animator = if humanoid then humanoid:FindFirstChildOfClass("Animator") else nil
	if not animator then
		return nil
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = CARRY_ANIM
	local ok, track = pcall(function()
		return (animator :: Animator):LoadAnimation(anim)
	end)
	if not ok then
		return nil
	end
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = true
	return track
end

local function apply()
	local track = carryTrack
	if not track then
		return
	end
	if carrying and not track.IsPlaying then
		track:Play(0.2)
	elseif not carrying and track.IsPlaying then
		track:Stop(0.2)
	end
end

function CharacterController:KnitStart()
	local CarryService = Knit.GetService("CarryService")

	local function onCharacter(char: Model)
		carryTrack = nil
		task.spawn(function()
			char:WaitForChild("Humanoid", 10)
			task.wait(0.2)
			carryTrack = loadCarry(char)
			apply()
		end)
	end
	if localPlayer.Character then
		onCharacter(localPlayer.Character)
	end
	localPlayer.CharacterAdded:Connect(onCharacter)

	CarryService.Changed:Connect(function(info: any)
		carrying = info ~= nil
		apply()
	end)
end

return CharacterController
