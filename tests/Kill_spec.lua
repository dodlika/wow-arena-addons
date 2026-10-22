-- ArenaFrames 3.10: kill target suggestion, comp tip, match history, arena combat logging
dofile("tests/harness.lua")
UNITS.player = { name = "Me", player = true, guid = "0xME", class = "PRIEST", hp = 1, maxhp = 1 }
SPELLS[1126], SPELLS[21849] = "Mark of the Wild", "Gift of the Wild"
LoadAddon("ArenaFrames")
ArenaFrames_Data = { players = {}, specs = {} }    -- not the generated data: it changes with every update

local pass, fail = 0, 0
local function check(cond, label)
  if cond then pass = pass + 1 else fail = fail + 1; print("FAIL: " .. label) end
end
local function cmd(s) SlashCmdList.ARENAFRAMES(s) end
local function row(i) return _G["ArenaFramesRow" .. i] end
local function wait(s) for _ = 1, math.ceil(s / 0.5) do NOW = NOW + 0.5; Tick(0.5) end end
local ENEMY, FRIEND = 0x0548, 0x0514
local function died(guid, flags)
  FireEvent("COMBAT_LOG_EVENT_UNFILTERED", NOW, "UNIT_DIED", nil, nil, 0, guid, "x", flags)
end

FireEvent("ADDON_LOADED", "ArenaFrames")
FireEvent("PLAYER_ENTERING_WORLD")
local K = ArenaFrames_NS.Kill
cmd("autocall off")                              -- the 3.14 auto call has its own section below
check(K and ArenaFramesDB.kill == true and ArenaFramesDB.autolog == true, "loaded, on by default")

------------------------------------------------------------- scoring -------
local sLock = K.Score("WARLOCK", "Affliction", "X", "Orc")
local sPala = K.Score("PALADIN", "Holy", "Y", "Orc")
check(sLock > sPala, "an affliction lock is an easier kill than a holy paladin")
local sHuman = K.Score("WARLOCK", "Affliction", "X", "Human")
check(sHuman < sLock, "Human (EMFH = second trinket) lowers the score")
ArenaFrames_Data.players.Squishy = { resil = 400, rating = 1300, met = 3, firstDeath = 3 }
local sSquishy, why = K.Score("WARLOCK", "Affliction", "Squishy", "Orc")
check(sSquishy > sLock + 15 and why:find("low resil 400") and why:find("died first 3/3 vs you"),
  "armory / log data about the player: low resilience, died first every time")
