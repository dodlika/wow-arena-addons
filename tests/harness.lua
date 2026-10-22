-- Minimal mock of the WoW 3.3.5a API (Lua 5.1), enough to unit-test addons outside the game.
-- Keeps 3.3.5 semantics: boolean-ish APIs return 1/nil. Extend it when an addon uses new APIs.

local eventFrames = {}
local function B(v) if v then return 1 end return nil end

local Base = {}
Base.__index = Base
function Base:GetObjectType() return self._type end
function Base:GetName() return self._name end

-- Regions ------------------------------------------------------------------
local Texture = setmetatable({}, { __index = Base }); Texture.__index = Texture
function Texture:SetTexture(t) self._tex = t end
function Texture:GetTexture() return self._tex end
function Texture:SetTexCoord(...) self._coords = { ... } end
function Texture:SetAllPoints(f) self._all = f end
function Texture:Hide() self._shown = false end
function Texture:Show() self._shown = true end
function Texture:SetAlpha(a) self._alpha = a end
function Texture:GetAlpha() return self._alpha or 1 end
function Texture:SetPoint(...) end
function Texture:SetWidth(w) self._w = w end
function Texture:SetHeight(h) self._h = h end
function Texture:SetVertexColor(r, g, b, a) self._vc = { r, g, b, a or 1 } end
function Texture:SetGradientAlpha(orient, ...) assert(orient == "VERTICAL" or orient == "HORIZONTAL") end

local FontString = setmetatable({}, { __index = Base }); FontString.__index = FontString
function FontString:SetText(t) self._text = t end
function FontString:GetText() return self._text end
function FontString:SetTextColor(r, g, b, a) self._c = { r, g, b, a or 1 } end
function FontString:GetTextColor() return self._c[1], self._c[2], self._c[3], self._c[4] end
function FontString:Hide() self._shown = false end
function FontString:Show() self._shown = true end
function FontString:SetAlpha(a) self._alpha = a end
function FontString:GetAlpha() return self._alpha or 1 end
function FontString:SetPoint(...) self._points = self._points or {}; table.insert(self._points, { ... }) end
function FontString:ClearAllPoints() self._points = {} end
function FontString:SetFont(path, size, flags) assert(type(size) == "number"); self._font = { path, size, flags } end
function FontString:SetJustifyH(j) self._justify = j end
function FontString:SetShadowOffset(x, y) self._shadow = { x, y } end
function FontString:SetShadowColor(r, g, b, a) end
function FontString:SetHeight(h) self._h = h end
function FontString:SetWidth(w) self._w = w end

local function NewRegion(class, typ, tex)
  local r = setmetatable({ _type = typ, _shown = true, _c = { 1, 1, 1, 1 } }, class)
  if tex then r._tex = tex end
  return r
end

-- Frames -------------------------------------------------------------------
local Frame = setmetatable({}, { __index = Base }); Frame.__index = Frame
function Frame:SetScript(k, fn) self._scripts[k] = fn end
function Frame:GetScript(k) return self._scripts[k] end
function Frame:HookScript(k, fn)
  local old = self._scripts[k]
  self._scripts[k] = function(...) if old then old(...) end fn(...) end
end
function Frame:RegisterEvent(e) self._events[e] = true; eventFrames[self] = true end
function Frame:UnregisterEvent(e) self._events[e] = nil end
-- Protected (secure template) frames: like the client, layout/visibility/attribute
-- changes from addon code are blocked during combat lockdown.
local function Guard(f, what)
  if f._protected and COMBAT then error("ADDON_ACTION_BLOCKED: " .. what .. " on protected frame in combat", 3) end
end
function Frame:Show()
  Guard(self, "Show")
  local was = self._shown; self._shown = true
  if not was and self._scripts.OnShow then self._scripts.OnShow(self) end
end
function Frame:Hide()
  Guard(self, "Hide")
  local was = self._shown; self._shown = false
  if was and self._scripts.OnHide then self._scripts.OnHide(self) end
