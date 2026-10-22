-- ArenaFrames 3.6 alerts for a disc priest: SWD on Polymorph aimed at you, Scatter warning;
-- 3.7: no separate target/focus DR display (any class);
-- 3.6.2: Poly through focus / arena macros (maybe you), server-sent cast target wins
dofile("tests/harness.lua")
UNITS.player = { name = "Me", player = true, guid = "0xME", class = "PRIEST", hp = 1, maxhp = 1 }
TALENTS = { 51, 20, 0 }                          -- Discipline
LoadAddon("ArenaFrames")

local pass, fail = 0, 0
local function check(cond, label)
  if cond then pass = pass + 1 else fail = fail + 1; print("FAIL: " .. label) end
end
local function rows()
  local out = {}
  for i = 1, 3 do local r = _G["ArenaFramesAlert" .. i]; if r._shown then table.insert(out, r) end end
  return out
end
local function near(a, b) return a and b and math.abs(a - b) < 0.011 end
local function color(t, r, g, b) return t and near(t[1], r) and near(t[2], g) and near(t[3], b) end
local function step() for _ = 1, 3 do Tick(0.05) end end

FireEvent("ADDON_LOADED", "ArenaFrames")
INSTANCE = "arena"
FireEvent("PLAYER_ENTERING_WORLD")
UNITS.arena1 = { name = "Frostbolt", player = true, guid = "0xA1", class = "MAGE", hp = 1, maxhp = 1, reaction = 2 }
UNITS.arena1target = { name = "Mate", player = true, guid = "0xP1" }
Tick(0.2)
UNITS.arena1.cast = { name = "Polymorph", start = NOW, endt = NOW + 1.5 }
step()
-- 3.6.2: mages Poly through focus / arena macros and 3.3.5 can't show who it's aimed at
check(#rows() == 1 and rows()[1].label._text == "Polymorph (you?) - Frostbolt (1)"
  and rows()[1].status._text:find("SWD in"), "his target is someone else: focus / arena macro -> maybe you")