ArenaFrames_Data.specs["PALADIN:Holy"] = { seen = 20, firstDeath = 15 }
check(K.Score("PALADIN", "Holy", "Y", "Orc") > sPala + 20, "your logs override the prior when they have data")
ArenaFrames_Data.specs["PALADIN:Holy"] = nil
check(select(2, K.Score("MAGE", nil, "Z", nil)):find("^mage"), "spec unknown: class average")
-- 3.10.1: Warmane match history
ArenaFrames_Data.avgDeath = 40
ArenaFrames_Data.classes = { WARLOCK = { games = 100, deaths = 60 }, PALADIN = { games = 100, deaths = 15 } }
local lockH, whyH = K.Score("WARLOCK", "Affliction", "X", "Orc")
check(lockH > sLock + 5 and whyH:find("locks die in 60%% of your SoloQ games"), "class death rate from your history")
-- 3.17 (owner: "in 2v2 pull the 2v2 brackets, for SoloQ take SoloQ")
ArenaFrames_Data.classes2 = { WARLOCK = { games = 50, deaths = 10 } }
ArenaFrames_Data.avgDeath2 = 45
local lock2, why2 = K.Score("WARLOCK", "Affliction", "X", "Orc", nil, "2v2")
check(lock2 < sLock - 5 and why2:find("locks die in 20%% of your 2v2 games"), "2v2: the 2v2 class numbers")
check(K.Score("WARLOCK", "Affliction", "X", "Orc") == lockH, "SoloQ ignores the 2v2 numbers")
local pala2, whyP2 = K.Score("PALADIN", "Holy", "Y", "Orc", nil, "2v2")
check(whyP2:find("of your SoloQ games") ~= nil, "no 2v2 class data: falls back to SoloQ")
ArenaFrames_Data.classes2, ArenaFrames_Data.avgDeath2 = nil, nil
local savedClasses = ArenaFrames_Data.classes
ArenaFrames_Data.classes = {}
ArenaFrames_Data.players.Duo = { hgames = 8, hdeaths = 10, mmr = 1700, hgames2 = 8, hdeaths2 = 90, mmr2 = 1200 }
local _, whyD2 = K.Score("WARLOCK", "Affliction", "Duo", "Orc", nil, "2v2")
local _, whyDS = K.Score("WARLOCK", "Affliction", "Duo", "Orc")
check(whyD2:find("dies in 90%% of his games") and whyD2:find("2v2 MMR 1200"), "2v2: his 2v2 form and MMR")
check(whyDS:find("MMR 1700") and not whyDS:find("2v2"), "SoloQ: his SoloQ form")
ArenaFrames_Data.players.Solo = { hgames = 8, hdeaths = 90 }
local _, whyS2 = K.Score("WARLOCK", "Affliction", "Solo", "Orc", nil, "2v2")
check(whyS2:find("dies in 90%% of his games %(SoloQ%)"), "no 2v2 games: his SoloQ form, marked")
ArenaFrames_Data.players.Duo, ArenaFrames_Data.players.Solo = nil, nil
ArenaFrames_Data.classes = savedClasses
check(K.Score("PALADIN", "Holy", "Y", "Orc") < sPala - 5, "paladins rarely die: lower")
ArenaFrames_Data.classes = {}
ArenaFrames_Data.players.Feeder = { hgames = 8, hdeaths = 88, vsMet = 3, vsDied = 3, mmr = 1250 }
local sFeed, whyF = K.Score("WARLOCK", "Affliction", "Feeder", "Orc")
check(sFeed > sLock + 15 and whyF:find("dies in 88%% of his games"), "player who dies a lot in his recent games")
ArenaFrames_Data.players.Feeder = nil
ArenaFrames_Data.players.Frosty = { class = "MAGE", spec = "Fire" }
check(K.Score("MAGE", nil, "Frosty", "Orc") == K.Score("MAGE", "Fire", "Q", "Orc")
  and select(2, K.Score("MAGE", nil, "Frosty", "Orc")):find("Fire%? mage"), "spec not seen in game yet: the armory's (with a ?)")

------------------------------------------------------------- arena ---------
PARTY = 1                                         -- 2v2: you + one mate
INSTANCE = "arena"
FireEvent("ZONE_CHANGED_NEW_AREA")
wait(1)
check(COMBATLOG == 1 and table.concat(CHAT, "\n"):find("combat log ON"), "entering arena switches the combat log on")
UNITS.arena1 = { name = "Bubble", player = true, guid = "0xA1", class = "PALADIN", race = "Human", hp = 1, maxhp = 1 }
wait(1)
check(not row(1).kill._shown, "3.15: one enemy seen, one not yet: the unseen one (a rogue by the buffs) can be the pick")
UNITS.arena2 = { name = "Squishy", player = true, guid = "0xA2", class = "WARLOCK", race = "Orc", hp = 1, maxhp = 1 }
wait(1)
check(row(2).kill._shown and not row(1).kill._shown, "whole team seen: the lock is the pick, skull on his row")
check(row(2).killGlow._shown and not row(1).killGlow._shown and row(2).kill._w == 30,
  "3.10.1: red outline around the picked row, skull as big as the row")