end
function Frame:IsShown() return B(self._shown) end
function Frame:IsVisible()
  local f = self
  while f do if not f._shown then return nil end f = f._parent end
  return 1
end
function Frame:SetAlpha(a) self._alpha = a end
function Frame:GetAlpha() return self._alpha or 1 end
function Frame:SetScale(s) Guard(self, "SetScale"); self._scale = s end
function Frame:SetAllPoints(f) self._all = f end
function Frame:SetBackdrop(b) self._backdrop = b end
function Frame:SetBackdropColor(r, g, b, a) self._bdColor = { r, g, b, a } end
function Frame:SetBackdropBorderColor(r, g, b, a) self._bdBorder = { r, g, b, a } end
function Frame:SetMovable(m) self._movable = m end
function Frame:SetClampedToScreen(c) end
function Frame:EnableMouse(m) self._mouse = m end
function Frame:StartMoving() assert(self._movable, "StartMoving on a non-movable frame") end
function Frame:StopMovingOrSizing() end
function Frame:GetPoint(i)
  local p = self._points[i or 1]
  if p then return p[1], p[2], p[3], p[4], p[5] end
end
function Frame:SetStatusBarTexture(t) self._barTex = t end
function Frame:SetCooldown(start, duration) self._cd = { start, duration } end
function Frame:SetFrameLevel(l) assert(type(l) == "number"); self._level = l end
function Frame:GetFrameLevel() return self._level end
function Frame:SetWidth(w) Guard(self, "SetWidth"); self._w = w end
function Frame:SetHeight(h) Guard(self, "SetHeight"); self._h = h end
function Frame:ClearAllPoints() Guard(self, "ClearAllPoints"); self._points = {} end
function Frame:SetPoint(...) Guard(self, "SetPoint"); table.insert(self._points, { ... }) end
function Frame:SetAttribute(k, v) Guard(self, "SetAttribute"); self._attr[k] = v end
function Frame:GetAttribute(k) return self._attr[k] end
function Frame:RegisterForClicks(...) self._clicks = { ... } end
function Frame:UnregisterAllEvents() self._events = {} end
function Frame:SetParent(p) Guard(self, "SetParent"); self._parent = p end
function Frame:GetParent() return self._parent end
function Frame:SetHitRectInsets(...) Guard(self, "SetHitRectInsets"); self._hitRect = { ... } end
function Frame:SetFrameStrata(s) Guard(self, "SetFrameStrata"); self._strata = s end
function Frame:SetToplevel(t) self._toplevel = t end
function Frame:SetClampRectInsets(...) self._clampInsets = { ... } end
function Frame:IsUserPlaced() return B(self._userPlaced) end
function Frame:SetUserPlaced(v) self._userPlaced = v end
function Frame:GetScale() return self._scale or 1 end
-- RegisterForDrag("LeftButton") enables dragging, RegisterForDrag() with no button clears it
function Frame:RegisterForDrag(...) self._drag = select("#", ...) > 0 and { ... } or nil end
function Frame:CreateTexture(name, layer)
  local t = NewRegion(Texture, "Texture"); t._layer = layer
  table.insert(self._regions, t); return t
end
function Frame:CreateFontString()
  local f = NewRegion(FontString, "FontString"); table.insert(self._regions, f); return f
end
function Frame:GetRegions() return unpack(self._regions) end
function Frame:GetChildren() return unpack(self._children) end
function Frame:GetNumChildren() return #self._children end
function Frame:SetStatusBarColor(r, g, b) self._bar = { r, g, b } end
function Frame:SetMinMaxValues(a, b) self._min, self._max = a, b end
function Frame:GetMinMaxValues() return self._min or 0, self._max or 100 end
function Frame:SetValue(v) self._val = v end
function Frame:GetValue() return self._val or (self._max or 100) end
function Frame:GetStatusBarColor() return self._bar[1], self._bar[2], self._bar[3], 1 end

