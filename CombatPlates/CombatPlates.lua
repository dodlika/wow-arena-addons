--[[
  CombatPlates 1.7  -  WoW 3.3.5a (Warmane-safe, no client patches)

  Puts an icon on enemy nameplates based on whether that unit is in combat.
  Built for rogues: know at a glance who you can still Sap.

  A unit counts as IN combat if ANY of these says so:
    * the game API (UnitAffectingCombat) for plates we can tie to a unit:
      arena1-5 (also when ArenaNumbers swapped the names for 1/2/3), target,
      focus, mouseover, party/raid targets
    * the combat log: the player dealt or took damage, debuffed or got debuffed
      by the other side (or you), or healed someone in combat, within 6 seconds
    * the plate's name color is red
  Each source alone misses cases on some servers, together they cover them.

  Commands:
    /cplates                    help + current settings
    /cplates mode combat        swords icon on enemies IN combat (default)
    /cplates mode sap           Sap icon on enemies OUT of combat (sappable)
    /cplates mode both          swords when in combat, Sap icon when not
    /cplates size 20            icon size, 10-64
    /cplates pos left|right|top where the icon sits on the plate
    /cplates offset 0 0         nudge x y
    /cplates test               toggle: show icons on every enemy plate (for positioning)
    /cplates debug              print what each source says for every visible enemy plate
    /cplates party on|off       teammates' plates (party1-4) -> class icon + name + cooldowns
    /cplates friends on|off     in arena, turn friendly plates on (and back off after)
    /cplates partysize 1.5      size of the teammates' plate widget, 0.5-3
    /cplates totems on|off      totems, Succubus and Felhunter plates -> a big spell icon (1.6)
    /cplates totemsize 36       size of that icon, 16-64
    /cplates auras on|off       CC, immunities and big buffs above enemy plates (1.7)
    /cplates aurasize 26        size of those icons, 14-48
    /cplates reset              defaults
]]

local ADDON = "CombatPlates"
local BORDER = [[Interface\Tooltips\Nameplate-Border]]
local SWORDS = [[Interface\CharacterFrame\UI-StateIcon]]
local SAP_FALLBACK = [[Interface\Icons\Ability_Sap]]
local DEFAULTS = { mode = "combat", size = 20, pos = "left", x = 0, y = 0, party = true, friends = true,
  partysize = 1.5, totems = true, totemsize = 36, auras = true, aurasize = 26 }
local CLASS_CIRCLES = [[Interface\TargetingFrame\UI-Classes-Circles]]
local CLASS_TCOORDS = {      -- same as Blizzard's CLASS_ICON_TCOORDS
  WARRIOR = { 0, 0.25, 0, 0.25 }, MAGE = { 0.25, 0.49609375, 0, 0.25 },
  ROGUE = { 0.49609375, 0.7421875, 0, 0.25 }, DRUID = { 0.7421875, 0.98828125, 0, 0.25 },
  HUNTER = { 0, 0.25, 0.25, 0.5 }, SHAMAN = { 0.25, 0.49609375, 0.25, 0.5 },
  PRIEST = { 0.49609375, 0.7421875, 0.25, 0.5 }, WARLOCK = { 0.7421875, 0.98828125, 0.25, 0.5 },
  PALADIN = { 0, 0.25, 0.5, 0.75 }, DEATHKNIGHT = { 0.25, 0.49609375, 0.5, 0.75 },
}
local FLAT = [[Interface\Buttons\WHITE8X8]]
local FONT = [[Fonts\FRIZQT__.TTF]]
local PARTY_CDS = 3          -- cooldown icons on a teammate's plate
local FRIEND_CVARS = { nameplateShowFriends = "1", nameplateShowFriendlyPets = "0",
  nameplateShowFriendlyGuardians = "0", nameplateShowFriendlyTotems = "0" }
local UPDATE_INTERVAL = 0.1
local COMBAT_WINDOW = 6     -- seconds after a player's last combat action we still count them in combat

local band = bit.band
local AFFILIATION_MINE, TYPE_PLAYER, REACTION_HOSTILE = 0x00000001, 0x00000400, 0x00000040
local TYPE_NOT_PLAYER = 0x00000800 + 0x00001000 + 0x00002000 + 0x00004000  -- NPC, pet, guardian, object (totems)
local SAP_IDS = { [6770] = true, [2070] = true, [11297] = true, [51724] = true }  -- Sap doesn't start combat

local db, SAP
local plates = {}                                -- [nameplate frame] = data
local seen = setmetatable({}, { __mode = "k" })  -- WorldFrame children already checked
local numChildren = 0
local testMode = false
local inArena = false
local tokenByName = {}                           -- [player name] = unit token
local lastCombat = {}                            -- [player name] = GetTime() of last combat action
local playerNames, npcNames, learned = {}, {}, 0  -- names the combat log showed as player / not

local BASE_TOKENS = { "target", "focus", "mouseover", "targettarget", "focustarget",
  "pettarget", "arena1", "arena2", "arena3", "arena4", "arena5" }
local PARTY_TOKENS, RAID_TOKENS = {}, {}
for i = 1, 4 do PARTY_TOKENS[i] = "party" .. i .. "target" end
for i = 1, 40 do RAID_TOKENS[i] = "raid" .. i .. "target" end

