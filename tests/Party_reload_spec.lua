-- Regression (3.4.2 in game): /reload or login while already in a group crashed the frame
-- setup ("attempt to index field 'hpText'"): party frames were drawn with the target code.
dofile("tests/harness.lua")
UNITS.player = { name = "Me", player = true, guid = "0xME", class = "ROGUE", hp = 1, maxhp = 1 }
UNITS.party1 = { name = "Elcemento", player = true, guid = "0xP1", class = "ROGUE", hp = 100, maxhp = 200, reaction = 5 }
UNITS.party2 = { name = "Hydramon", player = true, guid = "0xP2", class = "PRIEST", hp = 50, maxhp = 100,
  ptype = 0, power = 10, maxpower = 20, reaction = 5 }
UNITS.target = { name = "Enemy", player = true, guid = "0xT1", class = "MAGE", hp = 1, maxhp = 1, reaction = 2 }
LoadAddon("ArenaFrames")

local pass, fail = 0, 0
local function check(cond, label)
  if cond then pass = pass + 1 else fail = fail + 1; print("FAIL: " .. label) end
end

FireEvent("ADDON_LOADED", "ArenaFrames")
check(not table.concat(CHAT, "\n"):find("failed"), "no load error with a party and a target already there")
Tick(0.2)
check(ArenaFramesParty1._shown and ArenaFramesParty1.name._text == "Elcemento" and ArenaFramesParty1.hp._val == 100,
  "party frames drawn right away")
check(ArenaFramesTarget._shown and ArenaFramesTarget.name._text == "Enemy", "target frame too")
CHAT = {}
SlashCmdList.ARENAFRAMES("")
check(table.concat(CHAT, "\n"):find("frames: on"), "state is on (not 'error')")

print(string.format("%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