function CreateFrame(typ, name, parent, template)
  local f = setmetatable({ _type = typ, _name = name, _scripts = {}, _events = {},
    _shown = true, _level = parent and (parent._level + 1) or 1, _points = {},
    _regions = {}, _children = {}, _bar = { 1, 0, 0 }, _parent = parent, _attr = {},
    _protected = template and template:find("Secure") and true or nil }, Frame)
  if parent then table.insert(parent._children, f) end
  if name then _G[name] = f end  -- named frames become globals, like in the client
  return f
end

WorldFrame = CreateFrame("Frame", "WorldFrame")
UIParent = CreateFrame("Frame", "UIParent")
-- Blizzard frames addons may hide
PlayerFrame = CreateFrame("Button", "PlayerFrame", UIParent)
PlayerFrame.unit = "player"
PlayerFrameDropDown = CreateFrame("Frame", "PlayerFrameDropDown", PlayerFrame)
PetFrame = CreateFrame("Button", "PetFrame", PlayerFrame)
TargetFrame = CreateFrame("Button", "TargetFrame", UIParent)
FocusFrame = CreateFrame("Button", "FocusFrame", UIParent)
for i = 1, 4 do CreateFrame("Button", "PartyMemberFrame" .. i, UIParent) end
ComboFrame = CreateFrame("Frame", "ComboFrame", UIParent)
ComboFrame._shown = false
for i = 1, 5 do
  local p = CreateFrame("Frame", "ComboPoint" .. i, ComboFrame)
  CreateFrame("Frame", "ComboPoint" .. i .. "Highlight", p)._alpha = 0
end
for _, f in ipairs({ PlayerFrame, TargetFrame, FocusFrame, ComboFrame }) do f._events.PLAYER_TARGET_CHANGED = true end
-- Blizzard's unit frames are SecureUnitButtons: left click targets, right click runs their
-- own (untainted) menu function, like SecureUnitButton_OnLoad sets them up
OPENED_MENU = nil
for unit, f in pairs({ player = PlayerFrame, target = TargetFrame, focus = FocusFrame, party1 = PartyMemberFrame1,
    party2 = PartyMemberFrame2, party3 = PartyMemberFrame3, party4 = PartyMemberFrame4 }) do
  f._protected = true
  f._attr.unit = unit
  f._attr["*type1"] = "target"
  f._attr["*type2"] = "menu"
  f.menu = function() OPENED_MENU = f:GetName() .. "DropDown" end
end

-- Minimal SecureActionButton_OnClick: modified attribute lookup + the actions we use.
MODIFIER = nil            -- e.g. "shift" while a test holds shift
TARGETED, FOCUSED = nil, nil
local function ModAttr(f, name, button)
  local n = button == "RightButton" and "2" or "1"
  local keys = { name .. n, "*" .. name .. n, name .. "*", "*" .. name .. "*" }
  if MODIFIER then table.insert(keys, 1, MODIFIER .. "-" .. name .. n) end
  for _, k in ipairs(keys) do
    if f._attr[k] ~= nil then return f._attr[k] end
  end
end
function SecureClick(f, button)
  local t, unit = ModAttr(f, "type", button), f._attr.unit
  if t == "target" then TARGETED = unit
  elseif t == "focus" then FOCUSED = unit
  elseif t == "click" then
    local d = ModAttr(f, "clickbutton", button)
    if d then SecureClick(d, button) end          -- delegate:Click(button)
  elseif t == "menu" then
    local m = rawget(f, "menu")
    if m then m(f, unit, button) end
  end
end
COMBO_UPDATES = 0
function ComboFrame_Update() COMBO_UPDATES = COMBO_UPDATES + 1 end
HOOKS = {}
function hooksecurefunc(name, fn)
  local orig = _G[name]
  HOOKS[name] = fn
  _G[name] = function(...) local r = { orig(...) }; fn(...); return unpack(r) end
