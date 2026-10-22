-- ArenaFrames 3.3: cooldown tracking + enemy cooldown bar
dofile("tests/harness.lua")
UNITS.player = { name = "Me", player = true, guid = "0xME", class = "ROGUE", hp = 1, maxhp = 1 }
LoadAddon("ArenaFrames")

local pass, fail = 0, 0
local function check(cond, label)
  if cond then pass = pass + 1 else fail = fail + 1; print("FAIL: " .. label) end
end
local function cmd(s) SlashCmdList.ARENAFRAMES(s) end
local function near(a, b) return a and b and math.abs(a - b) < 0.011 end
local function color(t, r, g, b) return t and near(t[1], r) and near(t[2], g) and near(t[3], b) end
local function bar()
  local out = {}
  for _, b in ipairs(ArenaFramesCooldowns.icons) do if b._shown then table.insert(out, b) end end
  return out
end
local ENEMY, FRIEND, MINE, ENEMY_PET = 0x0548, 0x0518, 0x0511, 0x1148
local function Cast(src, flags, id, name)
  FireEvent("COMBAT_LOG_EVENT_UNFILTERED", NOW, "SPELL_CAST_SUCCESS", src, "Name" .. src, flags,
    nil, nil, nil, id, name or SPELLS[id] or "?", 1)
end

FireEvent("ADDON_LOADED", "ArenaFrames")
FireEvent("PLAYER_ENTERING_WORLD")
check(ArenaFramesCooldowns and #bar() == 0, "bar exists, empty")

------------------------------------------------------------- arena ---------
INSTANCE = "arena"
FireEvent("ZONE_CHANGED_NEW_AREA")
UNITS.arena1 = { name = "Kisame", player = true, guid = "0xA1", class = "ROGUE", faction = "Alliance", hp = 1, maxhp = 1 }
UNITS.arenapet1 = { name = "Pet", guid = "0xP1" }
UNITS.arena2 = { name = "Bubble", player = true, guid = "0xA2", class = "PALADIN", faction = "Alliance", hp = 1, maxhp = 1 }
Tick(0.2)
Cast("0xA1", ENEMY, 1766)                       -- Kick
Tick(0.2)
local b = bar()
check(#b == 1 and b[1].icon._tex == "Interface\\Icons\\Kick", "enemy Kick shows on the bar")
check(b[1].text._text == "10" and b[1].cd._cd[2] == 10 and b[1].badge._text == 1, "timer, sweep, arena number")
check(color(b[1]._bdBorder, 0.3, 0.6, 1), "interrupt border blue")
NOW = NOW + 2
Cast("0xA2", ENEMY, 642)                        -- Divine Shield
Tick(0.2)
b = bar()
check(#b == 2 and b[1].icon._tex:find("DivineShield") and b[2].icon._tex:find("Kick"), "newest first")
check(b[1].badge._text == 2 and color(b[1]._bdBorder, 0.2, 0.9, 0.2), "arena2, defensive green")
NOW = NOW + 8.5; Tick(0.2)
check(#bar() == 1, "Kick ready again -> gone")
Cast("0xA1", ENEMY, 42292)                      -- PvP trinket (shares with EMFH)
Tick(0.2)
check(#bar() == 2, "trinket shows; the shared Every Man for Himself lockout doesn't add an icon")
local act = ArenaFrames_ActiveCooldowns("0xA1")
local shared
for e, u in pairs(act) do if e.name == "Every Man for Himself" then shared = u end end
check(shared and shared.shared and shared.dur == 120, "shared cooldown tracked (for party / ready state)")
Cast("0xP1", ENEMY_PET, 1766)                   -- something cast by arena1's pet
Tick(0.2)
check(ArenaFrames_ActiveCooldowns("0xA1") and #bar() == 3, "pet casts count for the owner")
Cast("0xA1", ENEMY, 99999, "Kick")              -- unknown rank, matched by name
Tick(0.2)
check(#bar() == 3, "same spell again just restarts it (by name too)")
Cast("0xME", MINE, 2094)                        -- my own Blind
Tick(0.2)
check(#bar() == 3, "your own cooldowns aren't on the enemy bar")
INSTANCE = "none"
FireEvent("PLAYER_ENTERING_WORLD")
UNITS.arena1, UNITS.arena2, UNITS.arenapet1 = nil, nil, nil
Tick(0.2)
check(#bar() == 0, "leaving arena clears")

------------------------------------------------------------- world ---------
Cast("0xH1", ENEMY, 2094)                       -- hostile player Blind
Cast("0xF1", FRIEND, 31224)                     -- friendly player Cloak
Tick(0.2)
b = bar()
check(#b == 1 and b[1].icon._tex:find("Blind") and b[1].badge._text == "", "world: hostile players only, no arena number")
UNITS.target = { name = "Dueler", player = true, guid = "0xF1", class = "ROGUE", reaction = 5, attackable = true }
Tick(0.2)
check(#bar() == 2, "duel opponent (friendly flag, attackable target) counts as enemy")
UNITS.target = nil

------------------------------------------------------------- options -------
cmd("cdsize 40")
check(ArenaFramesCooldowns.icons[1]._w == 40, "cdsize")
cmd("cd off"); Tick(0.2)
check(#bar() == 0, "cd off hides the bar")
cmd("cd on"); Tick(0.2)
check(#bar() == 1, "cd on (the duel target is gone, so only the hostile Blind)")
cmd("reset")
check(ArenaFramesDB.cdsize == 32 and ArenaFramesDB.cdbar == true, "reset")

------------------------------------------------------------- test mode -----
cmd("unlock")
Tick(0.2)
b = bar()
check(#b >= 4 and ArenaFramesCooldowns.bg._shown, "unlock: preview icons + drag handle")
local badges = {}
for _, x in ipairs(b) do badges[x.badge._text] = true end
check(badges[1] and badges[3], "preview shows arena numbers")
cmd("lock")
Tick(0.2)
check(not ArenaFramesCooldowns.bg._shown, "lock hides the handle")

print(string.format("%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
