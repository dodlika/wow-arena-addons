-- ArenaFrames 3.4: party frames + party cooldown icons
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
local function shown(list)
  local out = {}
  for _, b in ipairs(list) do if b._shown then table.insert(out, b) end end
  return out
end
local MATE = 0x0514                               -- friendly player in my party

FireEvent("ADDON_LOADED", "ArenaFrames")
FireEvent("PLAYER_ENTERING_WORLD")
local P1, P2 = ArenaFramesParty1, ArenaFramesParty2

------------------------------------------------------------- setup ---------
check(P1 and P2 and ArenaFramesParty4, "party frames 1-4 exist")
check(P1._protected and P1:GetAttribute("unit") == "party1" and P1:GetAttribute("*type1") == "target",
  "clickable party frames")
check(IsUnitWatched(P1), "shown whenever party1 exists (unit watch)")
OPENED_MENU = nil
SecureClick(P1, "RightButton")
check(OPENED_MENU == "PartyMemberFrame1DropDown", "right click opens Blizzard's party menu")
check(not PartyMemberFrame1._shown and PartyMemberFrame1._all == P1, "Blizzard party frame hidden, sitting on ours")
Tick(0.2)
check(not P1._shown, "no party -> hidden")

-- 3.5: you're the first box, party 1 / 2 under you
local ME = ArenaFramesPlayer
check(ME and ME.isParty and ME._shown and ME.name._text == "Me", "your box at the top, shown")
check(P1._points[1][2] == ME and P1._points[1][3] == "BOTTOMLEFT", "party1 hangs under your box")
check(P2._points[1][2] == P1, "party2 under party1")
-- 3.8.4 (owner: "can't see if I'm in combat")
check(not ME.combat._shown and not ME.combatGlow._shown, "out of combat: no swords, no red outline")
UNITS.player.combat = true; Tick(0.2)
check(ME.combat._shown and ME.combatGlow._shown and ME.combat._tex:find("UI%-StateIcon"), "in combat: swords + red outline")
UNITS.player.combat = nil; Tick(0.2)
check(not ME.combat._shown and not ME.combatGlow._shown, "combat over: gone")
check(P1.combat == nil, "only your own box shows it")
OPENED_MENU = nil
SecureClick(ME, "RightButton")
check(OPENED_MENU == "PlayerFrameDropDown", "right click on your box: Blizzard's player menu")

------------------------------------------------------------- members -------
UNITS.party1 = { name = "Elcemento", player = true, guid = "0xP1", class = "ROGUE", hp = 15000, maxhp = 20000,
  ptype = 3, power = 50, maxpower = 100, reaction = 5 }
UNITS.party2 = { name = "Hydramon", player = true, guid = "0xP2", class = "PRIEST", hp = 9000, maxhp = 18000,
  ptype = 0, power = 9000, maxpower = 20000, reaction = 5 }
FireEvent("PARTY_MEMBERS_CHANGED")
Tick(0.2)
check(P1._shown and P2._shown and not ArenaFramesParty3._shown, "party1 + party2 shown")
check(P1.name._text == "Elcemento" and color(P1.hp._bar, 1, 0.96, 0.41) and P1.hp._val == 15000,
  "name, class-colored health")