end
function FocusFrame_SetSmallSize(small) FocusFrame:ClearAllPoints(); FocusFrame:SetPoint("TOPLEFT", FocusFrame._parent, "TOPLEFT", 250, -240) end
DropDownList1 = CreateFrame("Frame", "DropDownList1", UIParent)
DropDownList1._shown = false
TargetFrameDropDown = CreateFrame("Frame", "TargetFrameDropDown", TargetFrame)
CLOSED_MENUS = 0
CVARS = { screenEdgeFlash = true, nameplateShowFriends = "0", nameplateShowFriendlyPets = "1",
  nameplateShowFriendlyGuardians = "1", nameplateShowFriendlyTotems = "1" }
function GetCVarBool(k) return B(CVARS[k] and CVARS[k] ~= "0") end
function GetCVar(k) local v = CVARS[k]; if v == nil then return nil end; return tostring(v) end
function SetCVar(k, v) CVARS[k] = tostring(v) end
FLASH = nil
function CombatFeedback_StartFullscreenStatus() FLASH = true end
function CombatFeedback_StopFullscreenStatus() FLASH = false end
TOOLTIP_UNIT = nil
function UnitFrame_OnEnter(self) TOOLTIP_UNIT = self.unit end
function UnitFrame_OnLeave() TOOLTIP_UNIT = nil end
SOUNDS = {}
function PlaySound(s) table.insert(SOUNDS, s) end
function CloseDropDownMenus() CLOSED_MENUS = CLOSED_MENUS + 1; DropDownList1._shown = false end
MENUS = {}
function ToggleDropDownMenu(level, value, frame, anchor) table.insert(MENUS, frame) end

DebuffTypeColor = {   -- FrameXML BuffFrame.lua
  none = { r = 0.80, g = 0, b = 0 }, Magic = { r = 0.20, g = 0.60, b = 1.00 },
  Curse = { r = 0.60, g = 0.00, b = 1.00 }, Disease = { r = 0.60, g = 0.40, b = 0 },
  Poison = { r = 0.00, g = 0.60, b = 0 },
}
RAID_CLASS_COLORS = {   -- FrameXML Constants.lua
  HUNTER = { r = 0.67, g = 0.83, b = 0.45 }, WARLOCK = { r = 0.58, g = 0.51, b = 0.79 },
  PRIEST = { r = 1.0, g = 1.0, b = 1.0 }, PALADIN = { r = 0.96, g = 0.55, b = 0.73 },
  MAGE = { r = 0.41, g = 0.8, b = 0.94 }, ROGUE = { r = 1.0, g = 0.96, b = 0.41 },
  DRUID = { r = 1.0, g = 0.49, b = 0.04 }, SHAMAN = { r = 0.0, g = 0.44, b = 0.87 },
  WARRIOR = { r = 0.78, g = 0.61, b = 0.43 }, DEATHKNIGHT = { r = 0.77, g = 0.12, b = 0.23 },
}
COMBAT = false
function InCombatLockdown() return B(COMBAT) end

