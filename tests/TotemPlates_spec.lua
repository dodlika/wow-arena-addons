-- CombatPlates 1.6: totem, Succubus and Felhunter plates -> a big spell icon (owner's screenshot)
dofile("tests/harness.lua")
UNITS.player = { name = "Me", player = true, guid = "0xME", class = "ROGUE", hp = 1, maxhp = 1 }
SPELLS[8177], SPELLS[8143] = "Grounding Totem", "Tremor Totem"
SPELLS[712], SPELLS[691], SPELLS[19647] = "Summon Succubus", "Summon Felhunter", "Spell Lock"
LoadAddon("CombatPlates")

local pass, fail = 0, 0
local function check(cond, label)
  if cond then pass = pass + 1 else fail = fail + 1; print("FAIL: " .. label) end
end
local function cp(s) SlashCmdList.COMBATPLATES(s) end
local function iconW(p)
  for _, c in ipairs(p._children) do if c._type == "Frame" and c.icon and c.hp then return c end end
end
local RED, WHITE = { 1, 0, 0 }, { 1, 1, 1 }

FireEvent("ADDON_LOADED", "CombatPlates")
FireEvent("PLAYER_ENTERING_WORLD")

local G = MakePlate("Grounding Totem", WHITE, RED, { maxhp = 5 })
local T = MakePlate("Tremor Totem", WHITE, RED, { maxhp = 5 })
local S = MakePlate("Jhaarsi", WHITE, RED, { maxhp = 8000, hp = 4000 })
local F = MakePlate("Grimkah", WHITE, RED, { maxhp = 8000 })
local N = MakePlate("Badguy", WHITE, RED, { maxhp = 20000 })
Tick(0.2)
local g = iconW(G)
check(g and g._shown and g.icon._tex == "Interface\\Icons\\GroundingTotem" and g._w == 36,
  "totem plate -> its spell icon, 36 px")
check(G._hp._alpha == 0 and not g.hp._shown, "plate blanked, no health bar on totems")
check(iconW(T) and iconW(T)._shown, "Tremor too")
check(not iconW(N), "a player plate is left alone")
check(not iconW(S), "a demon with an unknown family: left alone")

-- Succubus learned from its family (arena pet token), Felhunter from a spell it cast
UNITS.arenapet1 = { name = "Jhaarsi", guid = "0xPET1", family = "Succubus", hp = 1, maxhp = 1 }
FireEvent("COMBAT_LOG_EVENT_UNFILTERED", NOW, "SPELL_CAST_SUCCESS", "0xPET2", "Grimkah", 0x1148, "0xME", "Me",
  0x511, 19647, "Spell Lock", 0x20)
Tick(0.2)
local s = iconW(S)
check(s and s._shown and s.icon._tex == "Interface\\Icons\\SummonSuccubus", "Succubus (family) -> Summon Succubus icon")
check(s.hp._shown and s.hp._val == 4000, "demons keep a small health bar")
check(iconW(F) and iconW(F).icon._tex == "Interface\\Icons\\SummonFelhunter", "Felhunter (cast Spell Lock) -> its icon")

-- plates are recycled: the same plate frame shows a player next
G._nameFS:SetText("Otherguy")
Tick(0.2)
check(not g._shown and G._hp._alpha == 1, "recycled plate: icon gone, plate given back")

cp("totemsize 50")
Tick(0.2)
check(iconW(T)._w == 50, "totemsize")
cp("totems off")
Tick(0.2)
check(not iconW(T)._shown and T._hp._alpha == 1, "totems off: normal plates")

print(string.format("%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
