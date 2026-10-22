dofile("tests/harness.lua")
LoadAddon("ArenaFrames")

local pass, fail = 0, 0
local function check(cond, label)
  if cond then pass = pass + 1 else fail = fail + 1; print("FAIL: " .. label) end
end
local function cmd(s) SlashCmdList.ARENAFRAMES(s) end
local function row(i) return _G["ArenaFramesRow" .. i] end
local function visible(i) return row(i):IsVisible() == 1 end
local function shownDRs(i)
  local out = {}
  for _, d in ipairs(row(i).drs) do if d._shown then table.insert(out, d) end end
  return out
end
local function border(d) local c = d._bdBorder; return c[1], c[2], c[3] end
local function isColor(d, r, g, b)
  local R, G, B = border(d)
  return math.abs(R - r) < 0.01 and math.abs(G - g) < 0.01 and math.abs(B - b) < 0.01
end
local GREEN, YELLOW, RED = { 0.1, 0.9, 0.1 }, { 1, 0.85, 0 }, { 1, 0.1, 0.1 }

local ENEMY_PLAYER, ME = 0x0548, 0x0511
local function CLEU(sub, srcGUID, dstGUID, spellId, auraType, dstFlags)
  FireEvent("COMBAT_LOG_EVENT_UNFILTERED", NOW, sub, srcGUID, "src", ME,
    dstGUID, "dst", dstFlags or ENEMY_PLAYER, spellId, SPELLS[spellId] or "Unknown", 1, auraType)
end
local function Aura(sub, guid, id) CLEU(sub, "0xME", guid, id, "DEBUFF") end

------------------------------------------------------------- load ---------
FireEvent("ADDON_LOADED", "ArenaFrames")
check(ArenaFramesDB and ArenaFramesDB.width == 200 and ArenaFramesDB.height == 36, "loaded with defaults")
FireEvent("PLAYER_ENTERING_WORLD")
Tick(0.2)
for i = 1, 5 do check(not visible(i), "outside arena: row " .. i .. " hidden") end
check(ArenaFramesAnchor:IsShown() and not ArenaFramesAnchor.bg._shown, "drag handle hidden outside test")

------------------------------------------------------------- arena --------
INSTANCE = "arena"
FireEvent("ZONE_CHANGED_NEW_AREA")
UNITS.arena1 = { name = "Kisame", player = true, guid = "0xA1", class = "ROGUE", faction = "Alliance",
  hp = 11600, maxhp = 20000 }
UNITS.arena2 = { name = "Paracetomol", player = true, guid = "0xA2", class = "PRIEST", faction = "Horde",
  hp = 22500, maxhp = 22500 }
Tick(0.2)
check(visible(1) and visible(2) and not visible(3), "arena: rows for seen enemies only")
local r1 = row(1)
check(r1.pct._text == "58%", "health percent text (got " .. tostring(r1.pct._text) .. ")")
check(r1.hp._max == 20000 and r1.hp._val == 11600, "health bar holds real HP")
check(r1.hp._bar[1] == 1 and r1.hp._bar[2] == 0.96, "rogue bar is class colored")
check(r1.name._text:find("Kisame") and r1.name._text:find("1"), "name with arena number")
check(r1.class._tex:find("UI%-CharacterCreate%-Classes"), "class icon texture")
check(r1.trinket.icon._tex:find("TrinketPVP_01"), "alliance trinket icon")
check(row(2).trinket.icon._tex:find("TrinketPVP_02"), "horde trinket icon")
check(not r1.trinket.cd._shown and r1.trinket.text._text == "", "trinket ready: no cooldown")
-- layout (owner asked in 1.1): trinket right of the row, DRs left of it, growing leftwards
local tp = r1.trinket._points[1]
check(tp[1] == "LEFT" and tp[2] == r1 and tp[3] == "RIGHT", "trinket on the right side")
local d1, d2 = r1.drs[1]._points[1], r1.drs[2]._points[1]
check(d1[1] == "RIGHT" and d1[2] == r1.classBox and d1[3] == "LEFT", "3.11: first DR left of the class square")
local cbp = r1.classBox._points[1]
check(cbp[1] == "RIGHT" and cbp[2] == r1 and cbp[3] == "LEFT", "3.11: class / CC square left of the bar")
check(d2[1] == "RIGHT" and d2[2] == r1.drs[1] and d2[3] == "LEFT", "next DRs grow further left")

