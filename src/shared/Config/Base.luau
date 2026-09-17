--!strict
--[[
	BASES + PROTECTION
	==================
	Studio side: Workspace.Bases.Base1 .. Base8, each a Folder (or Model) with:
	  - Region     (Part)   invisible box covering the whole base. Inside = safe.
	  - Entrance   (Part)   just outside the gate (boss camps here, intruders are ejected here).
	  - Gates      (Folder) one or more Parts that become laser walls when locked.
	  - LockPad    (Part)   step on it to lock.
	  - PunchingBag (Part)  hold E at it to train Power.
	  - Spawn      (Part)   where the owner respawns.
	  - Slots      (Folder) Parts named Slot1..SlotN with a "Floor" number attribute (1, 2 or 3).
	  - Sign       (Part)   optional, gets a BillboardGui with the owner's name.
	  - GuardPath  (Folder) optional Parts the guard walks between (falls back to Slots).
]]

local Base = {
	Count = 8,
	Floor1Slots = 10,
	Floor2Slots = 8, -- unlocked at rebirth 2
	Floor2Rebirth = 2,
	Floor3Slots = 8, -- unlocked at rebirth 10
	Floor3Rebirth = 10,
	SlotsPerRebirth = 1,
	GamepassBonusSlots = 5, -- "+5 Slots" pass

	Lock = {
		joinLockSeconds = 30, -- auto-lock when you join
		padLockSeconds = 60, -- LockPad lock duration
		perRebirthBonusSeconds = 10,
		vipBonusSeconds = 10,
		cooldownAfterUnlockSeconds = 20, -- can't re-lock for this long after a lock expires
		intruderCheckInterval = 0.4,
	},

	Theft = {
		slowMultiplier = 0.70,
		promptHoldSeconds = 1.5,
		promptDistance = 8,
	},

	Guard = { -- Robux gamepass "Guard"
		walkSpeed = 18,
		slowRadius = 7,
		slowMultiplier = 0.5,
		slowSeconds = 2,
		tickSeconds = 0.5,
	},

	AlarmTrap = { -- cash upgrade
		cost = 25_000,
		stunSeconds = 2,
		ownerSpeedMultiplier = 1.5,
		ownerBoostSeconds = 8,
		cooldownSeconds = 30,
	},

	Earning = {
		tickSeconds = 1,
		vipCashMultiplier = 2,
	},
}

return Base
