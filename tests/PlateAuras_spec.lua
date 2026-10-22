-- CombatPlates 1.7 (owner: "I landed Fear and the plate showed nothing"): CC / immunities / big buffs
-- above enemy plates; uses ArenaFrames' tables
dofile("tests/harness.lua")
UNITS.player = { name = "Me", player = true, guid = "0xME", class = "PRIEST", hp = 1, maxhp = 1 }
LoadAddon("ArenaFrames")
LoadAddon("CombatPlates")

local pass, fail = 0, 0
local function check(cond, label)
  if cond then pass = pass + 1 else fail = fail + 1; print("FAIL: " .. label) end
end
local function cp(s) SlashCmdList.COMBATPLATES(s) end
local function auraRow(p)
  for _, c in ipairs(p._children) do if c.icons then return c end end
end
local function shown(row)
  local out = {}
  for _, b in ipairs(row and row.icons or {}) do if b._shown then table.insert(out, b) end end
  return out
end
local RED, WHITE, BLUE = { 1, 0, 0 }, { 1, 1, 1 }, { 0, 0, 1 }
local function log(sub, dst, id, auraType)
  FireEvent("COMBAT_LOG_EVENT_UNFILTERED", NOW, sub, "0xME", "Me", 0x511, "0x" .. dst, dst, 0x548, id,
    SPELLS[id] or "?", 0x20, auraType)
end

FireEvent("ADDON_LOADED", "ArenaFrames")
FireEvent("ADDON_LOADED", "CombatPlates")
FireEvent("PLAYER_ENTERING_WORLD")

-- a plate tied to a unit (your target): UnitAura, with the time left
local T = MakePlate("Badguy", WHITE, RED, { maxhp = 20000 })
UNITS.target = { name = "Badguy", player = true, guid = "0xB", class = "WARRIOR", hp = 1, maxhp = 1, reaction = 2,
  attackable = true, auras = { { name = "Fear", id = 5782, harmful = true, dur = 8, expires = NOW + 6.5 } } }
Tick(0.2)
local r = shown(auraRow(T))
check(#r == 1 and r[1].icon._tex == "Interface\\Icons\\Fear" and r[1].text._text == "6.5", "your Fear on the target's plate, 6.5 s left")
UNITS.target.auras = { { name = "Fear", id = 5782, harmful = true, dur = 8, expires = NOW + 6.5 },
  { name = "Divine Shield", id = 642, dur = 12, expires = NOW + 11 } }
Tick(0.2)
r = shown(auraRow(T))
check(#r == 2 and r[1].icon._tex:find("DivineShield") and r[1].text._text == 11, "immunity first, then the CC")
UNITS.target.auras = { { name = "Corruption", id = 47813, harmful = true, dur = 18, expires = NOW + 10 } }
Tick(0.2)
check(not auraRow(T)._shown, "DoTs and other auras: nothing")
UNITS.target = nil

-- no unit for the plate: the combat log (no timer)
local O = MakePlate("Otherguy", WHITE, RED, { maxhp = 20000 })
FireEvent("COMBAT_LOG_EVENT_UNFILTERED", NOW, "SWING_DAMAGE", "0xO", "Otherguy", 0x548, "0xME", "Me", 0x511, 100)
log("SPELL_AURA_APPLIED", "Otherguy", 5782, "DEBUFF")
Tick(0.2)
r = shown(auraRow(O))
check(#r == 1 and r[1].icon._tex == "Interface\\Icons\\Fear" and r[1].text._text == "", "combat log: Fear shown, no timer")
log("SPELL_AURA_REMOVED", "Otherguy", 5782, "DEBUFF")
Tick(0.2)
check(not auraRow(O)._shown, "removed: gone")

-- friendly plates get nothing
local F = MakePlate("Buddy", WHITE, BLUE, { maxhp = 20000 })
FireEvent("COMBAT_LOG_EVENT_UNFILTERED", NOW, "SWING_DAMAGE", "0xF", "Buddy", 0x514, "0xX", "X", 0x548, 100)
log("SPELL_AURA_APPLIED", "Buddy", 5782, "DEBUFF")
Tick(0.2)
check(not auraRow(F) or not auraRow(F)._shown, "friendly plates: no aura row")

cp("aurasize 34")
log("SPELL_AURA_APPLIED", "Otherguy", 5782, "DEBUFF")
Tick(0.2)
check(shown(auraRow(O))[1]._w == 34, "aurasize")
cp("auras off")
Tick(0.2)
check(not auraRow(O)._shown, "auras off")

print(string.format("%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