IN_RANGE.arena1 = 0; step()
check(#rows() == 0, "mage out of SWD range: can't be on you")
IN_RANGE.arena1 = nil
SlashCmdList.ARENAFRAMES("swd target"); step()
check(#rows() == 0 and ArenaFramesDB.swdpoly == "target", "swd target: only when the mage targets you")
SlashCmdList.ARENAFRAMES("swd all"); step()
check(#rows() == 1, "swd all: back")
-- if the server sends the cast's target in SPELL_CAST_START, it decides
local function PolyStart(dst)
  FireEvent("COMBAT_LOG_EVENT_UNFILTERED", NOW, "SPELL_CAST_START", "0xA1", "Frostbolt", 0x0548, dst, nil, 0,
    118, "Polymorph", 64)
end
PolyStart("0xP1"); step()
check(#rows() == 0, "log says Poly on Mate: no SWD alert")
PolyStart("0xME"); step()
check(#rows() == 1 and rows()[1].label._text == "Polymorph on you - Frostbolt (1)", "log says Poly on you: sure")
PolyStart("0x0000000000000000"); step()
check(rows()[1].label._text == "Polymorph (you?) - Frostbolt (1)", "empty target in the log: back to guessing")
CHAT = {}
SlashCmdList.ARENAFRAMES("debug")
check(table.concat(CHAT, "\n"):find("last enemy Polymorph / Seduction cast start: Polymorph by Frostbolt %-> no target in the log"),
  "debug shows what the log sent")
UNITS.arena1target = UNITS.player
step()
local r = rows()
check(#r == 1 and r[1].icon.icon._tex:find("ShadowWord") and r[1].label._text == "Polymorph on you - Frostbolt (1)",
  "Poly aimed at you -> Shadow Word: Death")
check(r[1].status._text:find("SWD in"), "wait for the end of the cast")
NOW = NOW + 0.45; step()                       -- 1.05 s left: backlash would tick before the sheep
check(rows()[1].status._text:find("SWD in"), "too early: wait")
NOW = NOW + 0.1; step()                        -- 0.95 s left <= latency 0.1 + 0.9 (3.7.1)
check(rows()[1].status._text == "NOW!", "NOW from latency + 0.9 s left (backlash ticks 1 s after SWD)")
-- 3.9 (owner: "big swd icon and stopcasting so I can click swd instantly")
local SWDB = ArenaFramesSWD
check(SWDB._alpha == 1 and color(SWDB._bdBorder, 1, 0.15, 0.15), "big SWD button lights up red on NOW")
NOW = NOW + 0.6; step()                        -- 0.35 s left
check(rows()[1].status._text == "NOW!", "still NOW with 0.35 s left")
NOW = NOW + 0.3; step()                        -- 0.05 s left < latency: can't reach the server in time
check(rows()[1].status._text == "too late", "under your latency: too late")
NOW = NOW - 0.3
SPELL_CD["Shadow Word: Death"] = { NOW - 1, 12 }; step()
check(rows()[1].status._text == "SWD on cd", "SWD on cooldown")
SPELL_CD["Shadow Word: Death"] = nil
UNITS.arena1.cast = nil

-- 3.6.3: a warlock's Succubus (arenapet) casting Seduction, also through focus / arena macros
UNITS.arena3 = { name = "Lockz", player = true, guid = "0xA3", class = "WARLOCK", hp = 1, maxhp = 1, reaction = 2 }
UNITS.arenapet3 = { name = "Jhaarsi", guid = "0xPET3", hp = 1, maxhp = 1, reaction = 2,
  cast = { name = "Seduction", start = NOW, endt = NOW + 1.5 } }
UNITS.arenapet3target = { name = "Mate", player = true, guid = "0xP1" }
step()
check(#rows() == 1 and rows()[1].label._text == "Seduction (you?) - Jhaarsi (3)" and rows()[1].status._text:find("SWD in"),
  "Succubus Seduction on someone else: maybe you")
UNITS.arenapet3target = UNITS.player; step()
check(rows()[1].label._text == "Seduction on you - Jhaarsi (3)", "Succubus targets you: Seduction on you")
NOW = NOW + 1.15; step()
check(rows()[1].status._text == "NOW!", "Seduction: NOW just before it lands")
UNITS.arena3, UNITS.arenapet3, UNITS.arenapet3target = nil, nil, nil
step()
check(#rows() == 0, "Seduction over: nothing")

-- 3.9: the big SWD button; 3.9.1 (owner: "should be displayed only when poly is casted")
local SWDB = ArenaFramesSWD
check(SWDB and SWDB._protected and SWDB._w == 64, "disc: big SWD button (secure, 64 px)")
local mt = SWDB:GetAttribute("macrotext")
check(SWDB:GetAttribute("type") == "macro" and mt:find("^/stopcasting\n/cast %[harm,nodead%]%[target=focus,harm,nodead%]")
  and mt:find("%[target=arena5,harm,nodead%] Shadow Word: Death$") and #mt <= 255,
  "macro: /stopcasting, then SWD on enemy target > focus > arena1-5 (fits 255 chars)")
check(not SWDB._shown, "no Poly coming, out of combat: hidden")
local mage = UNITS.arena1
local function poly() mage.cast = { name = "Polymorph", start = NOW, endt = NOW + 1.5 }; UNITS.arena1target = UNITS.player end
local function nopoly() mage.cast, UNITS.arena1target = nil, nil end
poly(); step()
check(SWDB._shown and SWDB._alpha == 1 and color(SWDB._bdBorder, 1, 0.85, 0.1), "Poly coming: shown, yellow border")
check(SWDB.who._text == "-> Frostbolt (arena1)", "shows who a click hits")
UNITS.focus = mage; step()
check(SWDB.who._text == "-> Frostbolt (focus)", "focus before arena units")
UNITS.focus = nil
SPELL_CD["Shadow Word: Death"] = { NOW - 1, 12 }; step()
check(SWDB.cd._cd and SWDB.cd._cd[2] == 12, "SWD cooldown sweep on the button")
SPELL_CD["Shadow Word: Death"] = nil
nopoly(); step()
check(not SWDB._shown, "Poly over: hidden again")
-- combat: Show / Hide are protected, so it goes in shown but invisible and only changes alpha
FireEvent("PLAYER_REGEN_DISABLED")
COMBAT = true
step()
check(SWDB._shown and SWDB._alpha == 0, "in combat, no Poly: invisible (alpha 0)")
poly(); step()
check(SWDB._shown and SWDB._alpha == 1, "in combat, Poly coming: visible")
nopoly(); step()
check(SWDB._alpha == 0, "in combat, Poly over: invisible again")
SlashCmdList.ARENAFRAMES("swdsize 90")           -- protected: must wait for the end of combat
check(SWDB._w == 64, "in combat: size change waits")
COMBAT = false
FireEvent("PLAYER_REGEN_ENABLED")
step()
check(SWDB._w == 90 and not SWDB._shown, "after combat: size applied, hidden")
SlashCmdList.ARENAFRAMES("swdbutton off")
poly(); step()
check(not SWDB._shown, "swdbutton off: never shown")
nopoly()
SlashCmdList.ARENAFRAMES("swdbutton on")
SlashCmdList.ARENAFRAMES("unlock")
step()
check(SWDB._shown and SWDB:GetAttribute("type") == nil and SWDB._drag, "unlock: shown to drag, clicks do nothing")
check(SWDB.who._text == "-> Frostbolt (focus)", "unlock: preview")
FireEvent("PLAYER_REGEN_DISABLED")               -- combat while unlocked: test ends, button still ready
check(SWDB._shown and SWDB._alpha == 0 and SWDB:GetAttribute("type") == "macro", "combat ends test mode: ready, invisible")
FireEvent("PLAYER_REGEN_ENABLED"); step()
check(not SWDB._shown, "out of combat again: hidden")

-- a hunter with Scatter ready nearby
UNITS.arena2 = { name = "Huntard", player = true, guid = "0xA2", class = "HUNTER", hp = 1, maxhp = 1, reaction = 2 }
Tick(0.2)
step()
check(#rows() == 0, "hunter far away: nothing")
NEAR.arena2 = 20; step()
r = rows()
check(#r == 1 and r[1].label._text:find("Scatter maybe ready") and r[1].status._text == "close", "hunter ~28 yd, spec unknown")
NEAR.arena2 = 9; step()
check(rows()[1].status._text == "IN RANGE", "inside ~11 yd: red")
FireEvent("COMBAT_LOG_EVENT_UNFILTERED", NOW, "SPELL_CAST_SUCCESS", "0xA2", "Huntard", 0x0548, nil, nil, nil,
  19503, "Scatter Shot", 1)
step()
check(#rows() == 0, "Scatter used -> on cooldown -> no warning")
NOW = NOW + 31; step()
check(#rows() == 1 and rows()[1].label._text:find("Scatter ready"), "30 s later: ready again (known now, no 'maybe')")

-- 3.7: no separate target/focus DR display (any class);
-- 3.6.2: Poly through focus / arena macros (maybe you), server-sent cast target wins; the arena rows keep their DRs
local function rowDRs(i)
  local out = {}
  for _, d in ipairs(_G["ArenaFramesRow" .. i].drs) do if d._shown then table.insert(out, d) end end
  return out
end
UNITS.target = UNITS.arena1
FireEvent("COMBAT_LOG_EVENT_UNFILTERED", NOW, "SPELL_AURA_APPLIED", "0xME", "Me", 0x0511, "0xA1", "Frostbolt",
  0x0548, 1833, "Cheap Shot", 1, "DEBUFF")
Tick(0.2)
check(ArenaFramesCenter == nil, "3.7: no separate DR display at all (removed for every class)")
check(#rowDRs(1) == 1, "the arena row still shows the DR")
UNITS.target = nil

CHAT = {}
SlashCmdList.ARENAFRAMES("")
check(table.concat(CHAT, "\n"):find("SWD on Polymorph / Seduction aimed at you"), "help says what you get as disc")
check(table.concat(CHAT, "\n"):find("click an arena row: left = target, right = focus"), "help explains the row clicks")
check(table.concat(CHAT, "\n"):find("/aframes swd all|target (now all)", 1, true), "help lists the swd option")
SlashCmdList.ARENAFRAMES("test"); Tick(0.2)
check(#rows() == 3 and rows()[3].label._text == "Kisame 34% - stop LoSing me", "test mode previews the LoS row")
SlashCmdList.ARENAFRAMES("test"); Tick(0.2)

-- 3.15.2: every enemy Poly cast start is recorded with what the alert saw (owner: "swd didn't appear")
ArenaFramesDB.swdTrace = nil
UNITS.arena1target = { name = "Mate", player = true, guid = "0xP1" }
UNITS.arena1.cast = { name = "Polymorph", start = NOW, endt = NOW + 1.0 }
FireEvent("COMBAT_LOG_EVENT_UNFILTERED", NOW, "SPELL_CAST_START", "0xA1", "Frostbolt", 0x20548, "0x0000000000000000",
  nil, 0x80000000, 12826, "Polymorph", 0x40)
step()
local tr = ArenaFramesDB.swdTrace and ArenaFramesDB.swdTrace[1]
check(tr and tr.caster == "Frostbolt" and tr.profile == "disc" and tr.unit == "arena1" and tr.targetsMe == "no"
  and tr.alert and tr.button and tr.button:find("^shown yes"), "Poly cast recorded: unit, target, alert, button")
CHAT = {}
SlashCmdList.ARENAFRAMES("debug")
check(table.concat(CHAT, "\n"):find("Polymorph by Frostbolt: profile disc, unit arena1", 1, true), "debug lists it")
FireEvent("COMBAT_LOG_EVENT_UNFILTERED", NOW, "SPELL_CAST_START", "0xP1", "Mate", 0x512, "0x0000000000000000",
  nil, 0x80000000, 12826, "Polymorph", 0x40)
check(#ArenaFramesDB.swdTrace == 1, "a teammate's Poly isn't recorded")
UNITS.arena1.cast = nil

-- 3.16 (owner: "stop LoSing me notification for priest if party is low and LoSing / out of ranging me")
for i = 1, 5 do UNITS["arena" .. i], UNITS["arenapet" .. i] = nil, nil end
UNITS.target, UNITS.focus = nil, nil
PARTY = 2
UNITS.party1 = { name = "Kisame", player = true, guid = "0xP1", class = "ROGUE", hp = 9000, maxhp = 20000 }
UNITS.party2 = { name = "Durimlok", player = true, guid = "0xP2", class = "MAGE", hp = 20000, maxhp = 20000 }
IN_RANGE.party1, IN_RANGE.party2 = 1, 1
SOUNDS, SENT = {}, {}
step()
check(#rows() == 0, "out of combat: nothing")
UNITS.player.combat = true
step()
check(#rows() == 0, "low but healable: nothing")
FireEvent("UNIT_SPELLCAST_SENT", "player", "Flash Heal", "", "Kisame")
FireEvent("UI_ERROR_MESSAGE", "Target not in line of sight")
step()
check(#rows() == 1 and rows()[1].label._text == "Kisame 45% - stop LoSing me" and rows()[1].status._text == "NO LOS",
  "your heal on him failed with LoS: NO LOS")
check(#SOUNDS == 1, "sound once per warning")
step()
check(#SOUNDS == 1, "not repeated every tick")
check(#SENT == 0, "no party message unless losparty on")
FireEvent("COMBAT_LOG_EVENT_UNFILTERED", NOW, "SPELL_HEAL", "0xME", "Me", 0x511, "0xP1", "Kisame", 0x512,
  2061, "Flash Heal", 2, 3000, 0, nil)
step()
check(#rows() == 0, "your heal landed on him: back in LoS")
IN_RANGE.party1 = 0
step()
check(#rows() == 1 and rows()[1].status._text == "OUT OF RANGE", "out of Flash Heal range")
IN_RANGE.party2 = 0
step()
check(#rows() == 1, "a full-health teammate far away: no warning")
UNITS.party1.hp = 15000
step()
check(#rows() == 0, "above loshp: no warning")
SlashCmdList.ARENAFRAMES("loshp 80"); step()
check(#rows() == 1, "loshp 80")
SlashCmdList.ARENAFRAMES("los off"); step()
check(#rows() == 0, "los off")
SlashCmdList.ARENAFRAMES("los on"); SlashCmdList.ARENAFRAMES("losparty on")
UNITS.party1.hp = 4000
step()
check(SENT[1] and SENT[1][1] == "Kisame, come to me, out of range! (20%)" and SENT[1][2] == "PARTY",
  "losparty: tells him in party chat (arena)")
UNITS.player.combat = nil
PARTY = 0

-- 3.20 (owner: "announce on priest that I'm low, need BoP if we have a pala, or need peel")
local function hit(sub, src, amount, school)
  if sub == "SWING_DAMAGE" then
    FireEvent("COMBAT_LOG_EVENT_UNFILTERED", NOW, sub, src, "Gorehowl", 0x548, "0xME", "Me", 0x511, amount)
  else
    FireEvent("COMBAT_LOG_EVENT_UNFILTERED", NOW, sub, src, "Burnbaby", 0x548, "0xME", "Me", 0x511, 1, "x", school, amount)
  end
end
SlashCmdList.ARENAFRAMES("los off")
PARTY = 2
UNITS.party1 = { name = "Holypala", player = true, guid = "0xP1", class = "PALADIN", hp = 20000, maxhp = 20000 }
UNITS.party2 = { name = "Durimlok", player = true, guid = "0xP2", class = "MAGE", hp = 20000, maxhp = 20000 }
UNITS.arena1 = { name = "Gorehowl", player = true, guid = "0xA1", class = "WARRIOR", hp = 1, maxhp = 1, reaction = 2 }
UNITS.target = UNITS.arena1
UNITS.player.hp, UNITS.player.maxhp, UNITS.player.combat = 30, 100, true
SENT = {}
hit("SWING_DAMAGE", "0xA1", 4000)
step()
check(SENT[1] and SENT[1][1] == "Holypala, BOP me! 30% - warr on me" and SENT[1][2] == "PARTY",
  "low + physical damage + pala in team: ask for BoP, name the warrior")
NOW = NOW + 20; step()
check(#SENT == 1, "once per dip: not again while still low")
UNITS.player.hp = 60; step()
UNITS.player.hp = 25
FireEvent("COMBAT_LOG_EVENT_UNFILTERED", NOW, "SPELL_CAST_SUCCESS", "0xP1", "Holypala", 0x511, "0xME", "Me", 0x511,
  10278, "Hand of Protection", 2)
hit("SWING_DAMAGE", "0xA1", 4000)
step()
check(SENT[2] and SENT[2][1] == "Holypala, SAC me! 25% - warr on me", "BoP used: ask for Sacrifice")
UNITS.party1.class = "ROGUE"
UNITS.player.hp = 60; NOW = NOW + 20; step()
UNITS.player.hp = 20
hit("SPELL_DAMAGE", "0xA2", 5000, 4)
hit("SWING_DAMAGE", "0xA1", 3000)
step()
check(SENT[3] and SENT[3][1]:find("^PEEL me! 20%% %- Burnbaby %+ warr on me") , "no pala: ask for a peel, top attackers first")
UNITS.player.hp = 60; NOW = NOW + 20; step()
INSTANCE = "none"; UNITS.player.hp = 20; step()
check(#SENT == 3, "outside arena: never")
INSTANCE = "arena"
SlashCmdList.ARENAFRAMES("lowcall off"); step()
check(#SENT == 3, "lowcall off")
SlashCmdList.ARENAFRAMES("lowcall on")
UNITS.player.combat, UNITS.target, UNITS.arena1 = nil, nil, nil
UNITS.player.hp, UNITS.player.maxhp = 1, 1
PARTY = 0

print(string.format("%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
