dofile("tests/harness.lua")
dofile("CombatPlates/CombatPlates.lua")

local pass, fail = 0, 0
local function check(cond, label)
  if cond then pass = pass + 1 else fail = fail + 1; print("FAIL: " .. label) end
end
local function shown(p) local h = Holder(p); return h and h._shown end
local function kind(p)
  local h = Holder(p); local t = h and h._regions[1]
  if not t or not h._shown then return nil end
  if t._tex == [[Interface\CharacterFrame\UI-StateIcon]] then return "swords" end
  if t._tex == [[Interface\Icons\Ability_Sap]] then return "sap" end
end
local function cmd(s) SlashCmdList.COMBATPLATES(s) end
local function clearUnits() for k in pairs(UNITS) do UNITS[k] = nil end end
local function hidePlates(...) for _, p in ipairs({ ... }) do p:Hide() end end

-- combat log flags (as seen by us)
local ENEMY_PLAYER  = 0x0548   -- hostile + player + outsider
local FRIEND_PLAYER = 0x0511   -- friendly + player + mine/party
local ENEMY_NPC     = 0x0A48   -- hostile + npc
local function CLEU(sub, srcName, srcFlags, dstName, dstFlags, spellId, auraType)
  FireEvent("COMBAT_LOG_EVENT_UNFILTERED", NOW, sub,
    srcName and ("0x" .. srcName) or nil, srcName, srcFlags,
    dstName and ("0x" .. dstName) or nil, dstName, dstFlags,
    spellId or 0, "spell", 1, auraType)
end

local RED, WHITE = { 1, 0, 0 }, { 1, 1, 1 }
local HOSTILE, FRIENDLY_NPC, PRIEST_WHITE = { 1, 0, 0 }, { 0, 1, 0 }, { 1, 1, 1 }

FireEvent("ADDON_LOADED", "CombatPlates")
check(CombatPlatesDB and CombatPlatesDB.mode == "combat", "loaded with defaults")
cmd("mode sap")

------------------------------------------------------------ ARENA ----------
INSTANCE = "arena"
UNITS.arena1 = { name = "Breakingbad", player = true, combat = true,  hp = 28000, maxhp = 31000 }
UNITS.arena2 = { name = "Paracetomol", player = true, combat = true,  hp = 20500, maxhp = 22500 }
UNITS.arena3 = { name = "Twilights",   player = true, combat = false, hp = 25000, maxhp = 27800 }

-- ArenaNumbers rewrote the names to 1/2/3, and the client left the names WHITE
-- (the exact failure from the screenshot)
local P1 = MakePlate("1", WHITE, HOSTILE,      { maxhp = 31000, hp = 28000 })
local P2 = MakePlate("2", WHITE, PRIEST_WHITE, { maxhp = 22500, hp = 20500 })
local P3 = MakePlate("3", WHITE, HOSTILE,      { maxhp = 27800, hp = 25000 })
Tick(0.2)
check(not shown(P1), "arena #1 in combat -> no Sap icon (was the bug)")
check(not shown(P2), "arena #2 in combat -> no Sap icon, class-colored white bar not treated as friendly")
check(kind(P3) == "sap", "arena #3 out of combat -> Sap icon")

-- enemy resets / drops combat -> Sap icon comes back; no flicker from name color
UNITS.arena1.combat = false
Tick(0.2)
check(kind(P1) == "sap", "arena: API out, no log, white name -> Sap icon")
P1._nameFS:SetTextColor(1, 0, 0)
Tick(0.2)
check(not shown(P1), "arena: red name alone is enough (OR logic)")
P1._nameFS:SetTextColor(1, 1, 1)
-- Warmane case: API says out but the log shows them fighting (ArenaNumbers plate "1")
CLEU("SWING_DAMAGE", "Breakingbad", ENEMY_PLAYER, "Kisame", 0x0511)
Tick(0.2)
check(not shown(P1), "arena: API false but combat log (via arena1 name) -> in combat")
NOW = NOW + 7; Tick(0.2)
check(kind(P1) == "sap", "arena: log expires -> Sap icon back")
UNITS.arena1.combat = true

