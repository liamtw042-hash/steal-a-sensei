--!strict
--[[
	PathWalker: pathfinding + waypoint following for a Humanoid rig.
	Call :Step(goal) repeatedly (every ~0.1s). It recomputes the path on an interval and
	falls back to a straight MoveTo when no path exists. Yields briefly while computing.
]]
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local PathWalker = {}
PathWalker.__index = PathWalker

type Fields = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	path: Path,
	waypoints: { PathWaypoint }?,
	wpIndex: number,
	lastComputeAt: number,
	lastGoal: Vector3?,
	recomputeSeconds: number,
	stuckSince: number?,
	lastPos: Vector3,
}

export type PathWalker = typeof(setmetatable({} :: Fields, PathWalker))

function PathWalker.new(model: Model, recomputeSeconds: number?): PathWalker?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		return nil
	end
	local fields: Fields = {
		model = model,
		humanoid = humanoid,
		root = root,
		path = PathfindingService:CreatePath({
			AgentRadius = 2.5,
			AgentHeight = 5,
			AgentCanJump = true,
			AgentCanClimb = false,
			WaypointSpacing = 4,
		}),
		waypoints = nil,
		wpIndex = 1,
		lastComputeAt = 0,
		lastGoal = nil,
		recomputeSeconds = recomputeSeconds or Config.Zones.Boss.pathRecomputeSeconds,
		stuckSince = nil,
		lastPos = root.Position,
	}
	return setmetatable(fields, PathWalker)
end

local function flatDistance(a: Vector3, b: Vector3): number
	return (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
end

function PathWalker.Reset(self: PathWalker)
	self.waypoints = nil
	self.wpIndex = 1
	self.lastComputeAt = 0
	self.lastGoal = nil
end

-- Returns the flat distance remaining to the goal
function PathWalker.Step(self: PathWalker, goal: Vector3): number
	local now = os.clock()
	local root = self.root
	local lastGoal = self.lastGoal
	local goalMoved = lastGoal == nil or (lastGoal - goal).Magnitude > 3
	if self.waypoints == nil or goalMoved or now - self.lastComputeAt > self.recomputeSeconds then
		self.lastComputeAt = now
		self.lastGoal = goal
		local ok = pcall(function()
			self.path:ComputeAsync(root.Position, goal)
		end)
		if ok and self.path.Status == Enum.PathStatus.Success then
			self.waypoints = self.path:GetWaypoints()
			self.wpIndex = 2
		else
			self.waypoints = nil
		end
	end

	local reach = Config.Zones.Boss.waypointReachStuds
	local wps = self.waypoints
	if wps then
		local wp: PathWaypoint? = wps[self.wpIndex]
		while wp and flatDistance(wp.Position, root.Position) < reach do
			self.wpIndex += 1
			wp = wps[self.wpIndex]
		end
		if wp then
			if wp.Action == Enum.PathWaypointAction.Jump then
				self.humanoid.Jump = true
			end
			self.humanoid:MoveTo(wp.Position)
		else
			self.humanoid:MoveTo(goal)
		end
	else
		self.humanoid:MoveTo(goal)
	end

	-- stuck detection: nudge with a jump, and force a recompute
	if (root.Position - self.lastPos).Magnitude < 0.2 then
		local since = self.stuckSince
		if not since then
			self.stuckSince = now
		elseif now - since > 1.2 then
			self.humanoid.Jump = true
			self.waypoints = nil
			self.stuckSince = nil
		end
	else
		self.stuckSince = nil
	end
	self.lastPos = root.Position

	return flatDistance(goal, root.Position)
end

function PathWalker.Stop(self: PathWalker)
	self.humanoid:MoveTo(self.root.Position)
	self:Reset()
end

return PathWalker