-- RegisterUnitWatch: the secure state driver shows/hides the frame by UnitExists(unit),
-- also in combat (it's secure code, so it bypasses the combat guard). Run by Tick().
local unitWatch = {}
function RegisterUnitWatch(f) Guard(f, "RegisterUnitWatch"); unitWatch[f] = true end
function UnregisterUnitWatch(f) Guard(f, "UnregisterUnitWatch"); unitWatch[f] = nil end
function IsUnitWatched(f) return unitWatch[f] end
-- RegisterStateDriver(f, "visibility", "[cond] show|hide; ...; default"): the conditions we
-- use are [group:raid] and [target=unit,exists]
local stateDrivers = {}
function RegisterStateDriver(f, state, cond) Guard(f, "RegisterStateDriver"); stateDrivers[f] = cond end
function UnregisterStateDriver(f, state) Guard(f, "UnregisterStateDriver"); stateDrivers[f] = nil end
function StateDriverOf(f) return stateDrivers[f] end
local function EvalVisibility(cond)
  for clause in cond:gmatch("[^;]+") do
    local conds, action = clause:match("^%s*%[(.-)%]%s*(%a+)%s*$")
    if not conds then return clause:match("%a+") == "show" end
    local ok = true
    for c in conds:gmatch("[^,]+") do
      local u = c:match("^target=(.+)$")
      if c == "group:raid" then ok = ok and RAID > 0
      elseif u then ok = ok and true; conds = u
      elseif c == "exists" then ok = ok and UNITS[conds] ~= nil end
    end
    if ok then return action == "show" end
  end
  return false
end
local function RunUnitWatch()
  for f, cond in pairs(stateDrivers) do
    local want = EvalVisibility(cond)
    if want ~= f._shown then
      local p = f._protected; f._protected = nil
      if want then f:Show() else f:Hide() end
      f._protected = p
    end
  end
  for f in pairs(unitWatch) do
    local want = UNITS[f._attr.unit] and true or false
    if want ~= f._shown then
      local p = f._protected; f._protected = nil
      if want then f:Show() else f:Hide() end
      f._protected = p
    end
  end
end

-- Game state / unit API ------------------------------------------------------
UNITS = {}  -- token -> { name=, player=bool, combat=bool, hp=, maxhp=, guid=, class=, faction=, dead= }
function UnitExists(u) return B(UNITS[u]) end
function UnitIsPlayer(u) return B(UNITS[u] and UNITS[u].player) end
function UnitName(u) return UNITS[u] and UNITS[u].name end
function UnitCreatureFamily(u) return UNITS[u] and UNITS[u].family end
function UnitAffectingCombat(u) return B(UNITS[u] and UNITS[u].combat) end
function UnitHealth(u) return UNITS[u] and UNITS[u].hp or 0 end
function UnitHealthMax(u) return UNITS[u] and UNITS[u].maxhp or 0 end
function UnitGUID(u) return UNITS[u] and UNITS[u].guid end
function UnitClass(u)
  local c = UNITS[u] and UNITS[u].class
  if c then return c:sub(1, 1) .. c:sub(2):lower(), c end
end
function UnitIsUnit(a, b) return B(UNITS[a] and UNITS[b] and UNITS[a].guid == UNITS[b].guid) end
function UnitFactionGroup(u) return UNITS[u] and UNITS[u].faction end
function UnitIsDeadOrGhost(u) return B(UNITS[u] and UNITS[u].dead) end
function UnitReaction(u) return UNITS[u] and UNITS[u].reaction or 2 end
time = time or os.time
date = date or os.date
COMBATLOG = nil          -- LoggingCombat state
LOGCALLS = {}             -- every LoggingCombat(on) call
function LoggingCombat(on)
  if on ~= nil then table.insert(LOGCALLS, on); COMBATLOG = on and 1 or nil end
  return COMBATLOG
end
SENT = {}                 -- SendChatMessage calls: { msg, channel }
function SendChatMessage(msg, channel) table.insert(SENT, { msg, channel }) end
function UnitRace(u) local r = UNITS[u] and UNITS[u].race; if r then return r, r end end
-- spells of the player: SPELL_CD[name] = { start, dur }, IN_RANGE[unit] = 1/0, NO_POWER[name] = true
SPELL_CD, IN_RANGE, NO_POWER, NEAR = {}, {}, {}, {}
function GetSpellCooldown(name) local c = SPELL_CD[name]; if c then return c[1], c[2], 1 end; return 0, 0, 1 end
function IsSpellInRange(name, u) return IN_RANGE[u] end
function IsUsableSpell(name) if NO_POWER[name] then return nil, 1 end; return 1, nil end
-- NEAR[unit] = yards (CheckInteractDistance: 2 = ~11 yd, 3 = 10 yd, 4 = 28 yd)
function CheckInteractDistance(u, i)
  local d = NEAR[u]
  if not d then return nil end
  return B(d <= ({ 28, 11.11, 10, 28 })[i])
end
TALENTS = { 0, 0, 0 }
function GetTalentTabInfo(i) return "Tab" .. i, "icon", TALENTS[i] end
-- talent trees: TREE[group][tab] = { { name, tier, col, rank }, ... }; PREVIEW[group] = { "tab:index" = points }
TREE, PREVIEW, TALENT_GROUP = { {}, {} }, { {}, {} }, 1
function GetNumTalentGroups() return #TREE[2] > 0 and 2 or 1 end
function GetActiveTalentGroup() return TALENT_GROUP end
function GetNumTalentTabs() return 3 end
function GetNumTalents(tab) return #((TREE[1][tab]) or {}) end
function GetTalentInfo(tab, i, inspect, pet, g)
  local t = TREE[g or TALENT_GROUP][tab]; t = t and t[i]
  if t then return t[1], "icon", t[2], t[3], t[4], t[5] or 5 end
end
function ResetGroupPreviewTalentPoints(pet, g) PREVIEW[g] = {} end
UNSPENT = 71
function GetUnspentTalentPoints() return UNSPENT end
function GetGroupPreviewTalentPointsSpent(pet, g)
  local n = 0; for _, v in pairs(PREVIEW[g] or {}) do n = n + v end; return n
end
function LearnTalent(tab, i)
  local t = TREE[TALENT_GROUP][tab][i]
  if UNSPENT > 0 and t[4] < (t[5] or 5) then t[4] = t[4] + 1; UNSPENT = UNSPENT - 1 end
end
function AddPreviewTalentPoints(tab, i, n, pet, g)
  local k = tab .. ":" .. i; PREVIEW[g][k] = (PREVIEW[g][k] or 0) + n
end
LATENCY = 100
function GetNetStats() return 0, 0, LATENCY end
function UnitInRange(u) return B(UNITS[u] and not UNITS[u].far) end
function UnitIsConnected(u) return B(UNITS[u] and not UNITS[u].offline) end
function UnitPowerType(u) return UNITS[u] and UNITS[u].ptype or 0 end
function UnitPower(u) return UNITS[u] and UNITS[u].power or 0 end
function UnitPowerMax(u) return UNITS[u] and UNITS[u].maxpower or 0 end
PORTRAIT_CALLS = 0
function SetPortraitTexture(tex, u) PORTRAIT_CALLS = PORTRAIT_CALLS + 1; tex._tex = "portrait:" .. u end
function SetPortraitToTexture(tex, path) tex._tex = "round:" .. path end
function UnitLevel(u) return UNITS[u] and (UNITS[u].level or 80) or 0 end
function UnitClassification(u) return UNITS[u] and UNITS[u].classification or "normal" end
function UnitSelectionColor(u)
  local r = UnitReaction(u)
  if r <= 3 then return 1, 0, 0 elseif r == 4 then return 1, 1, 0 else return 0, 1, 0 end
end
function GetQuestDifficultyColor(level) return { r = 1, g = 1, b = 0 } end   -- "yellow" (same level)
function GetRaidTargetIndex(u) return UNITS[u] and UNITS[u].raidIcon end
function SetRaidTargetIconTexture(tex, i) tex._raid = i end
-- reaction/attackable are seen from the player; the other argument is the unit
local function Other(a, b) return UNITS[a == "player" and b or a] end
function UnitCanAttack(a, b)
  local u = Other(a, b)
  if u and u.attackable ~= nil then return B(u.attackable) end
  return B(u and (u.reaction or 2) <= 4)
end
function UnitIsEnemy(a, b) local u = Other(a, b); return B(u and (u.reaction or 2) <= 3) end
function UnitIsFriend(a, b) local u = Other(a, b); return B(u and (u.reaction or 2) >= 5) end
COMBO = 0
function GetComboPoints(who, target) assert(who == "player" and target == "target"); return COMBO end
-- auras: UNITS[u].auras = { { name=, icon=, count=, dur=, expires=, caster=, id=, harmful= } }
function UnitAura(u, i, filter)
  local list = UNITS[u] and UNITS[u].auras
  if not list then return nil end
  local harmful = filter:find("HARMFUL") and true or false
  local n = 0
  for _, a in ipairs(list) do
    if (a.harmful or false) == harmful then
      n = n + 1
      if n == i then
        return a.name, "", a.icon or ("Interface\\Icons\\" .. a.name:gsub(" ", "")), a.count or 0, a.dtype,
          a.dur or 0, a.expires or 0, a.caster, nil, nil, a.id
      end
    end
  end
end
-- casts: UNITS[u].cast = { name=, icon=, start=, endt=, channel=, notInt= } (seconds)
function UnitCastingInfo(u)
  local c = UNITS[u] and UNITS[u].cast
  if c and not c.channel then
    return c.name, "", c.name, c.icon or "casticon", c.start * 1000, c.endt * 1000, nil, 1, c.notInt and 1 or nil
  end
end
function UnitChannelInfo(u)
  local c = UNITS[u] and UNITS[u].cast
  if c and c.channel then
    return c.name, "", c.name, c.icon or "casticon", c.start * 1000, c.endt * 1000, nil, c.notInt and 1 or nil
  end
end
INSTANCE = "none"
function IsInInstance() return B(INSTANCE ~= "none"), INSTANCE end
NOW = 100
function GetTime() return NOW end
bit = { band = function(a, b)
  local r, p = 0, 1
  while a > 0 and b > 0 do
    local ra, rb = a % 2, b % 2
    if ra == 1 and rb == 1 then r = r + p end
    a, b, p = (a - ra) / 2, (b - rb) / 2, p * 2
  end
  return r
end }
RAID, PARTY = 0, 0
function GetNumRaidMembers() return RAID end
function GetNumPartyMembers() return PARTY end
-- id -> name; icon is Interface\Icons\<name without spaces>, Sap keeps its real icon
SPELLS = {
  [6770] = "Sap", [2070] = "Sap", [11297] = "Sap", [51724] = "Sap", [1776] = "Gouge",
  [408] = "Kidney Shot", [8643] = "Kidney Shot", [1833] = "Cheap Shot", [2094] = "Blind",
  [118] = "Polymorph", [12826] = "Polymorph", [5782] = "Fear", [6215] = "Fear",
  [853] = "Hammer of Justice", [10308] = "Hammer of Justice",
  [64044] = "Psychic Horror", [64058] = "Psychic Horror",
  [31117] = "Unstable Affliction", [47843] = "Unstable Affliction",
  [42292] = "PvP Trinket", [59752] = "Every Man for Himself", [33786] = "Cyclone",
  [47486] = "Mortal Strike", [1766] = "Kick", [2139] = "Counterspell",
  [48666] = "Mutilate", [51713] = "Shadow Dance", [14185] = "Preparation", [53007] = "Penance",
  [1833] = "Cheap Shot", [1044] = "Hand of Freedom", [47813] = "Corruption", [48156] = "Mind Flay",
  [59752] = "Every Man for Himself", [31224] = "Cloak of Shadows", [642] = "Divine Shield", [45438] = "Ice Block",
  [19750] = "Flash of Light", [32379] = "Shadow Word: Death", [19503] = "Scatter Shot", [2061] = "Flash Heal",
  [47540] = "Penance", [118] = "Polymorph",
  [6358] = "Seduction", [10278] = "Hand of Protection", [6940] = "Hand of Sacrifice",
  [25771] = "Forbearance", [15473] = "Shadowform", [49284] = "Earth Shield", [17116] = "Nature's Swiftness", [16188] = "Nature's Swiftness",
}
UNKNOWN_SPELLS = {}                               -- names not in "your" spellbook
function GetSpellInfo(id)
  if type(id) == "string" then                    -- by name: only spells "you know" (listed in SPELLS)
    if UNKNOWN_SPELLS[id] then return nil end
    for k, v in pairs(SPELLS) do if v == id then id = k; break end end
  end
  local name = SPELLS[id]
  if not name then return nil end
  if name == "Sap" then return name, "Rank 1", [[Interface\Icons\Ability_Sap]] end
  return name, "", "Interface\\Icons\\" .. name:gsub(" ", "")
end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
SlashCmdList = {}
CHAT = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) table.insert(CHAT, m) end }

