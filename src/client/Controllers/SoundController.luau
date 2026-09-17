--!strict
-- SoundController: plays UI/feedback sounds for game events (see Shared/Sounds.luau).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

-- Knit's package entry is typed as the server half; the client half is dynamic, so treat it as `any`.
local Knit = require(ReplicatedStorage.Packages.Knit) :: any
local Sounds = require(ReplicatedStorage.Shared.Sounds)

local SoundController = Knit.CreateController({ Name = "SoundController" })

local cache: { [string]: Sound } = {}
local lastPlayed: { [string]: number } = {}

local function get(name: string): Sound?
	local existing = cache[name]
	if existing then
		return existing
	end
	local def = Sounds[name]
	if not def then
		return nil
	end
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = def.id
	s.Volume = def.volume
	s.PlaybackSpeed = def.pitch or 1
	s.Parent = SoundService
	cache[name] = s
	return s
end

-- Play a named sound. `minGap` throttles spammy sounds (seconds).
function SoundController:Play(name: string, minGap: number?)
	local now = os.clock()
	if minGap and (lastPlayed[name] or 0) + minGap > now then
		return
	end
	lastPlayed[name] = now
	local s = get(name)
	if s then
		-- clone so overlapping plays don't cut each other off
		local c = s:Clone()
		c.Parent = SoundService
		c.Ended:Once(function()
			c:Destroy()
		end)
		c:Play()
		task.delay(6, function()
			if c.Parent then
				c:Destroy()
			end
		end)
	end
end

function SoundController:KnitStart()
	local DataController = Knit.GetController("DataController")
	local CarryService = Knit.GetService("CarryService")
	local FighterService = Knit.GetService("FighterService")
	local BossService = Knit.GetService("BossService")
	local BaseService = Knit.GetService("BaseService")
	local MonetizationService = Knit.GetService("MonetizationService")
	local RebirthService = Knit.GetService("RebirthService")
	local PowerService = Knit.GetService("PowerService")
	local TheftService = Knit.GetService("TheftService")
	local CombatService = Knit.GetService("CombatService")
	local EventService = Knit.GetService("EventService")

	CarryService.Changed:Connect(function(info: any)
		if info then
			self:Play("grab")
		end
	end)
	FighterService.Hatched:Connect(function()
		self:Play("hatch")
	end)
	FighterService.Evolved:Connect(function()
		self:Play("rebirth")
	end)
	FighterService.Notice:Connect(function(text: string)
		if text:find("secured") or text:find("returned") or text:find("Stole") then
			self:Play("secured")
		end
	end)
	BossService.ChaseState:Connect(function(bossName: string?)
		if bossName then
			self:Play("roar", 2)
		end
	end)
	BossService.Caught:Connect(function()
		self:Play("impact")
		self:Play("caught")
	end)
	BaseService.Alert:Connect(function(_text: string, kind: string)
		if kind == "lock" then
			self:Play("lock")
		elseif kind == "unlock" then
			self:Play("unlock")
		elseif kind == "alarm" then
			self:Play("alarm", 1)
		elseif kind == "warn" then
			self:Play("error", 0.5)
		end
	end)
	BaseService.TheftAlert:Connect(function()
		self:Play("alarm")
	end)
	TheftService.Started:Connect(function()
		self:Play("steal")
	end)
	MonetizationService.Purchased:Connect(function()
		self:Play("purchase")
	end)
	RebirthService.Rebirthed:Connect(function()
		self:Play("rebirth")
	end)
	PowerService.Stunned:Connect(function()
		self:Play("stun")
	end)
	CombatService.Effect:Connect(function(kind: string)
		if kind == "slap" then
			self:Play("slap")
		elseif kind == "trap" then
			self:Play("stun")
		end
	end)
	EventService.Announce:Connect(function()
		self:Play("rift", 3)
	end)

	-- soft cash tick while income flows (at most once a second)
	local lastCash = DataController.Cash
	DataController.CashChanged:Connect(function(cash: number)
		if cash > lastCash then
			self:Play("cashTick", 1)
		end
		lastCash = cash
	end)
end

return SoundController
