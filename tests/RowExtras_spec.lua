-- ArenaFrames 3.12 (owner picked them): range fading, enemy pets under the rows, big cooldown alert
dofile("tests/harness.lua")
UNITS.player = { name = "Me", player = true, guid = "0xME", class = "PRIEST", hp = 1, maxhp = 1 }
SPELLS[32379] = "Shadow Word: Death"
SPELLS[46924], SPELLS[19647] = "Bladestorm", "Spell Lock"
LoadAddon("ArenaFrames")

local pass, fail = 0, 0
local function check(cond, label)
  if cond then pass = pass + 1 else fail = fail + 1; print("FAIL: " .. label) end
end
local function cmd(s) SlashCmdList.ARENAFRAMES(s) end
local function row(i) return _G["ArenaFramesRow" .. i] end
local ENEMY, ENEMY_PET, FRIEND = 0x0548, 0x1148, 0x0514
local function cast(src, flags, id)
  FireEvent("COMBAT_LOG_EVENT_UNFILTERED", NOW, "SPELL_CAST_SUCCESS", src, "x", flags, nil, nil, nil, id,
    SPELLS[id] or "?", 1)
end

FireEvent("ADDON_LOADED", "ArenaFrames")
INSTANCE = "arena"
FireEvent("PLAYER_ENTERING_WORLD")
UNITS.arena1 = { name = "Warr", player = true, guid = "0xA1", class = "WARRIOR", hp = 1, maxhp = 1 }
UNITS.arena2 = { name = "Lock", player = true, guid = "0xA2", class = "WARLOCK", hp = 1, maxhp = 1 }
UNITS.arenapet2 = { name = "Grimkah", guid = "0xP2", hp = 3000, maxhp = 6000 }
Tick(0.2)

-- range
check(row(1)._alpha == 1, "in range: full")
IN_RANGE.arena1 = 0; Tick(0.2)
check(row(1)._alpha == 0.5, "out of SWD range: faded")
cmd("range off"); Tick(0.2)
check(row(1)._alpha == 1, "range off")
cmd("range on"); IN_RANGE.arena1 = nil

-- pets
check(row(2).pet._shown and row(2).pet.text._text == "Grimkah" and row(2).pet._val == 3000, "lock's pet bar under his row")
check(not row(1).pet._shown, "no pet: no bar")
local pb = ArenaFramesPetClick2
check(pb and pb._protected and pb:GetAttribute("unit") == "arenapet2" and pb:GetAttribute("*type1") == "target",
  "pet bar clickable (target / focus)")
UNITS.arenapet2.dead = true; Tick(0.2)
check(row(2).pet._val == 0, "dead pet: empty bar")

-- 3.13: every spell they use flashes in the class square (casts stay on the cast bar)
SPELLS[988] = "Dispel Magic"
cast("0xA1", ENEMY, 988); Tick(0.2)
check(row(1).cc._shown and row(1).cc._tex == "Interface\\Icons\\DispelMagic" and row(1).ccText._text == "",
  "Dispel Magic flashes in the class square")
check(row(1).classBox._bdBorder[1] == 1 and row(1).classBox._bdBorder[2] == 1, "white border while it flashes")
cast("0xP2", ENEMY_PET, 19647); Tick(0.2)
check(row(2).cc._shown and row(2).cc._tex == "Interface\\Icons\\SpellLock", "pet spells flash on the owner's square")
NOW = NOW + 1.6; Tick(0.2)
check(not row(1).cc._shown, "back to the class icon after 1.5 s")
SPELLS[75] = "Auto Shot"
cast("0xA1", ENEMY, 75); Tick(0.2)
check(not row(1).cc._shown, "Auto Shot doesn't flash")
NOW = NOW + 2; Tick(0.2)

-- big cooldown alert
local B1 = ArenaFramesBigCD and ArenaFramesBigCD
SOUNDS = {}
cast("0xA1", ENEMY, 46924)                       -- Bladestorm
Tick(0.1)
local icons = {}
for _, c in ipairs(ArenaFramesBigCD._children) do if c.label then table.insert(icons, c) end end
check(icons[1]._shown and icons[1].label._text == "Bladestorm" and icons[1].text._text == 1, "Bladestorm flashes, arena 1")
check(SOUNDS[1] == "RaidWarning", "with a sound")
cast("0xA2", ENEMY, 19647)                        -- Spell Lock: not a big offensive cooldown
Tick(0.1)
check(not icons[2]._shown, "only big offensive cooldowns")
NOW = NOW + 3.1; Tick(0.1)
check(not icons[1]._shown, "gone after ~3 s")
cmd("bigsound off")
SOUNDS = {}
cast("0xA1", ENEMY, 46924); Tick(0.1)
check(icons[1]._shown and #SOUNDS == 0, "bigsound off: silent")
NOW = NOW + 4; Tick(0.1)
cmd("bigcd off")
cast("0xA1", ENEMY, 46924); Tick(0.1)
check(not icons[1]._shown, "bigcd off")

print(string.format("%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