-- trinket via combat log
CLEU("SPELL_CAST_SUCCESS", "0xA1", nil, 42292)
Tick(0.2)
check(r1.trinket.cd._shown and r1.trinket.cd._cd[2] == 120, "trinket used -> 2 min cooldown sweep")
check(r1.trinket.text._text == "2:00", "trinket timer text (got " .. tostring(r1.trinket.text._text) .. ")")
NOW = NOW + 75; Tick(0.2)
check(r1.trinket.text._text == "45", "trinket timer counts down (got " .. tostring(r1.trinket.text._text) .. ")")
NOW = NOW + 46; Tick(0.2)
check(not r1.trinket.cd._shown and r1.trinket.text._text == "", "trinket ready again after 2 min")

-- EMFH through UNIT_SPELLCAST_SUCCEEDED (3.3.5 passes the spell name, no ID); the log
-- seeing the same use right after must not restart the timer
FireEvent("UNIT_SPELLCAST_SUCCEEDED", "arena2", "Every Man for Himself", "")
local t0 = NOW
NOW = NOW + 1
CLEU("SPELL_CAST_SUCCESS", "0xA2", nil, 59752)
Tick(0.2)
check(row(2).trinket.cd._shown and row(2).trinket.cd._cd[1] == t0, "EMFH counts as trinket, deduped")
FireEvent("UNIT_SPELLCAST_SUCCEEDED", "party1", "PvP Trinket", "")
Tick(0.2)
check(not r1.trinket.cd._shown, "party trinket casts ignored")

