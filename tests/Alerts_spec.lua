-- ArenaFrames 3.6: alerts by your class / spec. Rogue: Kick alerts (Polymorph + heals).
dofile("tests/harness.lua")
UNITS.player = { name = "Me", player = true, guid = "0xME", class = "ROGUE", hp = 1, maxhp = 1 }
LoadAddon("ArenaFrames")

local pass, fail = 0, 0
local function check(cond, label)
  if cond then pass = pass + 1 else fail = fail + 1; print("FAIL: " .. label) end
end
local function cmd(s) SlashCmdList.ARENAFRAMES(s) end
local function rows()
  local out = {}
  for i = 1, 3 do local r = _G["ArenaFramesAlert" .. i]; if r._shown then table.insert(out, r) end end
  return out
end
local function step() for _ = 1, 3 do Tick(0.05) end end

FireEvent("ADDON_LOADED", "ArenaFrames")
FireEvent("PLAYER_ENTERING_WORLD")
INSTANCE = "arena"
FireEvent("ZONE_CHANGED_NEW_AREA")
UNITS.arena1 = { name = "Healbot", player = true, guid = "0xA1", class = "PALADIN", hp = 1, maxhp = 1, reaction = 2 }
UNITS.arena2 = { name = "Frostbolt", player = true, guid = "0xA2", class = "MAGE", hp = 1, maxhp = 1, reaction = 2 }
Tick(0.2)
step()
check(#rows() == 0, "nothing cast: no alerts")

UNITS.arena1.cast = { name = "Flash of Light", start = NOW, endt = NOW + 1.5 }
IN_RANGE.arena1 = 1
step()
local r = rows()
check(#r == 1 and r[1].label._text == "Flash of Light - Healbot (1)" and r[1].status._text == "KICK!",
  "enemy heal in Kick range, Kick ready -> KICK!")
check(r[1].icon.icon._tex == "casticon", "the cast's own icon (from UnitCastingInfo)")
IN_RANGE.arena1 = 0; step()
check(rows()[1].status._text == "out of range", "out of range")
IN_RANGE.arena1 = 1; SPELL_CD.Kick = { NOW - 2, 10 }; step()
check(rows()[1].status._text == "Kick 8.0", "Kick on cooldown with time left")
SPELL_CD.Kick = { NOW, 1 }; step()
check(rows()[1].status._text == "KICK!", "just the GCD doesn't count")
SPELL_CD.Kick = nil
NO_POWER.Kick = true; step()
check(rows()[1].status._text == "no energy", "not enough energy")
NO_POWER.Kick = nil

UNITS.arena2.cast = { name = "Polymorph", start = NOW, endt = NOW + 1.5 }
IN_RANGE.arena2 = 0
step()
check(#rows() == 2, "Polymorph too, both shown")
UNITS.arena1.cast = { name = "Divine Shield", start = NOW, endt = NOW + 1 }
step()
check(#rows() == 1 and rows()[1].label._text:find("Polymorph"), "casts we don't kick are left out")
UNITS.arena2.cast = { name = "Polymorph", start = NOW, endt = NOW + 1.5, notInt = true }
step()
check(#rows() == 0, "uninterruptible: no alert")
UNITS.arena2.cast = { name = "Penance", start = NOW, endt = NOW + 2, channel = true }
UNITS.target = UNITS.arena2
step()
check(#rows() == 1, "channels too (Penance), and the same enemy as target is shown once")
UNITS.target = nil
UNITS.arena1.cast, UNITS.arena2.cast = nil, nil
step()
check(#rows() == 0, "cast over -> gone")

-- unlock preview, help, off
cmd("unlock"); step()
check(#rows() == 2 and ArenaFramesAlerts.bg._shown, "unlock: preview + drag handle")
cmd("lock"); step()
check(#rows() == 0, "lock: preview gone")
CHAT = {}
cmd("")
check(table.concat(CHAT, "\n"):find("Kick alerts for Polymorph and heals"), "help says what you get as a rogue")
cmd("alerts off")
UNITS.arena1.cast = { name = "Flash of Light", start = NOW, endt = NOW + 1.5 }
step()
check(#rows() == 0, "alerts off")

check(ArenaFramesSWD == nil, "rogue: no SWD button")
print(string.format("%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
