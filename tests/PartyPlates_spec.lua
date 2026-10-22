-- CombatPlates 1.5: teammates' nameplates -> class icon + name + their cooldowns (from ArenaFrames)
dofile("tests/harness.lua")
UNITS.player = { name = "Me", player = true, guid = "0xME", class = "ROGUE", hp = 1, maxhp = 1 }
LoadAddon("ArenaFrames")
LoadAddon("CombatPlates")

local pass, fail = 0, 0
local function check(cond, label)
  if cond then pass = pass + 1 else fail = fail + 1; print("FAIL: " .. label) end
end
local function cp(s) SlashCmdList.COMBATPLATES(s) end
local function widget(p)
  for _, c in ipairs(p._children) do if c._type == "Frame" and c.class then return c end end
end
local function regionsAlpha(p)
  local all0, all1 = true, true
  for _, r in ipairs(p._regions) do
    if (r._alpha or 1) ~= 0 then all0 = false end
    if (r._alpha or 1) ~= 1 then all1 = false end
  end
  return all0, all1
end
local BLUE, RED, WHITE = { 0, 0, 1 }, { 1, 0, 0 }, { 1, 1, 1 }

FireEvent("ADDON_LOADED", "ArenaFrames")
FireEvent("ADDON_LOADED", "CombatPlates")
FireEvent("PLAYER_ENTERING_WORLD")

UNITS.party1 = { name = "Elcemento", player = true, guid = "0xP1", class = "ROGUE", hp = 1, maxhp = 1, reaction = 5 }
local P = MakePlate("Elcemento", WHITE, BLUE, { maxhp = 20000 })
local E = MakePlate("Badguy", WHITE, RED, { maxhp = 20000 })
local O = MakePlate("Randomfriend", WHITE, BLUE, { maxhp = 20000 })
Tick(0.2)
local w = widget(P)
check(w and w._shown, "teammate's plate gets the widget")
check(w.class._tex == "Interface\\TargetingFrame\\UI-Classes-Circles" and w.class._coords[1] == 0.49609375,
  "round rogue class icon")
check(w.name._text == "Elcemento" and w.name._c[1] == 1 and w.name._c[2] == 0.96, "name in class color")
local all0 = regionsAlpha(P)
check(all0 and P._hp._alpha == 0, "the plate's own parts are invisible (alpha 0, nothing hidden)")
check(P._nameFS._w == 0.001, "1.5.3: Blizzard's name squeezed to nothing (the client resets its alpha)")
check(w._scale == 1.5, "1.5.3: bigger by default (partysize 1.5)")
local _, eAll1 = regionsAlpha(E)
check(eAll1 and not widget(E), "enemy plate untouched")
check(not widget(O) and select(2, regionsAlpha(O)), "a friendly player who isn't in the party: untouched")

-- their cooldowns from ArenaFrames
FireEvent("COMBAT_LOG_EVENT_UNFILTERED", NOW, "SPELL_CAST_SUCCESS", "0xP1", "Elcemento", 0x0514, nil, nil, nil,
  2094, "Blind", 1)
NOW = NOW + 9
Tick(0.2)
check(w.cds[1]._shown and w.cds[1].icon._tex:find("Blind") and w.cds[1].text._text == "1:51",
  "used cooldown with time left next to the class icon")
check(not w.cds[2]._shown, "only what's running")

-- plate recycled: everything goes back
P:Hide()
local _, back = regionsAlpha(P)
check(back and P._hp._alpha == 1 and not w._shown, "OnHide gives the plate its look back")
check(P._nameFS._w == 0, "name gets its normal (auto) width back")
P._nameFS:SetText("Badguy2"); P._hp:SetStatusBarColor(1, 0, 0)
P:Show(); Tick(0.2)
check(not w._shown and select(2, regionsAlpha(P)), "reused for an enemy: normal plate")
P:Hide()
P._nameFS:SetText("Elcemento (*)"); P._hp:SetStatusBarColor(0, 0, 1)
P:Show(); Tick(0.2)
check(w._shown, "cross-realm name with (*) still matches")

cp("partysize 2"); Tick(0.2)
check(w._scale == 2, "/cplates partysize")
cp("party off"); Tick(0.2)
check(not w._shown and select(2, regionsAlpha(P)), "/cplates party off restores the plate")
cp("party on"); Tick(0.2)
check(w._shown, "/cplates party on")

-- friendly plates are switched on in arena, and back off after
INSTANCE = "arena"
FireEvent("PLAYER_ENTERING_WORLD")
check(CVARS.nameplateShowFriends == "1" and CVARS.nameplateShowFriendlyPets == "0"
  and CVARS.nameplateShowFriendlyTotems == "0", "arena: friendly plates on, pets/guardians/totems off")
INSTANCE = "none"
FireEvent("PLAYER_ENTERING_WORLD")
check(CVARS.nameplateShowFriends == "0" and CVARS.nameplateShowFriendlyPets == "1", "left arena: old values back")
INSTANCE = "arena"
COMBAT = true
FireEvent("PLAYER_ENTERING_WORLD")
check(CVARS.nameplateShowFriends == "0", "in combat (reload mid-fight): waits")
COMBAT = false
FireEvent("PLAYER_REGEN_ENABLED")
check(CVARS.nameplateShowFriends == "1", "set once combat ends")
cp("friends off")
check(CVARS.nameplateShowFriends == "0", "/cplates friends off puts the old value back")
INSTANCE = "none"
FireEvent("PLAYER_ENTERING_WORLD")

-- 1.5.2: raid-group teammates (solo queue), name-first matching, friendly plates kept on
UNITS.raid1 = { name = "Me", player = true, guid = "0xME" }
UNITS.raid2 = { name = "Raidmate", player = true, guid = "0xR2", class = "PRIEST", reaction = 5 }
RAID = 2
local R = MakePlate("Raidmate", WHITE, { 0, 0.2, 0.9 }, { maxhp = 20000 })   -- not exactly (0,0,1)
local H = MakePlate("Raidmate", WHITE, RED, { maxhp = 20000 })               -- hostile red, same name
Tick(0.2)
check(widget(R) and widget(R)._shown and widget(R).class._coords[1] == 0.49609375 and widget(R).class._coords[3] == 0.25,
  "raid-group teammate (not party1-4), bar not exactly blue: widget with priest icon")
check(not widget(H), "hostile red plate is never a teammate")
cp("friends on")
INSTANCE = "arena"
FireEvent("PLAYER_ENTERING_WORLD")
CVARS.nameplateShowFriends = "0"               -- he pressed V / Shift-V
Tick(0.2); Tick(1); Tick(1); Tick(0.2)
check(CVARS.nameplateShowFriends == "1", "arena: friendly plates switched back on")
INSTANCE = "none"
FireEvent("PLAYER_ENTERING_WORLD")
RAID = 0
UNITS.raid1, UNITS.raid2 = nil, nil

CHAT = {}
cp("debug")
local dbg = table.concat(CHAT, "\n")
check(dbg:find("friendly plate 'Elcemento %(%*%)' bar 0.00 0.00 1.00 %-> teammate widget %(party1%)"), "debug: teammate plate and why")
check(dbg:find("friendly plate 'Randomfriend' bar 0.00 0.00 1.00 %-> not a party member"), "debug: other friendly plates and why not")
check(dbg:find("party: party1=Elcemento"), "debug: party names")

print(string.format("%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