function FireEvent(e, ...)
  for f in pairs(eventFrames) do
    if f._events[e] and f._scripts.OnEvent then f._scripts.OnEvent(f, e, ...) end
  end
end

function Tick(dt)
  RunUnitWatch()
  for f in pairs(eventFrames) do
    if f._scripts.OnUpdate then f._scripts.OnUpdate(f, dt or 0.2) end
  end
end

-- Build a default-layout 3.3.5 nameplate (11 regions + health/cast bars).
function MakePlate(name, nameRGB, barRGB, opts)
  opts = opts or {}
  local p = CreateFrame("Frame", nil, WorldFrame)
  local tex = function(path) local t = NewRegion(Texture, "Texture", path); table.insert(p._regions, t) end
  tex("Interface\\TargetingFrame\\UI-TargetingFrame-Flash")           -- 1 threat glow
  tex(opts.blankBorder and nil or "Interface\\Tooltips\\Nameplate-Border") -- 2 border
  tex("castborder"); tex("castnostop"); tex("spellicon"); tex("highlight")  -- 3..6
  local nameFS = NewRegion(FontString, "FontString"); nameFS:SetText(name)
  nameFS:SetTextColor(unpack(nameRGB)); table.insert(p._regions, nameFS)    -- 7 name
  local lvl = NewRegion(FontString, "FontString"); lvl:SetText("80")
  table.insert(p._regions, lvl)                                            -- 8 level
  tex("skull"); tex("raid"); tex("elite")                                  -- 9..11
  local hp = CreateFrame("StatusBar", nil, p); hp:SetStatusBarColor(unpack(barRGB))
  if opts.maxhp then hp:SetMinMaxValues(0, opts.maxhp); hp:SetValue(opts.hp or opts.maxhp) end
  p._hp = hp
  CreateFrame("StatusBar", nil, p)                                         -- cast bar
  p._nameFS = nameFS
  return p
