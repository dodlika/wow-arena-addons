-- ArenaFrames 3.0: Blizzard-style player / target / focus frames (end of ArenaFrames.lua)
dofile("tests/harness.lua")
UNITS.player = { name = "Me", player = true, guid = "0xME", class = "ROGUE", hp = 15000, maxhp = 20000,
  ptype = 3, power = 85, maxpower = 100, reaction = 5 }
LoadAddon("ArenaFrames")

local pass, fail = 0, 0
local function check(cond, label)
  if cond then pass = pass + 1 else fail = fail + 1; print("FAIL: " .. label) end
end
local function cmd(s) SlashCmdList.ARENAFRAMES(s) end
local function near(a, b) return a and b and math.abs(a - b) < 0.011 end
local function color(t, r, g, b) return t and near(t[1], r) and near(t[2], g) and near(t[3], b) end
local function shownIcons(list)
  local out = {}
  for _, b in ipairs(list) do if b._shown then table.insert(out, b) end end
  return out
end
local function textColor(fs) return { fs:GetTextColor() } end

FocusFrame._userPlaced = true                  -- owner once dragged Blizzard's focus frame
FireEvent("ADDON_LOADED", "ArenaFrames")
FireEvent("PLAYER_ENTERING_WORLD")
local P, T, F = ArenaFramesPlayer, ArenaFramesTarget, ArenaFramesFocus

------------------------------------------------------------- setup ---------
check(P and T and F, "player, target and focus frames created")
check(T._protected and P:GetAttribute("unit") == "player" and T:GetAttribute("unit") == "target"
  and F:GetAttribute("unit") == "focus", "secure unit buttons")