check(not P1.power._shown and P2.power._shown and color(P2.power._bar, 0.25, 0.45, 1), "mana bar only for mana users")
-- 3.8.3 (owner: "no party pet frames at all"; Blizzard's pet frames went with the hidden party frames)
local PET1 = ArenaFramesPartyPet1
check(PET1 and PET1._protected and PET1:GetAttribute("unit") == "partypet1" and PET1:GetAttribute("*type1") == "target",
  "clickable party pet box")
check(not PET1._shown, "no pet -> hidden")
check(PET1._points[1][2] == P1 and PET1._points[1][3] == "TOPRIGHT", "pet box right of its owner's box")
UNITS.partypet1 = { name = "Felhunter", guid = "0xPP1", hp = 3000, maxhp = 6000 }
Tick(0.2); Tick(0.2)
check(PET1._shown and PET1.name._text == "Felhunter" and PET1.pct._text == "50%" and PET1.hp._val == 3000,
  "party pet: name, health")
check(not ArenaFramesPartyPet2._shown, "party2 has no pet -> hidden")
UNITS.partypet1.dead = true; Tick(0.2)
check(PET1.pct._text == "DEAD", "dead pet")
UNITS.partypet1 = nil; Tick(0.2)
check(not PET1._shown, "pet dismissed -> hidden")
UNITS.party2.far = true; Tick(0.2)
check(P2._alpha == 0.55 and P1._alpha == 1, "out of range -> faded")
UNITS.party2.far = nil
UNITS.party2.offline = true; Tick(0.2)
check(P2.status._text == "OFFLINE", "offline")
UNITS.party2.offline = nil
UNITS.party1.dead = true; Tick(0.2)
check(P1.status._text == "DEAD", "dead")
UNITS.party1.dead = nil; Tick(0.2)

-- CC on a mate, debuffs (dispellable first), important buffs
UNITS.party1.auras = {
  { name = "Cheap Shot", id = 1833, harmful = true, dur = 4, expires = NOW + 3 },
  { name = "Mind Flay", id = 48156, harmful = true, dur = 3, expires = NOW + 2 },
  { name = "Corruption", id = 47813, harmful = true, dur = 18, expires = NOW + 12, dtype = "Magic" },
  { name = "Arcane Intellect", id = 42995, harmful = false, dur = 3600, expires = NOW + 3000 },
  { name = "Hand of Freedom", id = 1044, harmful = false, dur = 6, expires = NOW + 5 },
}
FireEvent("UNIT_AURA", "party1"); Tick(0.2)
check(P1.cc._shown and P1.cc.icon._tex:find("CheapShot") and P1.cc.text._text == "3.0", "CC in the middle with time left")
local deb = shown(P1.debuffs)
check(#deb == 3 and deb[1].icon._tex:find("Corruption") and color(deb[1]._bdBorder, 0.2, 0.6, 1),
  "debuffs: dispellable (magic) first, border by type")
local buf = shown(P1.buffs)
check(#buf == 1 and buf[1].icon._tex:find("HandofFreedom"), "buffs: important ones only")
UNITS.party1.auras = nil
FireEvent("UNIT_AURA", "party1"); Tick(0.2)
check(not P1.cc._shown and #shown(P1.debuffs) == 0, "cleared")

------------------------------------------------------------- cooldowns -----
local cds = shown(P1.cds)
check(#cds >= 8 and cds[1].icon._tex:find("TrinketPVP_01"), "rogue mate: trinket (faction icon) + rogue cooldowns, all ready")
check(cds[1].text._text == "" and not cds[1].cd._shown, "ready = no timer")
FireEvent("COMBAT_LOG_EVENT_UNFILTERED", NOW, "SPELL_CAST_SUCCESS", "0xP1", "Elcemento", MATE, nil, nil, nil,
  2094, "Blind", 1)
Tick(0.2)
local blind
for _, b in ipairs(shown(P1.cds)) do if b.icon._tex:find("Blind") then blind = b end end
check(blind and blind.cd._shown and blind.text._text == "2:00", "used cooldown shows its timer")
check(#shown(ArenaFramesCooldowns.icons) == 0, "a mate's cooldown is not on the enemy bar")
local cds2 = shown(P2.cds)
-- regression (3.7.1 in 2v2: only a "Dispel Magic" icon = the trinket spell's own icon, no class cooldowns)
check(#cds2 == 6 and cds2[1].icon._tex:find("TrinketPVP") and not cds2[1].icon._tex:find("DispelMagic"),
  "non-human priest mate: trinket + 5 priest baseline cooldowns (no EMFH, no talent ones yet)")
FireEvent("COMBAT_LOG_EVENT_UNFILTERED", NOW, "SPELL_CAST_SUCCESS", "0xP2", "Hydramon", MATE, nil, nil, nil,
  33206, "Pain Suppression", 1)
Tick(0.2)
cds2 = shown(P2.cds)
check(#cds2 == 7 and cds2[7].cd._shown, "talent cooldown (Pain Suppression) appears once used, with its timer")
FireEvent("COMBAT_LOG_EVENT_UNFILTERED", NOW, "SPELL_CAST_SUCCESS", "0xPET", "Gorilla", 0x1114, nil, nil, nil,
  99999, "Kick", 1)
Tick(0.2)
check(#shown(P2.cds) == 7, "a pet spell matched only by name is ignored")
UNITS.party2.race = "Human"; Tick(0.2)
check(#shown(P2.cds) == 8, "human: Every Man for Himself too")
local first = cds[1]
check(first._points[1][1] == "TOPRIGHT" and first._points[1][2] == P1 and first._points[1][3] == "TOPLEFT",
  "cooldown grid on the left of the frame")

------------------------------------------------------------- raid ----------
-- regression (3.4 in game: no party frames in arena): Warmane's solo queue puts the arena
-- team in a raid group; party1/party2 still exist there and must show
RAID = 3; Tick(0.2)
check(P1._shown and P2._shown, "raid group (solo queue arena): party frames still shown")
RAID = 0; Tick(0.2)
CHAT = {}
cmd("debug")
check(table.concat(CHAT, "\n"):find("party1: Elcemento, frame shown"), "debug lists the party frames")

------------------------------------------------------------- test mode -----
UNITS.party1, UNITS.party2 = nil, nil
Tick(0.2)
cmd("unlock"); Tick(0.2)
check(P1._shown and P2._shown and P1.name._text == "Elcemento" and P2.name._text == "Hydramon", "unlock previews party1/2")
check(P1.cc._shown and #shown(P1.debuffs) == 1 and #shown(P1.buffs) == 1, "preview: CC, debuff, buff")
local used = 0
for _, b in ipairs(shown(P1.cds)) do if b.cd._shown then used = used + 1 end end
check(used == 2, "preview: two cooldowns on timers")
check(ArenaFramesPartyPet1._shown and ArenaFramesPartyPet1.name._text == "Felhunter", "preview: party1's pet")
check(ME.combat._shown, "preview: combat swords on your box")
P2:GetScript("OnDragStart")(P2)                 -- dragging any box moves the stack (hangs off your box)
ArenaFramesPlayer._points = { { "TOPLEFT", UIParent, "TOPLEFT", 120, -300 } }
P2:GetScript("OnDragStop")(P2)
check(ArenaFramesDB.ufpos_party and ArenaFramesDB.ufpos_party[2] == 120, "group position saved")
cmd("pcdsize 24")
check(P1.cds[1]._w == 24, "pcdsize")
cmd("lock"); Tick(0.2)
check(not P1._shown and IsUnitWatched(P1), "lock: back to the real party (none)")
check(not ArenaFramesPartyPet1._shown and IsUnitWatched(ArenaFramesPartyPet1), "lock: pet box back to its unit watch")

print(string.format("%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