-- 1.6 (owner's screenshot: "icons like this on the totems, also on succubus and felhunter"): those
-- plates become their spell icon. Totems by plate name (rank numerals stripped); warlock demons have
-- random names, so their family is learned from UnitCreatureFamily (arenapet1-5, target, focus,
-- mouseover) and from the spells they cast in the combat log.
local TOTEM_IDS = { 2484, 5730, 8071, 8075, 8143, 2062, 3599, 8190, 8227, 8181, 2894, 30706, 5394, 5675,
  16190, 8170, 8184, 8177, 8512, 3738, 10595, 6495 }
local PETS = {   -- family -> summon spell (icon), spells only that demon casts
  Succubus = { 712, { 6358, 7814, 6360, 7870 } },
  Felhunter = { 691, { 19647, 19244, 19505, 54049, 54424 } },
}
local PET_TOKENS = { "arenapet1", "arenapet2", "arenapet3", "arenapet4", "arenapet5", "target", "focus", "mouseover" }
local iconByTotem, petIcon, petBySpell, petByName = {}, {}, {}, {}
-- 1.7 (owner: "I landed Fear and the plate showed nothing"): CC / immunities / big buffs above enemy
-- plates. Plates tied to a unit (arena1-5, target, focus, mouseover...) read UnitAura (with timers);
-- other enemy players' plates use what the combat log saw applied / removed on that name (no timer).
-- What counts: ArenaFrames' tables (CC_PRIORITY by DR category, IMMUNE, BUFFS), so it needs ArenaFrames.
local AURA_MAX = 4
local logAuras = {}        -- [player name] = { [spellId] = { icon, prio, kind, t } }

local function Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cffffd200CombatPlates:|r " .. msg)
end

---------------------------------------------------------------- detection --

-- A default 3.3.5 plate is an unnamed WorldFrame child whose 2nd region is the
-- plate border texture. Some nameplate addons (e.g. Kui) blank that texture, so
-- fall back to the plate's layout: 6 textures, name + level FontStrings, and a
-- health bar + cast bar as its first two children.
local function IsNameplate(frame)
  if frame:GetName() then return false end
  local regions = { frame:GetRegions() }
  local border = regions[2]
  if border and border:GetObjectType() == "Texture" and border:GetTexture() == BORDER then
    return true
  end
  if #regions < 11 then return false end
  for i = 1, 6 do
    if regions[i]:GetObjectType() ~= "Texture" then return false end
  end
  if regions[7]:GetObjectType() ~= "FontString" or regions[8]:GetObjectType() ~= "FontString" then
    return false
  end
  local hp, cb = frame:GetChildren()
  return (hp and cb and hp:GetObjectType() == "StatusBar"
    and cb:GetObjectType() == "StatusBar") and true or false
end

------------------------------------------------------------------- layout --

local function ApplyLayout(d)
  local h = d.holder
  h:ClearAllPoints()
  h:SetWidth(db.size)
  h:SetHeight(db.size)
  if db.pos == "right" then
    h:SetPoint("LEFT", d.hp, "RIGHT", 22 + db.x, db.y)   -- clears the level text
  elseif db.pos == "top" then
    h:SetPoint("BOTTOM", d.hp, "TOP", db.x, 16 + db.y)   -- above the name
  else
    h:SetPoint("RIGHT", d.hp, "LEFT", -4 + db.x, db.y)
  end
end

local function ApplyLayoutAll()
  for _, d in pairs(plates) do ApplyLayout(d) end
end

local function SetupPlate(plate)
  local hp = plate:GetChildren()
  local nameText = select(7, plate:GetRegions())

  local holder = CreateFrame("Frame", nil, plate)
  holder:SetFrameLevel(math.min(plate:GetFrameLevel() + 5, 125))
  local tex = holder:CreateTexture(nil, "OVERLAY")
  tex:SetAllPoints(holder)
  holder:Hide()

  local d = { plate = plate, hp = hp, name = nameText, holder = holder, tex = tex }
  -- the plate's own look, so a teammate's plate can be blanked and given back (party plates)
  d.regions, d.alphas = { plate:GetRegions() }, {}
  for i, r in ipairs(d.regions) do d.alphas[i] = r:GetAlpha() end
  d.cb = select(2, plate:GetChildren())
  d.hpA, d.cbA = hp:GetAlpha(), d.cb and d.cb:GetAlpha() or 1
  plates[plate] = d
  ApplyLayout(d)

  -- plates get recycled for other units; never let an old icon flash on a new one
  plate:HookScript("OnHide", function()
    holder:Hide()
    if d.auraW then d.auraW:Hide() end
    if d.restore then d.restore(d) end
  end)
end

---------------------------------------------------------- unit token map --

local function AddToken(unit)
  if UnitExists(unit) and UnitIsPlayer(unit) then  -- player names are unique, NPC names aren't
    local name = UnitName(unit)
    if name and not tokenByName[name] then tokenByName[name] = unit end
  end
end

local function BuildTokens()
  wipe(tokenByName)
  for i = 1, #BASE_TOKENS do AddToken(BASE_TOKENS[i]) end
  local raid = GetNumRaidMembers()
  if raid > 0 then
    for i = 1, raid do AddToken(RAID_TOKENS[i]) end
  else
    for i = 1, GetNumPartyMembers() do AddToken(PARTY_TOKENS[i]) end
  end
end

-- Match a plate to arena1-5 by max HP, for plates whose name was rewritten.
-- Only trusted when it's unambiguous.
local function ArenaByHealth(maxHP, curHP)
  local match, count, exact = nil, 0, nil
  for i = 1, 5 do
    local u = "arena" .. i
    if UnitExists(u) and UnitHealthMax(u) == maxHP then
      count = count + 1
      match = u
      if UnitHealth(u) == curHP then
        if exact == nil then exact = u else exact = false end
      end
    end
  end
  if count == 1 then return match end
  return exact or nil
end

local function ArenaUnitForPlate(d, text)
  local n = tonumber(text)                         -- ArenaNumbers turns names into 1-5
  if n and n >= 1 and n <= 5 and UnitExists("arena" .. n) then return "arena" .. n end
  if tokenByName[text] then return tokenByName[text] end

  local _, maxHP = d.hp:GetMinMaxValues()
  if not maxHP or maxHP <= 1 then return nil end
  for i = 1, 5 do                                  -- enemy pets: name AND max HP must match
    local u = "arenapet" .. i
    if UnitExists(u) and UnitName(u) == text and UnitHealthMax(u) == maxHP then return u end
  end
  return ArenaByHealth(maxHP, d.hp:GetValue())
end

---------------------------------------------------------- combat log watch --

local DAMAGE_EVENTS = {
  SWING_DAMAGE = true, SWING_MISSED = true, RANGE_DAMAGE = true, RANGE_MISSED = true,
  SPELL_DAMAGE = true, SPELL_MISSED = true, SPELL_PERIODIC_DAMAGE = true, SPELL_PERIODIC_MISSED = true,
  DAMAGE_SHIELD = true, DAMAGE_SHIELD_MISSED = true, DAMAGE_SPLIT = true,
  SPELL_INTERRUPT = true, SPELL_STOLEN = true, SPELL_DRAIN = true, SPELL_LEECH = true,
  SPELL_PERIODIC_DRAIN = true, SPELL_PERIODIC_LEECH = true,
}
local AURA_EVENTS = { SPELL_AURA_APPLIED = true, SPELL_AURA_REFRESH = true, SPELL_AURA_APPLIED_DOSE = true }
local HEAL_EVENTS = { SPELL_HEAL = true, SPELL_PERIODIC_HEAL = true }

local function ShortName(name)
  return name and name:match("^[^%-]+")            -- drop "-Realm"
end

local function Has(flags, bitmask)
  return flags and band(flags, bitmask) ~= 0 or false
end

local function Mark(name)
  name = ShortName(name)
  if name then lastCombat[name] = GetTime() end
end

local function CombatAge(name)
  local t = name and lastCombat[name]
  if t then return GetTime() - t end
end

local function RecentlyInCombat(name)
  local age = CombatAge(name)
  return age ~= nil and age < COMBAT_WINDOW
end

-- Only players are tracked (their names are unique). Reaction flags aren't
-- trusted for damage, so duels (opponent may still look "friendly") count too.
-- Remember which names belong to players and which to pets, totems, ghouls, guardians...
-- what an aura is for the plate icons: kind (DR category / "immune" / "buff") and priority, or nil
local function AuraKind(spellId, name, harmful)
  local A, NS = ArenaFrames_Auras, ArenaFrames_NS
  if not A then return nil end
  if harmful then
    local cat = NS and NS.DRCategory and NS.DRCategory(spellId, name)
    local prio = cat and A.CC_PRIORITY[cat]
    if prio then return cat, prio end
  elseif A.IMMUNE[spellId] then
    return "immune", A.CC_PRIORITY.immune or 100
  elseif A.BUFFS[spellId] then
    return "buff", 10
  end
end

local function LearnName(name, flags)
  name = ShortName(name)
  if not name or not flags then return end
  local isPlayer = Has(flags, TYPE_PLAYER)
  if not isPlayer and not Has(flags, TYPE_NOT_PLAYER) then return end
  local list = isPlayer and playerNames or npcNames
  if list[name] then return end
  learned = learned + 1
  if learned > 3000 then wipe(playerNames); wipe(npcNames); learned = 0 end  -- battlegrounds: keep it small
  list[name] = true
end

local function OnCombatLog(_, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellId, spellName, _,
    auraType)
  LearnName(srcName, srcFlags)
  local fam = spellName and petBySpell[spellName]
  if fam and srcName and srcFlags and Has(srcFlags, 0x00001000 + 0x00002000) then   -- a pet / guardian cast it
    petByName[ShortName(srcName)] = fam
  end
  LearnName(dstName, dstFlags)
  if db and db.auras and dstName and dstFlags and Has(dstFlags, TYPE_PLAYER) and spellId then
    if event == "SPELL_AURA_APPLIED" or event == "SPELL_AURA_REFRESH" then
      local kind, prio = AuraKind(spellId, spellName, auraType == "DEBUFF")
      if kind then
        local n = ShortName(dstName)
        logAuras[n] = logAuras[n] or {}
        logAuras[n][spellId] = { icon = select(3, GetSpellInfo(spellId)), prio = prio, kind = kind, t = GetTime() }
      end
    elseif event == "SPELL_AURA_REMOVED" or event == "SPELL_AURA_BROKEN" or event == "SPELL_AURA_BROKEN_SPELL" then
      local list = logAuras[ShortName(dstName)]
      if list then list[spellId] = nil end
    end
  end
  if srcGUID == dstGUID then return end            -- self damage, self buffs, etc.

  if DAMAGE_EVENTS[event] then
    if Has(srcFlags, TYPE_PLAYER) then Mark(srcName) end
    if Has(dstFlags, TYPE_PLAYER) then Mark(dstName) end

  elseif AURA_EVENTS[event] or event == "SPELL_DISPEL" then
    if AURA_EVENTS[event] and (auraType ~= "DEBUFF" or SAP_IDS[spellId]) then return end
    local opposite = Has(srcFlags, REACTION_HOSTILE) ~= Has(dstFlags, REACTION_HOSTILE)
    local involvesYou = AURA_EVENTS[event] and (Has(srcFlags, AFFILIATION_MINE) or Has(dstFlags, AFFILIATION_MINE))
    if not (opposite or involvesYou) then return end  -- e.g. Weakened Soul, cleanses on own team
    if Has(srcFlags, TYPE_PLAYER) then Mark(srcName) end
    if Has(dstFlags, TYPE_PLAYER) then Mark(dstName) end

  elseif HEAL_EVENTS[event] then
    -- healing someone who is in combat puts the healer in combat too
    if Has(srcFlags, TYPE_PLAYER) and RecentlyInCombat(ShortName(dstName)) then Mark(srcName) end
  end
end

------------------------------------------------------------- combat state --

-- For other addons (ArenaFrames' Sap icon on the target frame): is this unit in combat by
-- the API or the combat log? true / false, nil if the unit doesn't exist.
function CombatPlates_InCombat(unit)
  if not UnitExists(unit) then return nil end
  if UnitAffectingCombat(unit) then return true end
  return RecentlyInCombat(UnitName(unit))
end

local function IsFriendly(hp)
  local r, g, b = hp:GetStatusBarColor()
  return (r < 0.01 and g > 0.99 and b < 0.01)   -- friendly NPC (green bar)
      or (r < 0.01 and g < 0.01 and b > 0.99)   -- friendly player (blue bar)
end

local function NameIsRed(fs)
  local r, g, b = fs:GetTextColor()
  return r > 0.9 and g < 0.15 and b < 0.15
end

-- What every source says about one plate.
-- returns unit (or nil), api (true/false, nil if no unit), log age (or nil), red name
local function Signals(d)
  local text = d.name:GetText() or ""
  local unit
  if inArena then unit = ArenaUnitForPlate(d, text) else unit = tokenByName[text] end
  local api = nil
  if unit then api = UnitAffectingCombat(unit) and true or false end
  local age = CombatAge(unit and UnitName(unit) or text)
  return unit, api, age, NameIsRed(d.name)
end

local function InCombat(d)
  local _, api, age, red = Signals(d)
  return api or (age ~= nil and age < COMBAT_WINDOW) or red
end

local function IsClassColored(hp)
  local r, g, b = hp:GetStatusBarColor()
  for _, c in pairs(RAID_CLASS_COLORS or {}) do
    if math.abs(r - c.r) < 0.03 and math.abs(g - c.g) < 0.03 and math.abs(b - c.b) < 0.03 then return true end
  end
  return false
end

-- Sap is only interesting on players: no Sap icon on pets, totems, ghouls, guardians.
-- A plate tied to a unit asks the unit; otherwise the combat log's flags for that name,
-- otherwise the bar color (enemy players are class colored, NPCs and pets plain red).
local function IsPlayerPlate(d)
  local unit = Signals(d)
  if unit then return UnitIsPlayer(unit) and true or false end
  local name = ShortName(d.name:GetText())
  if name and playerNames[name] then return true end
  if name and npcNames[name] then return false end
  return IsClassColored(d.hp)
end

local function SetIcon(d, kind)
  if d.kind == kind then return end
  d.kind = kind
  if kind == "swords" then
    d.tex:SetTexture(SWORDS)
    d.tex:SetTexCoord(0.5, 1, 0, 0.484375)
  else
    d.tex:SetTexture(SAP)
    d.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  end
end

------------------------------------------------------------- party plates --
-- A teammate's plate (party1-4) shows a small widget instead: round class icon, name in
-- class color, and the cooldowns they have running on the left (from ArenaFrames, when
-- that addon is loaded). Reversible: the plate's own parts only get alpha 0 and are given
-- back when the plate hides or stops being a teammate (plates are recycled).

local function FormatTime(t)
  if t >= 60 then return string.format("%d:%02d", math.floor(t / 60), math.floor(t % 60)) end
  return tostring(math.ceil(t))
end

-- A teammate is matched by name (player names are unique): party1-4, and in a raid group
-- (Warmane's solo queue puts the arena team in one) raid1-40 too. Only a hostile red bar
-- rules it out; the friendly blue isn't required.
local function GroupUnitByName(text)
  for i = 1, 4 do
    local u = "party" .. i
    if UnitExists(u) and UnitName(u) == text then return u end
  end
  for i = 1, GetNumRaidMembers() do
    local u = "raid" .. i
    if UnitName(u) == text and not UnitIsUnit(u, "player") then return u end
  end
end

local function PartyUnitForPlate(d)
  local r, g, b = d.hp:GetStatusBarColor()
  if r > 0.9 and g < 0.1 and b < 0.1 then return nil end            -- hostile: never a teammate
  local text = d.name:GetText()
  if not text then return nil end
  text = text:gsub("%s*%(%*%)$", "")                                 -- cross-realm " (*)"
  return GroupUnitByName(text)
end

local function NewCooldownIcon(parent)
  local b = CreateFrame("Frame", nil, parent)
  b:SetWidth(20); b:SetHeight(20)
  b:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
  b:SetBackdropColor(0, 0, 0, 0.6)
  b:SetBackdropBorderColor(0, 0, 0, 1)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
  b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
  b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  b.cd = CreateFrame("Cooldown", nil, b)
  b.cd:SetAllPoints(b.icon)
  local over = CreateFrame("Frame", nil, b)
  over:SetAllPoints(b)
  over:SetFrameLevel(b:GetFrameLevel() + 3)
  b.text = over:CreateFontString(nil, "OVERLAY")
  b.text:SetFont(FONT, 11, "OUTLINE")
  b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
  b:Hide()
  return b
end

local function CreatePartyWidget(d)
  local w = CreateFrame("Frame", nil, d.plate)
  w:SetFrameLevel(math.min(d.plate:GetFrameLevel() + 5, 125))
  w:SetWidth(28); w:SetHeight(28)
  w:SetPoint("CENTER", d.plate, "CENTER", 0, 6)
  w.class = w:CreateTexture(nil, "ARTWORK")
  w.class:SetAllPoints(w)
  w.class:SetTexture(CLASS_CIRCLES)
  w.name = w:CreateFontString(nil, "OVERLAY")
  w.name:SetFont(FONT, 11, "OUTLINE")
  w.name:SetPoint("TOP", w, "BOTTOM", 0, -2)
  w.cds = {}
  for k = 1, PARTY_CDS do
    local b = NewCooldownIcon(w)
    b:SetPoint("RIGHT", k == 1 and w or w.cds[k - 1], "LEFT", -3, 0)
    w.cds[k] = b
  end
  w:Hide()
  d.widget = w
  return w
end

local function RestorePlate(d)
  if d.widget then d.widget:Hide() end
  if d.iconW then d.iconW:Hide() end
  d.partyUnit, d.iconKind = nil, nil
  if not d.replaced then return end
  for i, r in ipairs(d.regions) do r:SetAlpha(d.alphas[i]) end
  d.name:SetWidth(0)
  d.hp:SetAlpha(d.hpA)
  if d.cb then d.cb:SetAlpha(d.cbA) end
  d.replaced = nil
end

local cdScratch = {}
local function ByNewest(a, b) return a.start > b.start end

-- blank the plate's own look (reversible: RestorePlate gives it back)
local function BlankPlate(d)
  if d.replaced then return end
  for _, r in ipairs(d.regions) do r:SetAlpha(0) end
  -- the client puts the name's alpha back, so squeeze it to nothing instead (TidyPlates /
  -- ElvUI do the same); width 0 gives it back its normal auto size
  d.name:SetWidth(0.001)
  d.hp:SetAlpha(0)                                -- the bar keeps updating, just invisible
  if d.cb then d.cb:SetAlpha(0) end
  d.replaced = true
  d.restore = RestorePlate
end

local function ShowPartyPlate(d, unit)
  if d.iconW then d.iconW:Hide() end
  BlankPlate(d)
  d.partyUnit = unit
  local w = d.widget or CreatePartyWidget(d)
  if w.scale ~= db.partysize then w:SetScale(db.partysize); w.scale = db.partysize end
  local _, class = UnitClass(unit)
  local c = CLASS_TCOORDS[class]
  if c then w.class:SetTexCoord(c[1], c[2], c[3], c[4]) end
  local col = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  w.name:SetText(UnitName(unit))
  if col then w.name:SetTextColor(col.r, col.g, col.b) else w.name:SetTextColor(1, 1, 1) end

  -- their running cooldowns, newest first
  wipe(cdScratch)
  local now = GetTime()
  local active = ArenaFrames_ActiveCooldowns and ArenaFrames_ActiveCooldowns(UnitGUID(unit))
  for e, u in pairs(active or {}) do
    if not u.shared and now < u.start + u.dur then
      table.insert(cdScratch, { icon = e.icon, start = u.start, dur = u.dur })
    end
  end
  table.sort(cdScratch, ByNewest)
  for k, b in ipairs(w.cds) do
    local x = cdScratch[k]
    if x then
      b.icon:SetTexture(x.icon)
      if b.start ~= x.start then b.cd:SetCooldown(x.start, x.dur); b.start = x.start end
      b.text:SetText(FormatTime(x.start + x.dur - now))
      b:Show()
    else
      b:Hide()
    end
  end
  w:Show()
end

-- totem / Succubus / Felhunter plate -> icon, kind ("totem" / "pet")
local function IconForPlate(d)
  local text = d.name:GetText()
  if not text then return nil end
  local icon = iconByTotem[(text:gsub(" [IVX]+$", ""))]
  if icon then return icon, "totem" end
  local fam = petByName[text]
  if fam then return petIcon[fam], "pet" end
end

local function CreateIconWidget(d)
  local w = CreateFrame("Frame", nil, d.plate)
  w:SetFrameLevel(math.min(d.plate:GetFrameLevel() + 5, 125))
  w:SetPoint("BOTTOM", d.plate, "CENTER", 0, -4)
  w:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
  w:SetBackdropColor(0, 0, 0, 1)
  w:SetBackdropBorderColor(0, 0, 0, 1)
  w.icon = w:CreateTexture(nil, "ARTWORK")
  w.icon:SetPoint("TOPLEFT", w, "TOPLEFT", 1, -1)
  w.icon:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", -1, 1)
  w.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  w.hp = CreateFrame("StatusBar", nil, w)        -- pets only: their health under the icon
  w.hp:SetStatusBarTexture(FLAT)
  w.hp:SetPoint("TOPLEFT", w, "BOTTOMLEFT", 0, -2)
  w.hp:SetPoint("TOPRIGHT", w, "BOTTOMRIGHT", 0, -2)
  w.hp:SetHeight(4)
  w:Hide()
  d.iconW = w
  return w
end

local function ShowIconPlate(d, icon, kind)
  if d.widget then d.widget:Hide() end
  BlankPlate(d)
  d.iconKind = kind
  local w = d.iconW or CreateIconWidget(d)
  if w.size ~= db.totemsize then w:SetWidth(db.totemsize); w:SetHeight(db.totemsize); w.size = db.totemsize end
  w.icon:SetTexture(icon)
  if kind == "pet" then
    local lo, hi = d.hp:GetMinMaxValues()
    w.hp:SetMinMaxValues(lo, hi)
    w.hp:SetValue(d.hp:GetValue())
    w.hp:SetStatusBarColor(d.hp:GetStatusBarColor())
    w.hp:Show()
  else
    w.hp:Hide()
  end
  w:Show()
end

local function LearnPets()
  for _, u in ipairs(PET_TOKENS) do
    if UnitExists(u) and not UnitIsPlayer(u) then
      local fam = UnitCreatureFamily(u)
      if fam and PETS[fam] then
        local name = UnitName(u)
        if name then petByName[name] = fam end
      end
    end
  end
end

local function CreateAuraRow(d)
  local w = CreateFrame("Frame", nil, d.plate)
  w:SetFrameLevel(math.min(d.plate:GetFrameLevel() + 6, 126))
  w:SetPoint("BOTTOM", d.plate, "TOP", 0, 2)
  w:SetWidth(1); w:SetHeight(1)
  w.icons = {}
  for k = 1, AURA_MAX do
    local b = CreateFrame("Frame", nil, w)
    b:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
    b:SetBackdropColor(0, 0, 0, 1)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
    b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.text = b:CreateFontString(nil, "OVERLAY")
    b.text:SetFont(FONT, 12, "OUTLINE")
    b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.text:SetTextColor(1, 0.9, 0.1)
    b:Hide()
    w.icons[k] = b
  end
  d.auraW = w
  return w
end

local function HideAuras(d)
  if d.auraW then d.auraW:Hide() end
end

local auraList = {}
local function ByAuraPrio(a, b)
  if a.prio ~= b.prio then return a.prio > b.prio end
  return (a.left or 999) > (b.left or 999)
end

local function ShowAuras(d, unit)
  wipe(auraList)
  local now = GetTime()
  if unit then
    for _, filter in ipairs({ "HARMFUL", "HELPFUL" }) do
      for k = 1, 40 do
        local name, _, icon, _, _, dur, expires, _, _, _, spellId = UnitAura(unit, k, filter)
        if not name then break end
        local kind, prio = AuraKind(spellId, name, filter == "HARMFUL")
        if kind and #auraList < 12 then
          table.insert(auraList, { icon = icon, kind = kind, prio = prio,
            left = (expires and expires > 0) and (expires - now) or nil })
        end
      end
    end
  else
    local text = (d.name:GetText() or ""):gsub("%s*%(%*%)$", "")   -- cross-realm names end in " (*)"
    local list = playerNames[text] and logAuras[text]
    for _, a in pairs(list or {}) do
      if now - a.t < 60 then table.insert(auraList, { icon = a.icon, kind = a.kind, prio = a.prio }) end
    end
  end
  if #auraList == 0 then HideAuras(d); return end
  table.sort(auraList, ByAuraPrio)
  local w = d.auraW or CreateAuraRow(d)
  local size, n = db.aurasize, math.min(#auraList, AURA_MAX)
  local colors = ArenaFrames_Auras and ArenaFrames_Auras.CC_COLORS or {}
  for k, b in ipairs(w.icons) do
    local a = auraList[k]
    if a and k <= n then
      if b.size ~= size then b:SetWidth(size); b:SetHeight(size); b.size = size end
      b:ClearAllPoints()
      b:SetPoint("BOTTOMLEFT", w, "BOTTOM", (k - 1) * (size + 2) - (n * (size + 2) - 2) / 2, 0)
      b.icon:SetTexture(a.icon)
      local c = a.kind == "buff" and { 0.2, 0.9, 0.2 } or colors[a.kind] or { 1, 0.15, 0.15 }
      b:SetBackdropBorderColor(c[1], c[2], c[3], 1)
      b.text:SetText(a.left and (a.left < 10 and string.format("%.1f", a.left) or math.floor(a.left + 0.5)) or "")
      b:Show()
    else
      b:Hide()
    end
  end
  w:Show()
end

local function UpdatePlate(d)
  if db.party then
    local unit = PartyUnitForPlate(d)
    if unit then
      d.holder:Hide()
      HideAuras(d)
      ShowPartyPlate(d, unit)
      return
    end
  end
  if db.totems then
    local icon, kind = IconForPlate(d)
    if icon then
      d.holder:Hide()
      HideAuras(d)
      ShowIconPlate(d, icon, kind)
      return
    end
  end
  if d.replaced or d.partyUnit then RestorePlate(d) end
  if IsFriendly(d.hp) then
    d.holder:Hide()
    HideAuras(d)
    return
  end
  if db.auras and ArenaFrames_Auras then ShowAuras(d, (Signals(d))) else HideAuras(d) end
  local combat = InCombat(d)
  local kind
  if testMode then
    kind = (db.mode == "sap") and "sap" or "swords"
  elseif db.mode == "sap" then
    kind = (not combat) and "sap" or nil
  elseif db.mode == "both" then
    kind = combat and "swords" or "sap"
  else
    kind = combat and "swords" or nil
  end
  if kind == "sap" and not testMode and not IsPlayerPlate(d) then kind = nil end
  if kind then
    SetIcon(d, kind)
    d.holder:Show()
  else
    d.holder:Hide()
  end
end

-------------------------------------------------------------------- loop --

local function RefreshContext()
  local _, instanceType = IsInInstance()
  inArena = (instanceType == "arena")
  BuildTokens()
end

-- In arena, friendly plates must be on for the teammates' widgets: turn them on (pets,
-- guardians and totems off) and put the old values back after. Not Shift-V: that also
-- turns the enemy plates off.
local function ArenaFriendlyPlates()
  local _, instanceType = IsInInstance()
  if instanceType == "arena" and db.party and db.friends then
    if not db.savedCVars then
      db.savedCVars = {}
      for k in pairs(FRIEND_CVARS) do db.savedCVars[k] = GetCVar(k) end
    end
    for k, v in pairs(FRIEND_CVARS) do SetCVar(k, v) end
    Print("arena: friendly nameplates on, so teammates' plates show class icon + name + cooldowns")
  elseif db.savedCVars then
    for k, v in pairs(db.savedCVars) do SetCVar(k, v) end
    db.savedCVars = nil
  end
end

local elapsedSince, pruneTimer, friendsTimer = 0, 0, 0
local function OnUpdate(self, elapsed)
  local n = WorldFrame:GetNumChildren()
  if n ~= numChildren then
    numChildren = n
    local kids = { WorldFrame:GetChildren() }
    for i = 1, #kids do
      local f = kids[i]
      if not seen[f] then
        seen[f] = true
        if IsNameplate(f) then SetupPlate(f) end
      end
    end
  end

  elapsedSince = elapsedSince + elapsed
  if elapsedSince < UPDATE_INTERVAL then return end
  pruneTimer = pruneTimer + elapsedSince
  friendsTimer = friendsTimer + elapsedSince
  elapsedSince = 0

  RefreshContext()
  if db.totems then LearnPets() end
  for plate, d in pairs(plates) do
    if plate:IsShown() then UpdatePlate(d) end
  end

  -- V / Shift-V can switch friendly plates off mid-arena; put them back (every 2 s)
  if friendsTimer > 2 then
    friendsTimer = 0
    if inArena and db.party and db.friends and db.savedCVars and not InCombatLockdown()
        and GetCVar("nameplateShowFriends") ~= "1" then
      SetCVar("nameplateShowFriends", "1")
    end
  end

  if pruneTimer > 30 then                          -- keep the combat log table small
    pruneTimer = 0
    local now = GetTime()
    for name, t in pairs(lastCombat) do
      if now - t > COMBAT_WINDOW then lastCombat[name] = nil end
    end
    for name, list in pairs(logAuras) do
      for id, a in pairs(list) do if now - a.t > 60 then list[id] = nil end end
      if next(list) == nil then logAuras[name] = nil end
    end
  end
end

local core = CreateFrame("Frame")
core:RegisterEvent("ADDON_LOADED")
core:SetScript("OnEvent", function(self, event, ...)
  if event == "COMBAT_LOG_EVENT_UNFILTERED" then
    OnCombatLog(...)
    return
  end
  if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_ENABLED" then
    if InCombatLockdown() then self:RegisterEvent("PLAYER_REGEN_ENABLED") return end
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    ArenaFriendlyPlates()
    return
  end
  local name = ...
  if event ~= "ADDON_LOADED" or name ~= ADDON then return end
  CombatPlatesDB = CombatPlatesDB or {}
  db = CombatPlatesDB
  for k, v in pairs(DEFAULTS) do
    if db[k] == nil then db[k] = v end
  end
  SAP = select(3, GetSpellInfo(6770)) or SAP_FALLBACK
  for _, id in ipairs(TOTEM_IDS) do
    local name, _, icon = GetSpellInfo(id)
    if name then iconByTotem[name] = icon end
  end
  for fam, v in pairs(PETS) do
    petIcon[fam] = select(3, GetSpellInfo(v[1])) or SAP_FALLBACK
    for _, id in ipairs(v[2]) do
      local name = GetSpellInfo(id)
      if name then petBySpell[name] = fam end
    end
  end
  self:UnregisterEvent("ADDON_LOADED")
  self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  self:RegisterEvent("PLAYER_ENTERING_WORLD")
  self:SetScript("OnUpdate", OnUpdate)
end)

------------------------------------------------------------------- slash --

local function Help()
  Print(string.format("v1.7  mode=%s  size=%d  pos=%s  offset=%d %d%s",
    db.mode, db.size, db.pos, db.x, db.y, testMode and "  |cff00ff00(test mode)|r" or ""))
  Print("/cplates mode combat|sap|both,  size 10-64,  pos left|right|top,  offset x y,  test,  debug,  reset")
  Print(string.format("/cplates party on|off (now %s): teammates' plates = class icon + name + cooldowns;  " ..
    "partysize 0.5-3 (now %.1f);  friends on|off (now %s): friendly plates on in arena",
    db.party and "on" or "off", db.partysize, db.friends and "on" or "off"))
  Print(string.format("/cplates auras on|off (now %s): CC, immunities, big buffs above enemy plates;  aurasize 14-48 (now %d)",
    db.auras and "on" or "off", db.aurasize))
  Print(string.format("/cplates totems on|off (now %s): totems, Succubus, Felhunter = big spell icon;  totemsize 16-64 (now %d)",
    db.totems and "on" or "off", db.totemsize))
end

local function Debug()
  RefreshContext()
  local count = 0
  for plate, d in pairs(plates) do
    if plate:IsShown() and not IsFriendly(d.hp) then
      count = count + 1
      if count <= 12 then
        local unit, api, age, red = Signals(d)
        local combat = api or (age ~= nil and age < COMBAT_WINDOW) or red
        Print(string.format("%s: %s | api: %s | log: %s | name: %s | player: %s",
          d.name:GetText() or "?",
          combat and "|cffff4040IN combat|r" or "|cff40ff40out|r",
          unit and ((api and "yes" or "no") .. " (" .. unit .. ")") or "-",
          age and string.format("%.1fs ago", age) or "-",
          red and "red" or "not red",
          IsPlayerPlate(d) and "yes" or "no (no Sap icon)"))
      end
    end
  end
  if count == 0 then Print("no enemy nameplates visible right now") end
  -- teammates: every shown friendly-looking plate, and why it is or isn't a teammate widget
  local names = {}
  for i = 1, 4 do
    if UnitExists("party" .. i) then table.insert(names, "party" .. i .. "=" .. tostring(UnitName("party" .. i))) end
  end
  Print(string.format("party: %s | teammate plates %s | friendly plates CVar %s",
    #names > 0 and table.concat(names, ", ") or "none", db.party and "on" or "off",
    tostring(GetCVar("nameplateShowFriends"))))
  local shownPlates = 0
  for plate, d in pairs(plates) do
    if plate:IsShown() then
      shownPlates = shownPlates + 1
      local r, g, b = d.hp:GetStatusBarColor()
      local text = (d.name:GetText() or ""):gsub("%s*%(%*%)$", "")
      if d.partyUnit or (b > 0.5 and r < 0.5) or IsFriendly(d.hp) or GroupUnitByName(text) then
        Print(string.format("friendly plate '%s' bar %.2f %.2f %.2f -> %s", d.name:GetText() or "?", r, g, b,
          d.partyUnit and ("teammate widget (" .. d.partyUnit .. ")") or "not a party member"))
      end
    end
  end
  Print(string.format("%d nameplates shown right now", shownPlates))
end

SLASH_COMBATPLATES1 = "/cplates"
SLASH_COMBATPLATES2 = "/combatplates"
SlashCmdList.COMBATPLATES = function(msg)
  if not db then return end
  local cmd, a, b = string.lower(msg or ""):match("^%s*(%S*)%s*(%S*)%s*(%S*)")

  if cmd == "mode" and (a == "combat" or a == "sap" or a == "both") then
    db.mode = a
    Print("mode = " .. a)
  elseif cmd == "size" and tonumber(a) then
    db.size = math.max(10, math.min(64, math.floor(tonumber(a))))
    ApplyLayoutAll()
    Print("size = " .. db.size)
  elseif cmd == "pos" and (a == "left" or a == "right" or a == "top") then
    db.pos = a
    ApplyLayoutAll()
    Print("position = " .. a)
  elseif cmd == "offset" and tonumber(a) and tonumber(b) then
    db.x, db.y = math.floor(tonumber(a)), math.floor(tonumber(b))
    ApplyLayoutAll()
    Print(string.format("offset = %d %d", db.x, db.y))
  elseif cmd == "test" then
    testMode = not testMode
    Print(testMode and "test mode ON - icons on every enemy plate. /cplates test again to stop."
      or "test mode OFF")
  elseif cmd == "debug" then
    Debug()
  elseif cmd == "party" and (a == "on" or a == "off") then
    db.party = (a == "on")
    if not db.party then
      for _, d in pairs(plates) do RestorePlate(d) end
    end
    ArenaFriendlyPlates()
    Print("teammates' plates " .. a)
  elseif cmd == "partysize" and tonumber(a) then
    db.partysize = math.max(0.5, math.min(3, tonumber(a)))
    Print("teammates' plate size = " .. db.partysize)
  elseif cmd == "friends" and (a == "on" or a == "off") then
    db.friends = (a == "on")
    ArenaFriendlyPlates()
    Print("friendly plates in arena " .. a)
  elseif cmd == "auras" and (a == "on" or a == "off") then
    db.auras = (a == "on")
    if not db.auras then for _, d in pairs(plates) do HideAuras(d) end end
    Print("auras on enemy plates " .. a)
  elseif cmd == "aurasize" and tonumber(a) then
    db.aurasize = math.max(14, math.min(48, math.floor(tonumber(a))))
    Print("plate aura size = " .. db.aurasize)
  elseif cmd == "totems" and (a == "on" or a == "off") then
    db.totems = (a == "on")
    if not db.totems then
      for _, d in pairs(plates) do if d.iconKind then RestorePlate(d) end end
    end
    Print("totem / demon icons " .. a)
  elseif cmd == "totemsize" and tonumber(a) then
    db.totemsize = math.max(16, math.min(64, math.floor(tonumber(a))))
    Print("totem / demon icon size = " .. db.totemsize)
  elseif cmd == "reset" then
    for k, v in pairs(DEFAULTS) do db[k] = v end
    ApplyLayoutAll()
    Print("settings reset")
  else
    Help()
  end
end