-- real names on the plates (no ArenaNumbers)
hidePlates(P1, P2, P3)
local N1 = MakePlate("Breakingbad", WHITE, HOSTILE, { maxhp = 31000 })
local N3 = MakePlate("Twilights", RED, HOSTILE, { maxhp = 27800 })
Tick(0.2)
check(not shown(N1), "arena real name -> arena token, in combat")
check(not shown(N3), "arena real name, API out but red name -> in combat (OR logic)")
N3._nameFS:SetTextColor(1, 1, 1); Tick(0.2)
check(kind(N3) == "sap", "arena real name, everything says out -> Sap icon")

-- some other addon renamed the plate to junk -> unique max HP match
hidePlates(N1, N3)
local R2 = MakePlate("Priest", WHITE, PRIEST_WHITE, { maxhp = 22500, hp = 20500 })
Tick(0.2)
check(not shown(R2), "arena renamed plate matched by unique max HP")

-- ambiguous max HP: two enemies with the same max; current HP disambiguates
UNITS.arena3.maxhp = 22500; UNITS.arena3.hp = 15000
R2._hp:SetValue(20500)
Tick(0.2)
check(not shown(R2), "same max HP, current HP picks arena2 (in combat)")
R2._hp:SetValue(15000)
Tick(0.2)
check(kind(R2) == "sap", "same max HP, current HP picks arena3 (out of combat)")
R2._hp:SetValue(9999)  -- no exact match -> don't guess; falls through to log/color (white)
Tick(0.2)
check(kind(R2) == "sap", "ambiguous + no exact HP -> no arena guess")
UNITS.arena3.maxhp = 27800; UNITS.arena3.hp = 25000
hidePlates(R2)

-- enemy pet: name + max HP
UNITS.arenapet1 = { name = "Fluffy", player = false, combat = true, hp = 9000, maxhp = 12000 }
local PET = MakePlate("Fluffy", WHITE, HOSTILE, { maxhp = 12000 })
local PET2 = MakePlate("Fluffy", WHITE, HOSTILE, { maxhp = 5000 })  -- same name, different HP
Tick(0.2)
check(not shown(PET), "arena pet matched by name + max HP")
check(not shown(PET2), "1.4: unmatched red pet plate -> no Sap icon (pets can't be the Sap target we want)")
hidePlates(PET, PET2)
clearUnits()

------------------------------------------------------- WORLD / BG -----------
INSTANCE = "pvp"
local ROGUE_BAR, PRIEST_BAR = { 1, 0.96, 0.41 }, { 1, 1, 1 }     -- enemy players: class colored bars
local E = MakePlate("Gankerdude", WHITE, ROGUE_BAR, { maxhp = 20000 })
local H = MakePlate("Healbot", WHITE, PRIEST_BAR, { maxhp = 18000 })
local M = MakePlate("Scarlet Monk", WHITE, HOSTILE, { maxhp = 9000 })
Tick(0.2)
check(kind(E) == "sap" and kind(H) == "sap", "idle enemy players -> Sap icon")

-- enemy hits our teammate -> in combat for 6s (cross-realm name in the log)
CLEU("SPELL_DAMAGE", "Gankerdude-Lordaeron", ENEMY_PLAYER, "Buddy", FRIEND_PLAYER, 48638)
Tick(0.2)
check(not shown(E), "combat log: enemy dealing damage -> in combat")
-- their healer heals them -> healer in combat too
CLEU("SPELL_HEAL", "Healbot", ENEMY_PLAYER, "Gankerdude", ENEMY_PLAYER, 48071)
Tick(0.2)
check(not shown(H), "combat log: healer healing an in-combat ally -> in combat")
NOW = NOW + 7
Tick(0.2)
check(kind(E) == "sap" and kind(H) == "sap", "6s after last action -> out of combat again")

-- things that must NOT count as combat
CLEU("SPELL_AURA_APPLIED", "Healbot", ENEMY_PLAYER, "Gankerdude", ENEMY_PLAYER, 6788, "DEBUFF") -- Weakened Soul
CLEU("SPELL_AURA_APPLIED", "Kisame", FRIEND_PLAYER, "Gankerdude", ENEMY_PLAYER, 51724, "DEBUFF") -- your Sap
CLEU("SPELL_DAMAGE", "Gankerdude", ENEMY_PLAYER, "Gankerdude", ENEMY_PLAYER, 32409)             -- SW:Death backlash
CLEU("SPELL_AURA_APPLIED", "Kisame", FRIEND_PLAYER, "Gankerdude", ENEMY_PLAYER, 1, "BUFF")      -- a buff
CLEU("SPELL_HEAL", "Healbot", ENEMY_PLAYER, "Gankerdude", ENEMY_PLAYER, 48071)                  -- heal on idle ally
Tick(0.2)
check(kind(E) == "sap", "Weakened Soul / Sap / self-damage / buffs don't count")
check(kind(H) == "sap", "healing an idle ally doesn't count")

