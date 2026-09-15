--!strict
--[[
	Sound library. These are Roblox's built-in `rbxasset://sounds/` files that ship with
	every client, so they always play, never get moderated and cost nothing. Swap any entry
	for an `rbxassetid://<id>` from the Creator Store once you've picked real sounds.
]]
export type SoundDef = { id: string, volume: number, pitch: number? }

local Sounds: { [string]: SoundDef } = {
	grab = { id = "rbxasset://sounds/unsheath.wav", volume = 0.6, pitch = 1.2 },
	hatch = { id = "rbxasset://sounds/Short spring sound.wav", volume = 0.8, pitch = 1.1 },
	cashTick = { id = "rbxasset://sounds/clickfast.wav", volume = 0.15, pitch = 1.4 },
	roar = { id = "rbxasset://sounds/HalloweenGhost.wav", volume = 0.9, pitch = 0.7 },
	caught = { id = "rbxasset://sounds/uuhhh.mp3", volume = 0.9 },
	impact = { id = "rbxasset://sounds/impact_generic.mp3", volume = 0.7 },
	lock = { id = "rbxasset://sounds/switch3.wav", volume = 0.8 },
	unlock = { id = "rbxasset://sounds/snap.wav", volume = 0.6 },
	purchase = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.8 },
	rebirth = { id = "rbxasset://sounds/victory.wav", volume = 0.9 },
	secured = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.7, pitch = 0.85 },
	click = { id = "rbxasset://sounds/button.wav", volume = 0.5 },
	slap = { id = "rbxasset://sounds/swordslash.wav", volume = 0.8 },
	stun = { id = "rbxasset://sounds/collide.wav", volume = 0.7 },
	alarm = { id = "rbxasset://sounds/HalloweenLightning.wav", volume = 0.7, pitch = 1.3 },
	steal = { id = "rbxasset://sounds/swordlunge.wav", volume = 0.8 },
	error = { id = "rbxasset://sounds/bass.wav", volume = 0.5, pitch = 1.5 },
	rift = { id = "rbxasset://sounds/Launching rocket.wav", volume = 0.6, pitch = 0.6 },
}

return Sounds