-- clicks (regression 3.0: the owner lost the right-click menu with Inspect)
SecureClick(T, "LeftButton")
check(TARGETED == "target", "left click targets")
MODIFIER = "shift"; SecureClick(T, "LeftButton"); MODIFIER = nil
check(FOCUSED == "target", "shift + left click focuses")
for unit, f in pairs({ player = P, target = T, focus = F }) do
  OPENED_MENU = nil
  SecureClick(f, "RightButton")
  local blizz = ({ player = "PlayerFrame", target = "TargetFrame", focus = "FocusFrame" })[unit]
  check(OPENED_MENU == blizz .. "DropDown", unit .. ": right click opens Blizzard's own menu via " .. blizz)
  check(_G[blizz]._all == f and #_G[blizz]._points == 0, unit .. ": hidden " .. blizz .. " covers our frame (menu opens there)")
end
check(rawget(P, "menu") == nil and #MENUS == 0, "no menu opened from addon code (that would taint Set Focus)")
check(not FocusFrame._userPlaced, "a user-placed Blizzard focus frame is released so the client won't move it back")
FocusFrame_SetSmallSize(true)                  -- Interface Options: "Larger Focus Frame" toggled
check(FocusFrame._all == F and #FocusFrame._points == 0, "Blizzard re-anchoring the focus frame is undone")
check(IsUnitWatched(P) and IsUnitWatched(T) and IsUnitWatched(F), "all three use the unit watch")
check(T._w == 232 and T._h == 100, "Blizzard's 232x100 frame")
check(T.art._tex == "Interface\\TargetingFrame\\UI-TargetingFrame" and T.art._coords[1] == 0.09375,
  "Blizzard frame art on target / focus")
check(P.isParty and P.art == nil, "3.5: you are a party-style box (no Blizzard-style player frame)")
for _, b in ipairs({ PlayerFrame, TargetFrame, FocusFrame }) do
  check(not b._shown and b._parent ~= UIParent and next(b._events) == nil, b:GetName() .. " hidden + silenced")
end
check(PetFrame._parent == UIParent, "pet frame kept (moved out of the hidden PlayerFrame)")
check(ComboFrame._parent == T and ComboFrame._points[1][2] == T and ComboFrame._events.PLAYER_TARGET_CHANGED,
  "Blizzard's combo points live on our target frame and keep updating themselves")
check(T._drag == nil and P._drag == nil, "no drag outside test mode: a left click always targets")
check(ComboFrame._strata == "MEDIUM", "combo points kept above the frame art (strata reset after SetParent)")

Tick(0.2)
check(P._shown and not T._shown and not F._shown, "player shown, no target / focus yet")

------------------------------------------------------------- player --------
check(P.name._text == "Me" and P.hp._val == 15000 and color(P.hp._bar, 1, 0.96, 0.41), "your box: name, class colored health")
check(P.power._shown and P.power._val == 85 and color(P.power._bar, 1, 0.9, 0.1), "your box shows your energy")
check(P._alpha == 1, "never faded as out of range")

------------------------------------------------------------- target --------
UNITS.target = { name = "Frostbolt", player = true, guid = "0xT1", class = "MAGE", hp = 9000, maxhp = 18000,
  ptype = 0, power = 15000, maxpower = 30000, reaction = 2, level = 80 }
SOUNDS = {}
DropDownList1._shown, UIDROPDOWNMENU_OPEN_MENU = true, TargetFrameDropDown
FireEvent("PLAYER_TARGET_CHANGED")
check(CLOSED_MENUS == 1, "an open target menu closes when the target changes")
check(T.name._text == "Frostbolt", "drawn on PLAYER_TARGET_CHANGED already, before the unit watch shows it")
check(SOUNDS[1] == "igCreatureAggroSelect", "target sound like Blizzard's frame")
Tick(0.2)
check(T._shown and T.hpText._text == "50%" and T.level._text == 80, "target: health %, level")
check(color(T.hp._bar, 0.41, 0.80, 0.94), "class colored health")
check(color(T.power._bar, 0.25, 0.45, 1), "mana bar")
check(color(T.nameBg._vc, 1, 0, 0), "name background: hostile red (UnitSelectionColor)")
check(T.classIcon._shown and T.classIcon._tex:find("UI%-Classes%-Circles") and not T.round._shown, "round class icon by default")
check(T.powerText._text == "", "no power text on the target")
T:GetScript("OnEnter")(T)
check(TOOLTIP_UNIT == "target", "hover shows Blizzard's unit tooltip")
T:GetScript("OnLeave")(T)
check(TOOLTIP_UNIT == nil, "tooltip hides on leave")
check(color(textColor(T.level), 1, 1, 0), "level of an enemy: difficulty color")

------------------------------------------------------------- CC portrait ---
local function setAuras(list) UNITS.target.auras = list; FireEvent("UNIT_AURA", "target"); Tick(0.2) end
setAuras({ { name = "Kidney Shot", id = 8643, harmful = true, dur = 6, expires = NOW + 5, caster = "player" } })
check(T.round._shown and T.round._tex == "round:Interface\\Icons\\KidneyShot" and not T.classIcon._shown,
  "stunned -> round Kidney Shot icon in the portrait")
check(T.ccText._text == "5.0" and color(textColor(T.ccText), 1, 0.15, 0.15), "countdown in stun red")
setAuras({
  { name = "Kidney Shot", id = 8643, harmful = true, dur = 6, expires = NOW + 5, caster = "player" },
  { name = "Blind", id = 2094, harmful = true, dur = 10, expires = NOW + 9, caster = "raid2" },
})
check(T.round._tex:find("KidneyShot"), "stun beats Blind even if Blind lasts longer")
setAuras({
  { name = "Kidney Shot", id = 8643, harmful = true, dur = 6, expires = NOW + 5, caster = "player" },
  { name = "Divine Shield", id = 642, harmful = false, dur = 12, expires = NOW + 11, caster = "target" },
})
check(T.round._tex:find("DivineShield") and color(textColor(T.ccText), 1, 0.82, 0), "immunity beats everything (gold)")
setAuras({ { name = "Frost Nova", id = 42917, harmful = true, dur = 8, expires = NOW + 8 } })
check(T.classIcon._shown and not T.round._shown, "roots don't take the portrait")
setAuras({
  { name = "Sap", id = 51724, harmful = true, dur = 10, expires = NOW + 3, caster = "player" },
  { name = "Polymorph", id = 12826, harmful = true, dur = 10, expires = NOW + 8 },
})
check(T.round._tex:find("Polymorph") and T.ccText._text == "8.0", "same priority: the longer one wins")
NOW = NOW + 8.5; Tick(0.2)
check(T.classIcon._shown and not T.round._shown and T.ccText._text == "", "CC over -> class icon again")

-- interrupt lockout
setAuras({})
FireEvent("COMBAT_LOG_EVENT_UNFILTERED", NOW, "SPELL_INTERRUPT", "0xME", "Me", 0x511, "0xT1", "Frostbolt", 0x548,
  1766, "Kick", 1, 42842, "Frostbolt", 16)
Tick(0.2)
check(T.round._tex:find("Kick") and T.ccText._text == "5.0" and color(textColor(T.ccText), 0.3, 0.6, 1),
  "Kick -> 5 s lockout on the portrait (blue)")
setAuras({ { name = "Cheap Shot", id = 1833, harmful = true, dur = 4, expires = NOW + 4, caster = "player" } })
check(T.round._tex:find("CheapShot"), "stun beats the lockout")
setAuras({})
check(T.round._tex:find("Kick"), "lockout back once the stun is gone")
NOW = NOW + 5.1; Tick(0.2)
check(T.classIcon._shown, "lockout over")

-- CC on yourself
UNITS.player.auras = { { name = "Blind", id = 2094, harmful = true, dur = 10, expires = NOW + 7 } }
FireEvent("UNIT_AURA", "player"); Tick(0.2)
check(P.cc._shown and P.cc.icon._tex:find("Blind") and P.cc.text._text == "7.0", "your own CC in your box")
UNITS.player.auras = nil
FireEvent("UNIT_AURA", "player"); Tick(0.2)
check(not P.cc._shown, "gone again")

------------------------------------------------------------- aura rows -----
-- 3.2 (owner: "target frame has no buffs while he has"): all buffs and debuffs, Blizzard style
setAuras({
  { name = "Rupture", id = 48672, harmful = true, dur = 16, expires = NOW + 14, caster = "player" },
  { name = "Deadly Poison IX", id = 57970, harmful = true, dur = 12, expires = NOW + 9, caster = "player",
    count = 5, dtype = "Poison" },
  { name = "Corruption", id = 47813, harmful = true, dur = 18, expires = NOW + 10, caster = "raid1", dtype = "Magic" },
  { name = "Arcane Intellect", id = 42995, harmful = false, dur = 3600, expires = NOW + 3000, caster = "arena2" },
  { name = "Cloak of Shadows", id = 31224, harmful = false, dur = 5, expires = NOW + 4, caster = "target" },
})
local deb, buf = shownIcons(T.debuffs), shownIcons(T.buffs)
check(#deb == 3 and #buf == 2, "every debuff and buff is shown")
check(deb[1].icon._tex:find("Rupture") and deb[2].icon._tex:find("DeadlyPoison") and deb[3].icon._tex:find("Corruption"),
  "your debuffs first, then others'")
check(deb[1].size == 21 and deb[3].size == 17, "yours large, others small (Blizzard sizes)")
check(deb[2].count._text == 5 and deb[1].text._text == "14" and deb[3].text._text == "", "stacks; timers on the large ones")
check(color(deb[2]._bdBorder, 0, 0.6, 0) and color(deb[3]._bdBorder, 0.2, 0.6, 1), "debuff borders by type (poison, magic)")
check(buf[1].icon._tex:find("CloakofShadows") and buf[1].size == 21 and color(buf[1]._bdBorder, 1, 0.82, 0),
  "important buff first, large, gold border")
check(buf[2].icon._tex:find("ArcaneIntellect") and buf[2].size == 17, "other buffs small")
check(deb[1].y == -68 and deb[1].x == 5 and deb[2].x == 28 and deb[3].x == 51, "enemy: debuffs in the first row")
check(buf[1].y == -92 and buf[1].x == 5, "buffs on the next row")
check(T.cast.y == -119, "cast bar moves under the last row")

local many = {}
for k = 1, 7 do
  table.insert(many, { name = "Dot" .. k, id = 90000 + k, harmful = true, dur = 10, expires = NOW + 9, caster = "player" })
end
setAuras(many)
deb = shownIcons(T.debuffs)
check(deb[5].y == -68 and deb[6].x == 5 and deb[6].y == -92, "rows wrap at Blizzard's width (5 large icons)")
check(T.cast.y == -92 - 21 - 6, "cast bar under the second row")

UNITS.target.reaction = 5
setAuras({
  { name = "Rupture", id = 48672, harmful = true, dur = 16, expires = NOW + 14, caster = "player" },
  { name = "Arcane Intellect", id = 42995, harmful = false, dur = 3600, expires = NOW + 3000, caster = "player" },
})
check(shownIcons(T.buffs)[1].y == -68 and shownIcons(T.debuffs)[1].y == -92, "friendly: buffs first")
UNITS.target.reaction = 2
setAuras({})
check(T.cast.y == -93, "no auras: cast bar in Blizzard's spot under the frame")

------------------------------------------------------------- cast bar ------
local CB = T.cast
local function castTick(t) NOW = NOW + t; CB:GetScript("OnUpdate")(CB, t) end
UNITS.target.cast = { name = "Polymorph", start = NOW, endt = NOW + 1.5 }
FireEvent("UNIT_SPELLCAST_START", "target")
check(CB._shown and CB.label._text == "Polymorph" and color(CB.bar._bar, 1, 0.7, 0), "cast bar (Blizzard yellow)")
castTick(0.6)
check(near(CB.bar._val, 0.4) and CB.time._text == "0.9", "progress + time left")
UNITS.target.cast = nil
FireEvent("UNIT_SPELLCAST_INTERRUPTED", "target")
check(CB.label._text == "Interrupted" and color(CB.bar._bar, 1, 0, 0), "interrupted -> red")
FireEvent("UNIT_SPELLCAST_STOP", "target")
check(CB._shown, "the STOP after an interrupt doesn't hide it early")
castTick(1.1)
check(not CB._shown, "gone after 1 s")
UNITS.target.cast = { name = "Divine Shield", start = NOW, endt = NOW + 1, notInt = true }
FireEvent("UNIT_SPELLCAST_START", "target")
check(color(CB.bar._bar, 0.6, 0.6, 0.6) and CB.label._text:find("no kick"), "uninterruptible: grey")
UNITS.target.cast = { name = "Mind Flay", start = NOW, endt = NOW + 3, channel = true }
FireEvent("UNIT_SPELLCAST_CHANNEL_START", "target")
castTick(1)
check(near(CB.bar._val, 2 / 3) and color(CB.bar._bar, 0, 1, 0), "channel drains, green")
UNITS.target.cast = nil
FireEvent("UNIT_SPELLCAST_CHANNEL_STOP", "target")
check(not CB._shown, "channel stop hides")
-- regression (review): switching target right after an interrupt must not show the old "Interrupted"
UNITS.target.cast = { name = "Fear", start = NOW, endt = NOW + 1.5 }
FireEvent("UNIT_SPELLCAST_START", "target")
UNITS.target.cast = nil
FireEvent("UNIT_SPELLCAST_INTERRUPTED", "target")
UNITS.target = { name = "Healer", player = true, guid = "0xT3", class = "PRIEST", hp = 100, maxhp = 100, reaction = 2 }
FireEvent("PLAYER_TARGET_CHANGED")
check(not CB._shown, "new target: the previous target's Interrupted bar is gone")

------------------------------------------------------------- sap icon ------
UNITS.target = { name = "Sappy", player = true, guid = "0xS1", class = "PALADIN", hp = 100, maxhp = 100, reaction = 2 }
FireEvent("PLAYER_TARGET_CHANGED"); Tick(0.2)
check(T.sap._shown and T.sap.icon._tex == "Interface\\Icons\\Ability_Sap", "enemy player out of combat -> Sap icon")
UNITS.target.combat = true; Tick(0.2)
check(not T.sap._shown, "in combat (API) -> no Sap icon")
UNITS.target.combat = false
CombatPlates_InCombat = function(u) return u == "target" end
Tick(0.2)
check(not T.sap._shown, "CombatPlates says in combat (combat log) -> no Sap icon")
CombatPlates_InCombat = nil
UNITS.target.reaction = 5; Tick(0.2)
check(not T.sap._shown, "friendly -> no Sap icon")
UNITS.target = { name = "Boar", player = false, guid = "0xN1", hp = 50, maxhp = 100, reaction = 2 }
FireEvent("PLAYER_TARGET_CHANGED"); Tick(0.2)
check(not T.sap._shown, "NPC -> no Sap icon")
check(P.sap == nil and F.sap, "Sap icon on target and focus, not on the player")
-- regression (3.0 in game: never showed): enemy-faction player who isn't attackable right
-- now (not PvP flagged) still counts, like the nameplate icon
UNITS.target = { name = "Unflagged", player = true, guid = "0xS2", class = "MAGE", hp = 1, maxhp = 1,
  reaction = 2, attackable = false }
FireEvent("PLAYER_TARGET_CHANGED"); Tick(0.2)
check(T.sap._shown, "enemy faction, not attackable (unflagged) -> Sap icon")
-- same faction duel opponent: not an enemy, but attackable during the duel
UNITS.target = { name = "Dueler", player = true, guid = "0xS3", class = "MAGE", hp = 1, maxhp = 1,
  reaction = 5, attackable = true }
FireEvent("PLAYER_TARGET_CHANGED"); Tick(0.2)
check(T.sap._shown, "duel opponent (same faction, attackable) -> Sap icon")
UNITS.focus = { name = "FocusSap", player = true, guid = "0xS4", class = "DRUID", hp = 1, maxhp = 1, reaction = 2 }
FireEvent("PLAYER_FOCUS_CHANGED"); Tick(0.2)
check(F.sap._shown, "focus: Sap icon too")
CHAT = {}
cmd("debug")
check(table.concat(CHAT, "\n"):find("sappable: yes %(player yes, enemy yes, attackable yes"), "debug lists every Sap check")
UNITS.focus = nil
FireEvent("PLAYER_FOCUS_CHANGED")

------------------------------------------------------------- NPCs ----------
UNITS.target = { name = "Training Dummy", player = false, guid = "0xN2", hp = 50, maxhp = 100, reaction = 4,
  classification = "elite", level = -1 }
PORTRAIT_CALLS = 0
FireEvent("PLAYER_TARGET_CHANGED"); Tick(0.2); Tick(0.2); Tick(0.2)
check(T.round._tex == "portrait:target" and T.round._shown and PORTRAIT_CALLS == 1,
  "NPC: round Blizzard portrait, drawn once (not every tick)")
FireEvent("UNIT_PORTRAIT_UPDATE", "target"); Tick(0.2)
check(PORTRAIT_CALLS == 2, "redrawn on UNIT_PORTRAIT_UPDATE")
check(T.art._tex:find("Elite") and color(T.hp._bar, 0.9, 0.8, 0.2), "elite art + reaction color")
check(T.skull._shown and not T.level._shown, "?? level -> skull")
UNITS.target = { name = "Guard", player = false, guid = "0xN3", hp = 50, maxhp = 100, reaction = 5, level = 70 }
FireEvent("PLAYER_TARGET_CHANGED"); Tick(0.2)
check(color(textColor(T.level), 1, 0.82, 0), "friendly unit: Blizzard's gold level, no difficulty color")
UNITS.target = { name = "Corpse", player = true, guid = "0xT2", class = "PRIEST", hp = 0, maxhp = 100, dead = true }
FireEvent("PLAYER_TARGET_CHANGED"); Tick(0.2)
check(T.hpText._text == "DEAD" and T.art._tex == "Interface\\TargetingFrame\\UI-TargetingFrame", "dead player, normal art")
UNITS.target.raidIcon = 8; Tick(0.2)
check(T.raidIcon._shown and T.raidIcon._raid == 8, "raid target icon")

------------------------------------------------------------- focus ---------
UNITS.focus = { name = "Healer", player = true, guid = "0xF1", class = "DRUID", hp = 100, maxhp = 100,
  ptype = 0, power = 50, maxpower = 100, reaction = 2 }
FireEvent("PLAYER_FOCUS_CHANGED"); Tick(0.2)
check(F._shown and F.name._text == "Healer", "focus frame")
UNITS.focus.cast = { name = "Cyclone", start = NOW, endt = NOW + 1.5 }
FireEvent("UNIT_SPELLCAST_START", "focus")
check(F.cast._shown and not T.cast._shown, "focus has its own cast bar")

------------------------------------------------------------- combat --------
COMBAT = true
UNITS.target = nil
SOUNDS = {}
DropDownList1._shown, UIDROPDOWNMENU_OPEN_MENU = true, PlayerFrameDropDown
FireEvent("PLAYER_TARGET_CHANGED")
check(CLOSED_MENUS == 1, "other menus (e.g. the player menu) stay open")
check(SOUNDS[1] == "INTERFACESOUND_LOSTTARGETUNIT", "lost target sound")
Tick(0.2)
check(not T._shown, "target lost in combat -> hidden by the unit watch")
UNITS.target = { name = "Frostbolt", player = true, guid = "0xT1", class = "MAGE", hp = 1, maxhp = 2, reaction = 2 }
local ok, err = pcall(FireEvent, "PLAYER_TARGET_CHANGED")
local ok2, err2 = pcall(Tick, 0.2)
check(ok and ok2 and T._shown, "new target in combat: no blocked actions " .. tostring(err) .. tostring(err2))
CHAT = {}
cmd("unlock")
check(CHAT[1] and CHAT[1]:find("in combat") and not T.fake, "can't unlock in combat")
cmd("ufscale 1.5")
check(T._scale ~= 1.5, "scale change waits for combat to end")
COMBAT = false
FireEvent("PLAYER_REGEN_ENABLED")
check(FLASH == false, "and stops after combat")
check(T._scale == 1.5 and near(T._points[1][4], 250 / 1.5), "applied after combat; position kept on screen (offset / scale)")

------------------------------------------------------------- test mode -----
UNITS.target, UNITS.focus = nil, nil
FireEvent("PLAYER_TARGET_CHANGED"); FireEvent("PLAYER_FOCUS_CHANGED")
Tick(0.2)
cmd("unlock")
Tick(0.2)
check(T._shown and F._shown and T.name._text == "Kisame" and F.name._text == "Paracetomol", "unlock shows fake target + focus")
check(T._drag and T._drag[1] == "LeftButton" and P._drag, "frames draggable while unlocked")
check(T.round._tex:find("KidneyShot") and P.cc.icon._tex:find("Blind"), "test: CC previews on target and your box")
check(ComboFrame._shown and _G.ComboPoint4Highlight._alpha == 1 and _G.ComboPoint5Highlight._alpha == 0, "test: 4 combo points")
check(F.cast._shown and #shownIcons(T.debuffs) == 3 and #shownIcons(T.buffs) == 3 and T.sap._shown, "test: cast bar, auras, Sap icon")
NOW = NOW + 20; Tick(0.2)
check(T.round._shown and #shownIcons(T.debuffs) == 3, "test preview stays up (fake auras restart)")
T:GetScript("OnDragStart")(T)
T._points = { { "TOPLEFT", UIParent, "TOPLEFT", 200, -100 } }
T:GetScript("OnDragStop")(T)
check(ArenaFramesDB.ufpos_target[2] == 300 and ArenaFramesDB.ufpos_target[3] == -150,
  "drag saves the position in screen units (scale 1.5)")
CHAT = {}
cmd("debug")
check(table.concat(CHAT, "\n"):find("portrait: stun"), "debug explains the portrait")
COMBO_UPDATES = 0
_G.ComboPoint4Highlight._alpha = 1
FireEvent("PLAYER_REGEN_DISABLED")             -- combat starts while unlocked
check(_G.ComboPoint4Highlight._alpha == 0 and COMBO_FRAME_LAST_NUM_POINTS == 0, "fake combo points cleared, Blizzard redraws")
check(FLASH == true, "Screen Edge Flash still starts at combat (Blizzard's PlayerFrame did it)")
check(IsUnitWatched(T) and not T.fake and T._drag == nil and COMBO_UPDATES == 1, "entering combat locks again")
Tick(0.2)
check(not T._shown and not F._shown and P._shown, "back to real units")
cmd("lock")
check(CHAT[#CHAT]:find("already locked"), "lock when already locked")

------------------------------------------------------------- slash ---------
CHAT = {}
cmd("")
check(table.concat(CHAT, "\n"):find("player/target/focus/party frames: on"), "help shows the frames' state")
cmd("reset")
check(ArenaFramesDB.ufpos_target == nil and ArenaFramesDB.ufscale == 1 and T._scale == 1, "reset")
cmd("uf off"); check(ArenaFramesDB.uf == false, "uf off (needs reload)")

print(string.format("%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