-- harmful debuff from our side onto the enemy does count
CLEU("SPELL_AURA_APPLIED", "Buddy", FRIEND_PLAYER, "Healbot", ENEMY_PLAYER, 10890, "DEBUFF")   -- Fear
Tick(0.2)
check(not shown(H), "enemy debuffed by our side -> in combat")

-- NPCs are never tracked by name in the log (names aren't unique)
CLEU("SWING_DAMAGE", "Scarlet Monk", ENEMY_NPC, "Buddy", FRIEND_PLAYER)
Tick(0.2)
check(not shown(M), "NPC: never tracked for combat, and 1.4: no Sap icon on NPCs")
M._nameFS:SetTextColor(1, 0, 0); Tick(0.2)
check(not shown(M), "NPC red name -> in combat")

-- target token still exact out of arena
NOW = NOW + 10
UNITS.target = { name = "Gankerdude", player = true, combat = true }
Tick(0.2)
check(not shown(E), "target token exact outside arena")
clearUnits()

-- debug command output
CHAT = {}
cmd("debug")
local joined = table.concat(CHAT, "\n")
check(joined:find("Gankerdude") and joined:find("api:") and joined:find("log:") and joined:find("name:"), "debug lists every source")
check(joined:find("Scarlet Monk"), "debug lists NPC plate")
hidePlates(E, H, M)
CHAT = {}; cmd("debug")
check(CHAT[1] and CHAT[1]:find("no enemy nameplates"), "debug with no plates")


------------------------------------------------------------ DUEL -----------
NOW = NOW + 20
INSTANCE = "none"
cmd("mode sap")
local OPP = MakePlate("Barbozcos", WHITE, { 0.78, 0.61, 0.43 }, { maxhp = 30000 })  -- warrior class color
UNITS.target = { name = "Barbozcos", player = true, combat = false }  -- server didn't flag duel combat
Tick(0.2)
check(kind(OPP) == "sap", "duel: before anything happens -> Sap icon")
-- opponent hits you; same-faction duel so the log flags him FRIENDLY
CLEU("SWING_DAMAGE", "Barbozcos", 0x0514, "Kisame", 0x0511)
Tick(0.2)
check(not shown(OPP), "duel: damage with friendly-flagged opponent counts")
NOW = NOW + 7; Tick(0.2)
check(kind(OPP) == "sap", "duel: 6s later -> back to Sap")
-- your debuff on him (mine flag) counts even though both look friendly
CLEU("SPELL_AURA_APPLIED", "Kisame", 0x0511, "Barbozcos", 0x0514, 26679, "DEBUFF") -- Deadly Throw slow
Tick(0.2)
check(not shown(OPP), "duel: your debuff on him counts")
NOW = NOW + 7; Tick(0.2)
-- but your Sap never counts
CLEU("SPELL_AURA_APPLIED", "Kisame", 0x0511, "Barbozcos", 0x0514, 51724, "DEBUFF")
Tick(0.2)
check(kind(OPP) == "sap", "duel: your Sap doesn't count")
-- red name alone (what the screenshot showed) also hides the Sap icon
OPP._nameFS:SetTextColor(1, 0, 0); Tick(0.2)
check(not shown(OPP), "duel: red name -> in combat even with API false")
CHAT = {}; cmd("debug")
check(CHAT[1] and CHAT[1]:find("Barbozcos") and CHAT[1]:find("no %(target%)") and CHAT[1]:find("name: red"), "debug shows api no(target) + red")
OPP:Hide()
clearUnits()

------------------------------------------------ old v1.0 regressions -------
INSTANCE = "none"
cmd("mode combat")
local A = MakePlate("Orcwarrior", RED, HOSTILE)
local C = MakePlate("Guard", RED, FRIENDLY_NPC)
local D = MakePlate("Kuiplate", RED, HOSTILE, { blankBorder = true })
local kuiContainer = CreateFrame("Frame", nil, WorldFrame)
CreateFrame("StatusBar", nil, kuiContainer); CreateFrame("StatusBar", nil, kuiContainer)
for i = 1, 6 do kuiContainer:CreateFontString() end
for i = 1, 8 do kuiContainer:CreateTexture() end
Tick(0.2)
check(kind(A) == "swords", "combat mode swords on red-name plate")
check(not shown(C), "friendly hidden")
check(kind(D) == "swords", "Kui-blanked plate detected")
check(Holder(kuiContainer) == nil, "Kui container not a plate")
cmd("test"); Tick(0.2); check(shown(C) == false and kind(A) == "swords", "test mode skips friendlies")
cmd("test"); cmd("size 30"); cmd("pos top"); cmd("offset 2 -3")
local h = Holder(A)
check(h._w == 30 and h._points[1][1] == "BOTTOM" and h._points[1][5] == 13, "layout commands")
cmd("reset"); check(CombatPlatesDB.size == 20 and Holder(A)._points[1][1] == "RIGHT", "reset")
A:Hide(); check(not shown(A), "OnHide hides icon")

-- prune keeps the log table from growing (just make sure it runs clean)
NOW = NOW + 100
for i = 1, 10 do Tick(5) end
check(true, "prune ran")

-- 1.4 regression (owner: Sap icons on ghouls, totems, succubus): only players get the Sap icon
cmd("mode sap")
for k in pairs(UNITS) do UNITS[k] = nil end
INSTANCE = "pvp"
local GHOUL = MakePlate("Ghoul", WHITE, HOSTILE, { maxhp = 9000 })
local TOTEM = MakePlate("Grounding Totem", WHITE, HOSTILE, { maxhp = 5 })
local SUCC = MakePlate("Brenthea", WHITE, HOSTILE, { maxhp = 8000 })
local REDP = MakePlate("Unclassed", WHITE, HOSTILE, { maxhp = 20000 })
local CLASSP = MakePlate("Classy", WHITE, { 0.41, 0.8, 0.94 }, { maxhp = 20000 })
local PET_FLAGS, GUARDIAN_FLAGS = 0x1148, 0x2148  -- hostile pet / guardian (totems, ghouls)
CLEU("SPELL_CAST_SUCCESS", "Brenthea", PET_FLAGS, "Someone", FRIEND_PLAYER, 6358)
CLEU("SWING_DAMAGE", "Ghoul", GUARDIAN_FLAGS, "Someone", FRIEND_PLAYER)
CLEU("SPELL_AURA_APPLIED", "Unclassed", ENEMY_PLAYER, "Unclassed", ENEMY_PLAYER, 1, "BUFF")
NOW = NOW + 7
Tick(0.2)
check(not shown(GHOUL) and not shown(TOTEM) and not shown(SUCC), "no Sap icon on ghoul / totem / succubus")
check(kind(CLASSP) == "sap", "class-colored bar = player -> Sap icon")
check(kind(REDP) == "sap", "red bar but the combat log knows it's a player -> Sap icon")
hidePlates(GHOUL, TOTEM, SUCC, REDP, CLASSP)
clearUnits()

-- 1.3: CombatPlates_InCombat(unit) for ArenaFrames' Sap icon on the target frame
for k in pairs(UNITS) do UNITS[k] = nil end
check(CombatPlates_InCombat("target") == nil, "API: no unit -> nil")
UNITS.target = { name = "Sappy", player = true, combat = false }
check(CombatPlates_InCombat("target") == false, "API: idle player -> false")
UNITS.target.combat = true
check(CombatPlates_InCombat("target") == true, "API: UnitAffectingCombat -> true")
UNITS.target.combat = false
CLEU("SWING_DAMAGE", "Sappy", ENEMY_PLAYER, "Someone", FRIEND_PLAYER)
check(CombatPlates_InCombat("target") == true, "API: combat log (API says no) -> true")
NOW = NOW + 7
check(CombatPlates_InCombat("target") == false, "API: log expired -> false")
CLEU("SPELL_AURA_APPLIED", "Me", FRIEND_PLAYER, "Sappy", ENEMY_PLAYER, 6770, "DEBUFF")
check(CombatPlates_InCombat("target") == false, "API: being Sapped doesn't count as combat")

print(string.format("%d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