CHAT = {}
cmd("debug")
check(table.concat(CHAT, "\n"):find("> Squishy"), "debug lists the scores, pick marked")
UNITS.arena3 = { name = "Late", player = true, guid = "0xA3", class = "PRIEST", race = "Orc", hp = 1, maxhp = 1 }
ArenaFrames_Data.players.Late = { resil = 100 }
wait(1)
check(row(2).kill._shown and not row(3).kill._shown, "locked: one pick per match, no switching")
UNITS.arena3, ArenaFrames_Data.players.Late = nil, nil
SENT = {}
RAID = 0
cmd("call")
check(SENT[1] and SENT[1][1] == "go lock" and SENT[1][2] == "PARTY", "/aframes call says it in party chat")
check(#SENT == 1, "only when you type it")
died("0xA2", ENEMY)
died("0xA1", ENEMY)
INSTANCE = "none"
FireEvent("ZONE_CHANGED_NEW_AREA")
wait(1)
check(COMBATLOG == nil, "leaving arena: combat log off again")
local h = ArenaFramesDB.killHistory
check(h and #h == 1 and h[1].pick == "Squishy" and h[1].firstDeath == "Squishy" and h[1].result == "win",
  "match stored: pick, first death, result")
check(not K.IsPick("0xA2"), "out of arena: no pick")
CHAT = {}
cmd("kills")
check(table.concat(CHAT, "\n"):find("pick died first in 1/1"), "/aframes kills: how the picks did")

-- logging you started yourself stays on
COMBATLOG = 1
INSTANCE = "arena"; FireEvent("ZONE_CHANGED_NEW_AREA"); wait(1)
UNITS.arena1 = { name = "Bubble", player = true, guid = "0xB1", class = "PALADIN", hp = 1, maxhp = 1 }
UNITS.arena2 = { name = "Squishy", player = true, guid = "0xB2", class = "WARLOCK", hp = 1, maxhp = 1 }
wait(1)
died("0xME", FRIEND)
died("0xP1", FRIEND)
INSTANCE = "none"; FireEvent("ZONE_CHANGED_NEW_AREA"); wait(1)
check(COMBATLOG == 1, "your own /combatlog isn't switched off")
check(LOGCALLS[#LOGCALLS - 1] == false and LOGCALLS[#LOGCALLS] == true,
  "3.15.1: but it's switched off and on again after the arena, so the client writes it to disk")
check(#h == 2 and h[2].result == "loss", "both of us died: loss")
UNITS.arena1, UNITS.arena2 = nil, nil

------------------------------------------------------------- options / test --
cmd("unlock"); wait(1)
local skulls = 0
for i = 1, 3 do if row(i).kill._shown then skulls = skulls + 1 end end
check(skulls == 1, "test mode previews a pick")
cmd("kill off"); wait(1)
check(not row(1).kill._shown and not row(2).kill._shown and not row(3).kill._shown, "kill off: no skull")
cmd("kill on")
cmd("lock"); wait(1)
cmd("autolog off")
COMBATLOG = nil
INSTANCE = "arena"; FireEvent("ZONE_CHANGED_NEW_AREA"); wait(1)
check(COMBATLOG == nil, "autolog off: not switched on")

-- 3.14: "go lock" in party 2 s after the gates (= the first enemy showing up), once; the skull follows it
INSTANCE = "none"; FireEvent("ZONE_CHANGED_NEW_AREA"); wait(1)
cmd("autocall on"); cmd("autolog on")
SENT = {}
INSTANCE = "arena"; FireEvent("ZONE_CHANGED_NEW_AREA"); wait(1)
check(#SENT == 0, "nothing before the gates")
UNITS.arena1 = { name = "Bubble", player = true, guid = "0xC1", class = "PALADIN", race = "Human", hp = 1, maxhp = 1 }
UNITS.arena2 = { name = "Squishy", player = true, guid = "0xC2", class = "WARLOCK", race = "Orc", hp = 1, maxhp = 1 }
wait(1)
check(#SENT == 0, "1 s after the gates: not yet")
wait(2)                                          -- (frames tick in any order: the slot may show up a tick late)
check(#SENT == 1 and SENT[1][1] == "go lock" and SENT[1][2] == "PARTY", "2 s after: go lock in party")
UNITS.arena3 = { name = "Late", player = true, guid = "0xC3", class = "PRIEST", race = "Orc", hp = 1, maxhp = 1 }
ArenaFrames_Data.players.Late = { resil = 0, hdeaths = 100, hgames = 8 }
wait(3)
check(#SENT == 1 and row(2).kill._shown and not row(3).kill._shown, "called once; the skull stays on what was called")
ArenaFrames_Data.players.Late = nil
UNITS.arena1, UNITS.arena2, UNITS.arena3 = nil, nil, nil

-- 3.15: an enemy still stealthed at the gates; their buffs tell rogue or druid
local function newArena()
  INSTANCE = "none"; FireEvent("ZONE_CHANGED_NEW_AREA"); wait(1)
  SENT = {}
  INSTANCE = "arena"; FireEvent("ZONE_CHANGED_NEW_AREA"); wait(1)
end
ArenaFrames_KillPrior.ROGUE._ = 95               -- make the hidden one the best kill for this test
PARTY = 1                                        -- 2v2: one enemy visible, one hidden
newArena()
UNITS.arena1 = { name = "Bubble", player = true, guid = "0xD1", class = "PALADIN", race = "Human", hp = 1, maxhp = 1 }
wait(3)
check(SENT[1] and SENT[1][1] == "go rog", "hidden enemy, no druid buffs: a rogue -> go rog")
-- 3.18: the hidden one gets a placeholder row of that class (dimmed, "stealth?", skull if picked)
local function isClass(f, class)
  local c = ({ ROGUE = { 0.49609375, 0, 0, 0 }, DRUID = { 0.7421875, 0, 0, 0 } })[class]
  local t = f.class._coords
  return t and t[1] == c[1] and t[3] == c[3]
end
check(row(2)._shown and isClass(row(2), "ROGUE") and row(2).spec:GetText() == "stealth?" and row(2):GetAlpha() < 0.5
  and row(2).kill._shown, "stealthed enemy: dimmed rogue placeholder row with the skull")
check(not row(3)._shown, "2v2: no placeholder beyond the team size")
UNITS.arena2 = { name = "Stabby", player = true, guid = "0xD2", class = "ROGUE", race = "Orc", hp = 1, maxhp = 1 }
wait(1)
check(row(2).kill._shown and not row(1).kill._shown, "the rogue shows up: skull on him")
check(not row(2).spec._shown, "the real rogue replaces the placeholder")
UNITS.arena2 = nil
ArenaFrames_KillPrior.DRUID._ = 96
newArena()
UNITS.arena1 = { name = "Bubble", player = true, guid = "0xE1", class = "PALADIN", race = "Human", hp = 1, maxhp = 1,
  auras = { { name = "Gift of the Wild", id = 21849 } } }
wait(3)
check(SENT[1] and SENT[1][1] == "go druid", "Gift of the Wild on the paladin, no druid seen: the hidden one is a druid")
check(row(2)._shown and isClass(row(2), "DRUID"), "druid buff on the enemies: druid placeholder row")
ArenaFrames_KillPrior.ROGUE._, ArenaFrames_KillPrior.DRUID._ = 48, 42
UNITS.arena1 = nil

-- 3.15.1: live gear check by max health; names that load late; the unlock preview inside an arena
check(K.Score("MAGE", "Frost", "Q", "Orc", 16000) > K.Score("MAGE", "Frost", "Q", "Orc", 21000) + 8
  and select(2, K.Score("MAGE", "Frost", "Q", "Orc", 16000)):find("low health 16k"), "low max health (gear) = easier kill")
PARTY = 1
newArena()
UNITS.arena1 = { name = "Unknown", player = true, guid = "0xF1", class = "PALADIN", race = "Human", hp = 1, maxhp = 1 }
UNITS.arena2 = { name = "Unknown", player = true, guid = "0xF2", class = "WARLOCK", race = "Orc", hp = 1, maxhp = 1 }
wait(1)
UNITS.arena1.name, UNITS.arena2.name = "Realpala", "Reallock"
wait(1)
cmd("unlock"); wait(1); cmd("lock")
INSTANCE = "none"; FireEvent("ZONE_CHANGED_NEW_AREA"); wait(1)
local last = ArenaFramesDB.killHistory[#ArenaFramesDB.killHistory]
local names = {}
for _, e in ipairs(last.enemies) do names[e.name] = true end
check(names.Realpala and names.Reallock and not names.Unknown, "names that showed up late are kept (not 'Unknown')")
check(#last.enemies == 2 and not names.Kisame, "the unlock preview's fake players don't end up in the match record")
UNITS.arena1, UNITS.arena2 = nil, nil

print(string.format("%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