-- DR: Kidney Shot -> green while running, timer after it ends
Aura("SPELL_AURA_APPLIED", "0xA1", 8643)
Tick(0.2)
local drs = shownDRs(1)
check(#drs == 1 and isColor(drs[1], unpack(GREEN)), "1st stun -> green (next is half)")
check(drs[1].icon._tex == "Interface\\Icons\\KidneyShot", "DR icon is the CC's icon")
check(not drs[1].cd._shown and drs[1].text._text == "", "no timer while the CC runs")
NOW = NOW + 4
Aura("SPELL_AURA_REMOVED", "0xA1", 8643)
Tick(0.2)
check(drs[1].cd._shown and drs[1].cd._cd[1] == NOW and drs[1].cd._cd[2] == 18, "timer starts when the CC ends")
check(drs[1].text._text == "18", "18 s DR timer")

-- Hammer of Justice shares the stun DR -> yellow, same icon slot
NOW = NOW + 5
Aura("SPELL_AURA_APPLIED", "0xA1", 10308)
Tick(0.2)
drs = shownDRs(1)
check(#drs == 1 and isColor(drs[1], unpack(YELLOW)), "2nd stun (HoJ) -> yellow (next is quarter)")
check(drs[1].icon._tex:find("HammerofJustice"), "icon switches to the last stun")
Aura("SPELL_AURA_REFRESH", "0xA1", 10308)
Tick(0.2)
check(isColor(shownDRs(1)[1], unpack(RED)), "3rd stun (refresh) -> red (immune)")

-- other category on the same enemy: Blind -> fear, separate icon, ordered by start
Aura("SPELL_AURA_APPLIED", "0xA1", 2094)
Tick(0.2)
drs = shownDRs(1)
check(#drs == 2 and drs[2].icon._tex:find("Blind") and isColor(drs[2], unpack(GREEN)), "Blind -> own fear DR icon")

-- reset 18 s after the CC ends
Aura("SPELL_AURA_REMOVED", "0xA1", 10308)
Aura("SPELL_AURA_REMOVED", "0xA1", 2094)
NOW = NOW + 17.5; Tick(0.2)
check(#shownDRs(1) == 2, "DRs still there at 17.5 s")
NOW = NOW + 1; Tick(0.2)
check(#shownDRs(1) == 0, "DRs gone after 18 s")
Aura("SPELL_AURA_APPLIED", "0xA1", 408)
Tick(0.2)
check(isColor(shownDRs(1)[1], unpack(GREEN)), "after reset: back to green")

-- CC end never seen (out of range): DR still expires
NOW = NOW + 10 + 18 + 0.5; Tick(0.2)
check(#shownDRs(1) == 0, "missing AURA_REMOVED: DR times out")

-- 1.2: DR icons fade in when the DR starts and out when it resets, each on its own
local function fade(d, secs)   -- run the icon's own OnUpdate (the harness only ticks event frames)
  for _ = 1, math.floor(secs / 0.05 + 0.5) do
    local fn = d:GetScript("OnUpdate")
    if not fn then return end
    fn(d, 0.05)
  end
end
Aura("SPELL_AURA_APPLIED", "0xA1", 408)        -- stun (older)
NOW = NOW + 1
Aura("SPELL_AURA_APPLIED", "0xA1", 2094)       -- Blind (newer)
Tick(0.2)
local s1, s2 = r1.drs[1], r1.drs[2]
check(s1._shown and s1._alpha == 0 and s1:GetScript("OnUpdate"), "new DR icon starts invisible and fades in")
fade(s1, 0.2); fade(s2, 0.2)
check(s1._alpha > 0.4 and s1._alpha < 0.6, "fade in is gradual (half way at 0.2 s)")
fade(s1, 0.3); fade(s2, 0.3)
check(s1._alpha == 1 and s2._alpha == 1 and not s1:GetScript("OnUpdate"), "fully visible, fade script stops")
Aura("SPELL_AURA_REMOVED", "0xA1", 408)
NOW = NOW + 2
Aura("SPELL_AURA_REMOVED", "0xA1", 2094)
NOW = NOW + 16.1; Tick(0.2)                    -- stun DR just reset, Blind has 2 s left
check(s1._shown and s1.icon._tex:find("KidneyShot") and s1.text._text == "", "reset DR stays in place while fading")
fade(s1, 0.2)
check(s1._alpha < 0.6 and s1._alpha > 0.4 and s2._alpha == 1, "only the reset DR fades out")
fade(s1, 0.3)
check(s1._alpha == 0, "faded out")
NOW = NOW + 0.4; Tick(0.2)
check(#shownDRs(1) == 1 and s1.icon._tex:find("Blind") and s1._alpha == 1,
  "remaining DR slides over without fading in again")
-- re-CC while a DR is fading out: fades back in, fresh green
NOW = NOW + 2; Tick(0.2)                       -- Blind reset -> fading out
fade(s1, 0.2)
Aura("SPELL_AURA_APPLIED", "0xA1", 2094)
Tick(0.2)
check(s1.target == 1 and isColor(s1, unpack(GREEN)), "re-CC during fade out: back in, green")
fade(s1, 0.5)
check(s1._alpha == 1, "fully back")
Aura("SPELL_AURA_REMOVED", "0xA1", 2094)
NOW = NOW + 18.5; Tick(0.2)
check(#shownDRs(1) == 0, "cleared for the next checks")

-- name fallback: a rank that's not in the ID list
SPELLS[99999] = "Kidney Shot"
Aura("SPELL_AURA_APPLIED", "0xA2", 99999)
Tick(0.2)
check(#shownDRs(2) == 1, "unknown rank matched by spell name")
-- Psychic Horror: same name, two categories -> ID only
Aura("SPELL_AURA_APPLIED", "0xA2", 64044)
Aura("SPELL_AURA_APPLIED", "0xA2", 64058)
Tick(0.2)
check(#shownDRs(2) == 3, "Psychic Horror horror + disarm are separate DRs")
-- Unstable Affliction DoT must not count as a silence
Aura("SPELL_AURA_APPLIED", "0xA2", 47843)
Tick(0.2)
check(#shownDRs(2) == 3, "UA dot isn't a silence DR")
-- buffs / non-players ignored
CLEU("SPELL_AURA_APPLIED", "0xME", "0xA2", 33786, "BUFF")
CLEU("SPELL_AURA_APPLIED", "0xME", "0xNPC", 33786, "DEBUFF", 0x0A48)
Tick(0.2)
check(#shownDRs(2) == 3, "buffs and NPC debuffs ignored")

-- 3.1: spec detection (no API on 3.3.5: spells / auras / pets only one spec has)
local function specText(i) return row(i).spec._shown and row(i).spec._text or nil end
local function namePointY(i) return row(i).name._points[#row(i).name._points][5] end
Tick(0.2)
check(specText(1) == nil, "spec unknown: no spec text")
CLEU("SPELL_CAST_SUCCESS", "0xA1", nil, 51713)  -- Shadow Dance
Tick(0.2)
check(specText(1) == "Subtlety", "Shadow Dance -> Subtlety (on the power bar)")
CLEU("SPELL_CAST_SUCCESS", "0xA1", nil, 51713)
FireEvent("UNIT_SPELLCAST_SUCCEEDED", "arena2", "Penance", "")   -- 3.3.5: name only
Tick(0.2)
check(specText(2) == "Discipline", "cast seen by name (UNIT_SPELLCAST_SUCCEEDED) -> Discipline")
UNITS.arena3 = { name = "Shammy", player = true, guid = "0xA3", class = "SHAMAN", faction = "Horde", hp = 1, maxhp = 1 }
UNITS.arena4 = { name = "Hybrid", player = true, guid = "0xA4", class = "ROGUE", faction = "Horde", hp = 1, maxhp = 1 }
UNITS.arenapet4 = { name = "Pet", guid = "0xP4" }
UNITS.arena5 = { name = "Tree", player = true, guid = "0xA5", class = "DRUID", faction = "Horde", hp = 1, maxhp = 1 }
Tick(0.2)
UNITS.arena2.auras = { { name = "Earth Shield", id = 49284, caster = "arena3" } }
FireEvent("UNIT_AURA", "arena2")
Tick(0.2)
check(specText(3) == "Restoration", "Earth Shield on a teammate, cast by arena3 -> arena3 Restoration")
CLEU("SPELL_CAST_SUCCESS", "0xA4", nil, 14185)  -- Preparation, weak hint
Tick(0.2)
check(specText(4) == "Subtlety?", "weak evidence shown with a ?")
CLEU("SPELL_CAST_SUCCESS", "0xP4", nil, 51713)  -- cast by arena4's pet / guardian
Tick(0.2)
check(specText(4) == "Subtlety", "pet spells count for the owner; more evidence drops the ?")
FireEvent("UNIT_SPELLCAST_SUCCEEDED", "arena5", "Nature's Swiftness", "")
Tick(0.2)
check(specText(5) == "Restoration", "same spell name on two classes: the druid entry is used for a druid")
CLEU("SPELL_CAST_SUCCESS", "0xA5", nil, 53007)  -- a priest spell from a druid: ignored
Tick(0.2)
check(specText(5) == "Restoration", "spells of another class are ignored")
-- regression (3.7.1 in 2v2: no spec shown; the list only had 9 spells, nothing for warriors / paladins...)
UNITS.arena4 = { name = "Warr", player = true, guid = "0xA4W", class = "WARRIOR", faction = "Horde", hp = 1, maxhp = 1 }
UNITS.arena3 = { name = "Boomy", player = true, guid = "0xA3B", class = "DRUID", faction = "Horde", hp = 1, maxhp = 1,
  auras = { { name = "Moonkin Aura", id = 24907, caster = "arena3" } } }
Tick(0.2)
CLEU("SPELL_CAST_SUCCESS", "0xA4W", nil, 47486)  -- Mortal Strike
Tick(0.2)
check(specText(4) == "Arms", "warrior: Mortal Strike -> Arms")
check(specText(3) == "Balance", "passive spec aura seen without a UNIT_AURA event (scan when the enemy shows up)")
CHAT = {}
cmd("debug")
local dbgSpec = table.concat(CHAT, "\n")
check(dbgSpec:find("spec: Subtlety %(3 pts; seen: Shadow Dance%)"), "debug: spec, points, evidence (counted once)")
UNITS.arena3, UNITS.arena4, UNITS.arenapet4, UNITS.arena5 = nil, nil, nil, nil
UNITS.arena2.auras = nil

-- 3.8.2 (owner: "no timer of applied cc displayed" on the arena rows)
UNITS.arena1.auras = { { name = "Kidney Shot", id = 8643, harmful = true, dur = 6, expires = NOW + 4, caster = "player" } }
FireEvent("UNIT_AURA", "arena1"); Tick(0.2)
check(row(1).cc._shown and row(1).cc._tex:find("KidneyShot") and row(1).ccText._text == "4.0",
  "CC on an enemy: its icon over the class icon with the time left")
UNITS.arena1.auras = { { name = "Kidney Shot", id = 8643, harmful = true, dur = 6, expires = NOW + 4, caster = "player" },
  { name = "Divine Shield", id = 642, dur = 12, expires = NOW + 11 } }
FireEvent("UNIT_AURA", "arena1"); Tick(0.2)
check(row(1).cc._tex:find("DivineShield") and row(1).ccText._text == "11", "immunity wins over a stun")
UNITS.arena1.auras = nil
NOW = NOW + 2                                    -- past the 3.13 spell flash of arena1's Shadow Dance
FireEvent("UNIT_AURA", "arena1"); Tick(0.2)
check(not row(1).cc._shown and row(1).ccText._text == "", "CC gone -> class icon again")

-- unknown debuffs are listed by /aframes debug
Aura("SPELL_AURA_APPLIED", "0xA2", 47486)
CHAT = {}
cmd("debug")
local dbg = table.concat(CHAT, "\n")
check(dbg:find("arena1 Kisame %(ROGUE, Alliance%)"), "debug lists arena units")
check(dbg:find("Horror: 1 applied"), "debug lists DRs")
check(dbg:find("no DR category: Mortal Strike 47486"), "debug lists unknown debuffs")

-- stealth: unit gone -> dimmed with last values; back -> full alpha
UNITS.arena1 = nil
Tick(0.2)
check(visible(1) and row(1)._alpha < 1 and row(1).pct._text == "58%", "unseen enemy: dimmed, last HP kept")
UNITS.arena1 = { name = "Kisame", player = true, guid = "0xA1", class = "ROGUE", faction = "Alliance",
  hp = 0, maxhp = 20000, dead = true }
Tick(0.2)
check(row(1)._alpha == 1 and row(1).pct._text == "DEAD", "dead enemy shows DEAD")

-- leaving the arena clears everything
INSTANCE = "none"
FireEvent("PLAYER_ENTERING_WORLD")
UNITS.arena1, UNITS.arena2 = nil, nil
Tick(0.2)
check(not visible(1) and not visible(2), "left arena: rows hidden")
INSTANCE = "arena"
FireEvent("PLAYER_ENTERING_WORLD")
UNITS.arena1 = { name = "Other", player = true, guid = "0xA1", class = "MAGE", faction = "Horde",
  hp = 100, maxhp = 100 }
Tick(0.2)
check(not row(1).trinket.cd._shown and #shownDRs(1) == 0, "new match: trinket and DR state cleared")
check(not row(1).spec._shown, "new match: spec cleared")
UNITS.arena1 = nil
INSTANCE = "none"
FireEvent("PLAYER_ENTERING_WORLD")

----------------------------------------- 3.7: no center display, clickable rows --
check(ArenaFramesCenter == nil and ArenaFramesCenterTarget == nil, "the separate target/focus DR display is gone")
CHAT = {}
cmd("center off")                              -- old command: just shows the help now
check(ArenaFramesDB.center == nil and CHAT[1] and CHAT[1]:find("v3.21.1"), "old center commands are gone")
local C1, C2 = ArenaFramesClick1, ArenaFramesClick2
check(C1 and C1._attr.unit == "arena1" and C1._attr["*type1"] == "target" and C1._attr["*type2"] == "focus"
  and C1._protected, "row 1 has a secure click button: left = target, right = focus")
Tick(0.2)
check(IsUnitWatched(C1) and not C1._shown, "no arena1: click button hidden by the unit watch")
INSTANCE = "arena"
FireEvent("PLAYER_ENTERING_WORLD")
UNITS.arena1 = { name = "Kisame", player = true, guid = "0xA1", class = "ROGUE", faction = "Alliance",
  hp = 100, maxhp = 100 }
Tick(0.2)
check(visible(1) and C1._shown and not C2._shown, "arena1 seen: row 1 and its click button shown, row 2 not")
TARGETED, FOCUSED = nil, nil
SecureClick(C1, "RightButton")
check(FOCUSED == "arena1" and TARGETED == nil, "right click on row 1 focuses arena1")
SecureClick(C1, "LeftButton")
check(TARGETED == "arena1", "left click on row 1 targets arena1")
local hp = ArenaFramesClickHolder._points[1]
check(hp[1] == ArenaFramesDB.point and hp[2] == UIParent and hp[4] == ArenaFramesDB.x and hp[5] == ArenaFramesDB.y
  and ArenaFramesClickHolder._scale == ArenaFramesDB.scale, "click holder copies the anchor's point and scale")
check(C2._points[1][2] == ArenaFramesClickHolder and C2._points[1][5] == row(2)._points[1][5]
  and C2._w == row(2)._w and C2._h == row(2)._h, "click button 2 sits exactly over row 2")
-- secure frames can't move in combat: rows resize now, click buttons after combat
COMBAT = true
ArenaFramesClickHolder._protected = true       -- in the client a protected child makes it protected too
cmd("width 260")
check(row(1)._w == 260 and C1._w == 200, "in combat: rows resize, click buttons wait (no blocked action)")
UNITS.arena1 = nil
Tick(0.2)
check(not C1._shown, "in combat the unit watch still hides the button when arena1 is gone")
CHAT = {}
cmd("debug")
check(table.concat(CHAT, "\n"):find("layout update waiting for combat to end"), "debug says the layout waits")
COMBAT = false
FireEvent("PLAYER_REGEN_ENABLED")
check(C1._w == 260, "after combat: click buttons resized")
ArenaFramesClickHolder._protected = nil
cmd("width 200")
INSTANCE = "none"
FireEvent("PLAYER_ENTERING_WORLD")
Tick(0.2)

------------------------------------------------------------- test mode ----
CHAT = {}
cmd("test")
Tick(0.2)
check(visible(1) and visible(2) and visible(3), "test mode shows 3 fake rows outside arena")
check(ArenaFramesAnchor.bg._shown and ArenaFramesAnchor._mouse, "test mode shows the drag handle")
check(row(2).trinket.cd._shown, "test: trinket cooldown preview")
check(#shownDRs(1) == 2 and #shownDRs(2) == 1, "test: DR preview")
check(isColor(shownDRs(2)[1], unpack(RED)), "test: immune color preview")
check(row(3)._alpha < 1, "test: unseen preview")
check(row(1).spec._text == "Subtlety" and row(2).spec._text == "Discipline", "test: spec preview")
check(row(2).cc._shown and row(2).ccText._text == "3.4", "test: CC timer preview on arena2")
-- 3.11 (owner's sArena screenshots)
check(not row(1).name._shown and not row(1).pct._shown, "3.11: no name / % on the bars by default")
check(row(2).cast._shown and row(2).cast.text._text == "Flash Heal", "3.11: cast bar preview right of the trinket")
check(row(2).racial._shown and row(2).racial.icon._tex == ArenaFrames_NS.racialByRace.Scourge.icon,
  "3.11: racial square (Undead: WotF)")
check(not row(1).racial._shown, "Human: EMFH is the trinket, no racial square")
local usedIcons = 0
for _, b in ipairs(row(1).used) do if b._shown then usedIcons = usedIcons + 1 end end
check(usedIcons == 2 and row(1).used[1]._points[1][2] == row(1) and row(1).used[1]._points[1][3] == "BOTTOMLEFT",
  "3.11: the cooldowns arena1 used (Kick, Blind) under its bar")
check(row(1).power._shown ~= false and row(1).power._max == 100 and row(1).power._val == 60, "3.11: power bar")
check(row(1)._alpha == 0.5 and row(2)._alpha == 1 and row(3)._alpha == 0.45, "preview: arena1 out of range, arena3 not visible")
cmd("names on")
check(row(1).name._shown and row(1).pct._shown, "names on: name + % back")
cmd("names off")
-- drag saves the position
ArenaFramesAnchor:GetScript("OnDragStart")(ArenaFramesAnchor)
ArenaFramesAnchor._points = { { "TOPLEFT", UIParent, "TOPLEFT", 300.4, -200.6 } }
ArenaFramesAnchor:GetScript("OnDragStop")(ArenaFramesAnchor)
check(ArenaFramesDB.point == "TOPLEFT" and ArenaFramesDB.x == 300 and ArenaFramesDB.y == -201, "drag saves position")
local hp2 = ArenaFramesClickHolder._points[1]
check(hp2[1] == "TOPLEFT" and hp2[4] == 300 and hp2[5] == -201, "drag moves the click buttons along")
cmd("test")
Tick(0.2)
check(not visible(1) and not ArenaFramesAnchor.bg._shown, "test off: hidden again")

------------------------------------------------------------- slash ---------
cmd("scale 5"); check(ArenaFramesDB.scale == 2, "scale clamped")
cmd("width 250"); check(ArenaFramesDB.width == 250 and row(1)._w == 250, "width applied")
cmd("height 44"); check(ArenaFramesDB.height == 44 and row(1).trinket._w == 44, "height = trinket size")
cmd("reset"); check(ArenaFramesDB.scale == 1 and ArenaFramesDB.width == 200 and ArenaFramesDB.point == "LEFT"
  and ArenaFramesDB.center == nil, "reset")
CHAT = {}
cmd("")
check(CHAT[1] and CHAT[1]:find("v3.21.1"), "help shows version")

print(string.format("%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