end

function Holder(p)
  -- our holder is the first plain "Frame" child the addon added to the plate
  for _, c in ipairs(p._children) do if c._type == "Frame" then return c end end
end

-- Load an addon the way the client does: every file listed in Name/Name.toc, in order.
function LoadAddon(name)
  local toc = assert(io.open(name .. "/" .. name .. ".toc"), "no toc for " .. name)
  for line in toc:lines() do
    line = line:gsub("\r", ""):match("^%s*(.-)%s*$")
    if line ~= "" and not line:find("^#") then dofile(name .. "/" .. line:gsub("\\", "/")) end
  end
  toc:close()
end
SPELL_FAILED_LINE_OF_SIGHT = "Target not in line of sight"

-- action bars / spellbook / macros / cursor (ArenaFrames 3.19 bars save / load)
ACTIONS, BOOK, MACROS, CURSOR = {}, {}, {}, nil
BOOKTYPE_SPELL = "spell"
function GetActionInfo(slot)
  local a = ACTIONS[slot]
  if not a then return nil end
  return a[1], a[2], a[3]
end
function GetSpellName(i) local e = BOOK[i]; if e then return e[1], e[2] end end
function GetNumMacros()
  local g, c = 0, 0
  for i in pairs(MACROS) do if i <= 36 then g = g + 1 else c = c + 1 end end
  return g, c
end
function GetMacroInfo(i) local m = MACROS[i]; if m then return m[1], "icon", m[2] end end
function PickupSpell(i) CURSOR = { "spell", i, "spell" } end
function PickupMacro(i) CURSOR = { "macro", i } end
function PickupItem(id) CURSOR = { "item", id } end
function PickupAction(slot) CURSOR = ACTIONS[slot]; ACTIONS[slot] = nil end
function PlaceAction(slot) local old = ACTIONS[slot]; ACTIONS[slot] = CURSOR; CURSOR = old end
function ClearCursor() CURSOR = nil end
function GetCursorInfo() return CURSOR and CURSOR[1] end
function CursorHasSpell() return B(CURSOR and CURSOR[1] == "spell") end
function CursorHasMacro() return B(CURSOR and CURSOR[1] == "macro") end
function CursorHasItem() return B(CURSOR and CURSOR[1] == "item") end
