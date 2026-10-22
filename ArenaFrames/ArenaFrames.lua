--[[
  ArenaFrames 3.0  -  WoW 3.3.5a (Warmane-safe, display only)

  Slim enemy arena frames, one row per arena1-5:
    ...[DR][DR][class icon][ class-colored health bar: "1 Name"   58% ][trinket]

  * Health: arena unit health, class colored. Dimmed when the enemy is stealthed /
    out of sight (last known values kept), grey "DEAD" when dead.
  * Trinket: faction PvP trinket icon; 2 min cooldown sweep + timer after PvP Trinket
    or Every Man for Himself (combat log, plus UNIT_SPELLCAST_SUCCEEDED as backup).
  * Enemy cooldowns: a movable bar near the middle; when an enemy uses a tracked cooldown
    (ArenaFrames_Cooldowns in DRList.lua) its icon shows with the time left, newest first,
    border by kind (blue interrupt, purple CC, green defensive, red offensive...), arena
    number in the corner. Arena: arena enemies; elsewhere: hostile players + attackable
    target/focus.
  * Spec: worked out from spells / auras / pets only one spec has (no API for it on 3.3.5),
    shown under the name ("Subtlety", or "Subtlety?" while the evidence is thin).
  * DR: one icon per diminishing-return category (DRList.lua) with the last CC's icon.
    Border = what the NEXT CC of that category does: green half, yellow quarter,
    red immune. The timer runs once the CC ends; DR resets 18 s later. Each icon fades
    in when its DR starts and fades out when it resets.

  * Click a row: left = target that enemy, right = focus. Done by an invisible secure
    button over each row (arena1-5), shown by the game itself while that enemy exists;
    its position follows the frames' saved layout, applied out of combat only.
    (The separate target/focus DR display near the screen center was removed in 3.7.)

  Commands:
    /aframes              help + settings
    /aframes test         toggle fake frames + drag handle to position them
    /aframes unlock|lock  same as test: unlock = show + make everything draggable
    /aframes debug        what each arena unit / trinket / DR looks like right now
    /aframes scale 1      0.5-2
    /aframes width 200    health bar width incl. class icon, 120-400
    /aframes height 36    row height (= trinket size), 20-64
    /aframes ufscale 1       player/target/focus frames scale, 0.5-2
    /aframes uf on|off       use our player/target/focus frames instead of Blizzard's (/reload)
    /aframes reset        defaults (and position)
]]

local ADDON = "ArenaFrames"
local VERSION = "3.21.1"
local DEFAULTS = { scale = 1, width = 200, height = 36, point = "LEFT", x = 250, y = 120,
  cdbar = true, cdsize = 32, cdpoint = "CENTER", cdx = 0, cdy = -230, names = false, range = true,
  bigcd = true, bigsound = true, bpoint = "CENTER", bx = 0, by = 60 }
local UPDATE_INTERVAL = 0.1
local DR_RESET = 18          -- seconds after a CC ends until its DR is gone (15-20 on WotLK servers)
local DR_MAX_ACTIVE = 10     -- if the CC's end is never seen (out of range), give up after this
local TRINKET_CD = 120
local SPACING = 8
local MAX_DR = 6
local MAX_CD_ICONS = 14   -- enemy cooldown bar
local FADE_TIME = 0.4     -- seconds for a DR icon to fade in / out

local FLAT = [[Interface\Buttons\WHITE8X8]]
local FONT = [[Fonts\FRIZQT__.TTF]]
local CLASS_TEX = [[Interface\Glues\CharacterCreate\UI-CharacterCreate-Classes]]
local TRINKET_ICON = {
  Alliance = [[Interface\Icons\INV_Jewelry_TrinketPVP_01]],
  Horde = [[Interface\Icons\INV_Jewelry_TrinketPVP_02]],
}
local UNKNOWN_ICON = [[Interface\Icons\INV_Misc_QuestionMark]]
local TRINKET_SPELLS = { [42292] = true, [59752] = true }   -- PvP Trinket, Every Man for Himself

local CLASS_COORDS = {
  WARRIOR = { 0, 0.25, 0, 0.25 },          MAGE = { 0.25, 0.49609375, 0, 0.25 },
  ROGUE = { 0.49609375, 0.7421875, 0, 0.25 }, DRUID = { 0.7421875, 0.98828125, 0, 0.25 },
  HUNTER = { 0, 0.25, 0.25, 0.5 },         SHAMAN = { 0.25, 0.49609375, 0.25, 0.5 },
  PRIEST = { 0.49609375, 0.7421875, 0.25, 0.5 }, WARLOCK = { 0.7421875, 0.98828125, 0.25, 0.5 },
  PALADIN = { 0, 0.25, 0.5, 0.75 },        DEATHKNIGHT = { 0.25, 0.49609375, 0.5, 0.75 },
}
local CLASS_COLORS = {   -- fallback if RAID_CLASS_COLORS is missing
  WARRIOR = { 0.78, 0.61, 0.43 }, MAGE = { 0.41, 0.80, 0.94 }, ROGUE = { 1.00, 0.96, 0.41 },
  DRUID = { 1.00, 0.49, 0.04 }, HUNTER = { 0.67, 0.83, 0.45 }, SHAMAN = { 0.00, 0.44, 0.87 },
  PRIEST = { 1.00, 1.00, 1.00 }, WARLOCK = { 0.58, 0.51, 0.79 }, PALADIN = { 0.96, 0.55, 0.73 },
  DEATHKNIGHT = { 0.77, 0.12, 0.23 },
}
-- border color by DR level: 1 = next is half, 2 = quarter, 3 = immune
local DR_COLORS = { { 0.1, 0.9, 0.1 }, { 1, 0.85, 0 }, { 1, 0.1, 0.1 } }

local band = bit.band
local TYPE_PLAYER = 0x00000400

local DR = ArenaFrames_DR
local db
local anchor
local clickHolder        -- mirrors the anchor's layout; parent of the secure click buttons
local clickButtons = {}  -- [1..5] SecureUnitButtons over the rows (arena1-5)
local petButtons = {}    -- [1..5] SecureUnitButtons over the pet bars (arenapet1-5), 3.12
local clickPending       -- layout / setup waiting for the end of combat
local rows = {}          -- [1..5] row widgets
local slots = {}         -- [1..5] last known info about arenaN
local trinketUsed = {}   -- [guid] = GetTime() of last trinket
local drState = {}       -- [guid] = { [category] = { count, active, resetAt, endedAt, startedAt, icon, spell } }
local drByName = {}      -- [spell name] = category
local trinketNames = {}  -- [spell name] = true
local unknownDebuffs = {}-- recent debuffs on arena enemies that aren't in the DR list (for debug)
local lockouts = {}      -- [guid] = { start, dur, icon, spell } school lockout after an interrupt
local specState = {}     -- [guid] = { score = { [spec] = n }, seen = { [entry] = true }, hints = {}, spec = }
local specById, specByName = {}, {}   -- from ArenaFrames_Specs (DRList.lua)
local cdById, cdByName = {}, {}       -- from ArenaFrames_Cooldowns (DRList.lua)
local cdUsed = {}        -- [guid] = { [entry] = { start, dur } } cooldowns someone used
local cdInfo = {}        -- [guid] = { name, hostile } who that is, from the combat log
local cdSeen = {}        -- [guid] = { [entry] = true } ever used (talent cooldowns show once seen)
local cdBar              -- enemy cooldown bar (mover); cdBar.icons
local inArena, testMode = false, false

-- shared with the target/focus frame code at the end of this file
local NS = {}
ArenaFrames_NS = NS

local function Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cffffd200ArenaFrames:|r " .. msg)
end

local function ClassColor(class)
  local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  if c then return c.r, c.g, c.b end
  c = CLASS_COLORS[class]
  if c then return c[1], c[2], c[3] end
  return 0.5, 0.5, 0.5
end

local function FormatTime(s)
  if s >= 60 then return string.format("%d:%02d", math.floor(s / 60), math.floor(s % 60)) end
  return tostring(math.ceil(s))
end

------------------------------------------------------------------ widgets --

local function SetBorder(f, r, g, b)
  f:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
  f:SetBackdropColor(0, 0, 0, 0.6)
  f:SetBackdropBorderColor(r or 0, g or 0, b or 0, 1)
end

local function NewText(parent, size, justify)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFont(FONT, size, "OUTLINE")
  fs:SetJustifyH(justify or "CENTER")
  return fs
end

-- square icon with a 1px border, a cooldown sweep and a timer text
local function NewIcon(parent)
  local b = CreateFrame("Frame", nil, parent)
  SetBorder(b)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
  b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
  b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  b.cd = CreateFrame("Cooldown", nil, b)
  b.cd:SetAllPoints(b.icon)
  b.cd:Hide()
  local over = CreateFrame("Frame", nil, b)     -- keeps the text above the sweep
  over:SetAllPoints(b)
  over:SetFrameLevel(b:GetFrameLevel() + 3)
  b.over = over
  b.text = NewText(over, 14)
  b.text:SetPoint("CENTER", over, "CENTER", 0, 0)
  return b
end

local function FadeStep(self, elapsed)
  local a, t = self.alpha, self.target
  local step = elapsed / FADE_TIME
  if a < t then a = math.min(t, a + step) else a = math.max(t, a - step) end
  self.alpha = a
  self:SetAlpha(a)
  if a == t then
    self.fading = nil
    self:SetScript("OnUpdate", nil)
  end
end

-- fade an icon's alpha toward target (0 or 1) over FADE_TIME, driven by its own OnUpdate
local function FadeTo(b, target)
  if b.target == target and (b.fading or b.alpha == target) then return end
  b.target = target
  if b.alpha == target then return end
  b.fading = true
  b:SetScript("OnUpdate", FadeStep)
end

local function SetCooldown(b, start, duration)
  if b.cdStart == start then return end
  b.cdStart = start
  if start then
    b.cd:SetCooldown(start, duration)
    b.cd:Show()
  else
    b.cd:Hide()
  end
end

-- holder.drs[1..MAX_DR]: DR icons, filled by RenderDRs
local function AddDRIcons(holder, fontSize)
  holder.drs = {}
  holder.prevAlpha = {}
  for k = 1, MAX_DR do
    local d = NewIcon(holder)
    d.text:SetFont(FONT, fontSize, "OUTLINE")
    d.alpha = 0
    d:Hide()
    holder.drs[k] = d
  end
end

-- 3.11 (owner's sArena screenshots: "make it look like this"): one row =
--   [DRs] [class / CC square] [health bar over a thin power bar with the spec] [trinket] [racial] [cast bar]
--   and under the bar the cooldowns that enemy used, with their timers.
-- No name / % on the bar (/aframes names on brings them back); the skull marks the kill target.
local MAX_USED = 6        -- used-cooldown icons under each row
local POWER_COLORS_ROW = { [0] = { 0.25, 0.45, 1 }, [1] = { 1, 0.2, 0.2 }, [3] = { 1, 0.85, 0.1 },
  [6] = { 0, 0.82, 1 } }

local function RowGap(h) return math.floor(h * 0.6) + 8 end   -- room for the used-cooldown icons

local function CreateRow(i)
  local f = CreateFrame("Frame", "ArenaFramesRow" .. i, anchor)
  f.index = i
  SetBorder(f)
  f:Hide()

  -- class / CC square, left of the bar
  f.classBox = CreateFrame("Frame", nil, f)
  f.classBox:SetPoint("RIGHT", f, "LEFT", -3, 0)
  SetBorder(f.classBox)
  f.class = f.classBox:CreateTexture(nil, "ARTWORK")
  f.class:SetPoint("TOPLEFT", f.classBox, "TOPLEFT", 1, -1)
  f.class:SetPoint("BOTTOMRIGHT", f.classBox, "BOTTOMRIGHT", -1, 1)
  f.cc = f.classBox:CreateTexture(nil, "OVERLAY")
  f.cc:SetAllPoints(f.class)
  f.cc:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  f.cc:Hide()
  f.ccText = NewText(f.classBox, 16, "CENTER")
  f.ccText:SetPoint("CENTER", f.classBox, "CENTER", 0, 0)
  f.ccText:SetTextColor(1, 0.9, 0.1)

  f.hp = CreateFrame("StatusBar", nil, f)
  f.hp:SetStatusBarTexture(FLAT)
  f.hp:SetMinMaxValues(0, 1)
  f.hp:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
  f.hp:SetPoint("RIGHT", f, "RIGHT", -1, 0)
  f.hpBg = f.hp:CreateTexture(nil, "BACKGROUND")
  f.hpBg:SetAllPoints(f.hp)
  f.hpBg:SetTexture(0.12, 0.12, 0.12, 0.9)
  f.gloss = f.hp:CreateTexture(nil, "OVERLAY")    -- soft top light so the flat bar has some depth
  f.gloss:SetAllPoints(f.hp)
  f.gloss:SetTexture(FLAT)
  f.gloss:SetGradientAlpha("VERTICAL", 0, 0, 0, 0.25, 1, 1, 1, 0.12)

  f.power = CreateFrame("StatusBar", nil, f)
  f.power:SetStatusBarTexture(FLAT)
  f.power:SetMinMaxValues(0, 1)
  f.power:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 1)
  f.power:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
  local pbg = f.power:CreateTexture(nil, "BACKGROUND")
  pbg:SetAllPoints(f.power)
  pbg:SetTexture(0.12, 0.12, 0.12, 0.9)
  f.spec = NewText(f.power, 9, "LEFT")            -- the spec, on the power bar
  f.spec:SetPoint("LEFT", f.power, "LEFT", 3, 0)
  f.spec:SetTextColor(1, 1, 1)
  f.spec:Hide()

  f.name = NewText(f.hp, 12, "LEFT")              -- only with /aframes names on
  f.name:SetPoint("LEFT", f.hp, "LEFT", 5, 0)
  f.pct = NewText(f.hp, 12, "RIGHT")
  f.pct:SetPoint("RIGHT", f.hp, "RIGHT", -5, 0)

  f.trinket = NewIcon(f)
  f.trinket:SetPoint("LEFT", f, "RIGHT", 3, 0)
  f.trinket.text:SetTextColor(1, 0.9, 0.1)
  f.racial = NewIcon(f)
  f.racial:SetPoint("LEFT", f.trinket, "RIGHT", 3, 0)
  f.racial.text:SetTextColor(1, 0.9, 0.1)
  f.racial:Hide()

  -- their cast, right of the trinket / racial
  f.cast = CreateFrame("StatusBar", nil, f)
  f.cast:SetStatusBarTexture(FLAT)
  f.cast:SetMinMaxValues(0, 1)
  SetBorder(f.cast)
  f.cast.icon = f.cast:CreateTexture(nil, "OVERLAY")
  f.cast.icon:SetPoint("RIGHT", f.cast, "LEFT", -1, 0)
  f.cast.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  f.cast.text = NewText(f.cast, 10, "LEFT")
  f.cast.text:SetPoint("LEFT", f.cast, "LEFT", 3, 0)
  f.cast.time = NewText(f.cast, 10, "RIGHT")
  f.cast.time:SetPoint("RIGHT", f.cast, "RIGHT", -3, 0)
  f.cast:Hide()

  -- 3.12: their pet (felhunter, ghoul, water elemental, hunter pet) under the trinket / racial
  f.pet = CreateFrame("StatusBar", nil, f)
  f.pet:SetStatusBarTexture(FLAT)
  f.pet:SetMinMaxValues(0, 1)
  SetBorder(f.pet)
  f.pet.text = NewText(f.pet, 9, "LEFT")
  f.pet.text:SetPoint("LEFT", f.pet, "LEFT", 2, 0)
  f.pet:Hide()

  -- the cooldowns this enemy used, under the bar
  f.used = {}
  for k = 1, MAX_USED do
    local b = NewIcon(f)
    b.text:SetFont(FONT, 10, "OUTLINE")
    b:Hide()
    f.used[k] = b
  end

  -- 3.10: the suggested kill target. 3.10.1 (owner: "skull doesn't appear or I couldn't see it"):
  -- a thick red outline around the whole row + a bigger skull
  f.killGlow = CreateFrame("Frame", nil, f)
  f.killGlow:SetPoint("TOPLEFT", f, "TOPLEFT", -3, 3)
  f.killGlow:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 3, -3)
  f.killGlow:SetBackdrop({ edgeFile = FLAT, edgeSize = 3 })
  f.killGlow:SetBackdropBorderColor(1, 0.1, 0.1, 1)
  f.killGlow:Hide()
  f.kill = f.hp:CreateTexture(nil, "OVERLAY")
  f.kill:SetTexture([[Interface\TargetingFrame\UI-RaidTargetingIcon_8]])
  f.kill:SetPoint("CENTER", f.hp, "CENTER", 0, 0)
  f.kill:Hide()

  AddDRIcons(f, 11)
  rows[i] = f
  return f
end

-- Clickable rows (owner: "right click focus"): an invisible SecureUnitButton over each row,
-- left = target, right = focus. RegisterUnitWatch shows it only while arenaN exists (secure
-- code, so it also works in combat). The rows stay plain frames: anchoring a protected frame
-- to them would make them protected too, and they show / hide / fade in combat. So the
-- buttons hang off their own holder that copies the anchor's point / scale / width, and
-- every holder / button change waits for the end of combat.
local function ApplyClickLayout()
  if not clickHolder or InCombatLockdown() then clickPending = true; return end
  clickPending = nil
  clickHolder:ClearAllPoints()
  clickHolder:SetPoint(db.point, UIParent, db.point, db.x, db.y)
  clickHolder:SetScale(db.scale)
  clickHolder:SetWidth(db.width)
  clickHolder:SetHeight(16)
  local h = db.height
  for i, b in ipairs(clickButtons) do
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", clickHolder, "BOTTOMLEFT", 0, -2 - (i - 1) * (h + RowGap(h)))
    b:SetWidth(db.width)
    b:SetHeight(h)
  end
  for i, b in ipairs(petButtons) do                -- same spot as the row's pet bar
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", clickHolder, "BOTTOMLEFT", db.width + 3, -2 - (i - 1) * (h + RowGap(h)) - h - 3)
    b:SetWidth(2 * h + 3)
    b:SetHeight(12)
  end
end

local function CreateClickButtons()
  if clickHolder then return ApplyClickLayout() end
  if InCombatLockdown() then clickPending = true; return end   -- e.g. /reload in combat
  clickHolder = CreateFrame("Frame", "ArenaFramesClickHolder", UIParent)
  clickHolder:SetFrameLevel(anchor:GetFrameLevel() + 10)       -- highlight above the bars
  for i = 1, 5 do
    local b = CreateFrame("Button", "ArenaFramesClick" .. i, clickHolder, "SecureUnitButtonTemplate")
    b:SetAttribute("unit", "arena" .. i)
    b:SetAttribute("*type1", "target")
    b:SetAttribute("*type2", "focus")
    b:RegisterForClicks("AnyUp")
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(b)
    hl:SetTexture(1, 1, 1, 0.12)
    b:Hide()
    RegisterUnitWatch(b)
    clickButtons[i] = b
    local p = CreateFrame("Button", "ArenaFramesPetClick" .. i, clickHolder, "SecureUnitButtonTemplate")
    p:SetAttribute("unit", "arenapet" .. i)
    p:SetAttribute("*type1", "target")
    p:SetAttribute("*type2", "focus")
    p:RegisterForClicks("AnyUp")
    local phl = p:CreateTexture(nil, "HIGHLIGHT")
    phl:SetAllPoints(p)
    phl:SetTexture(1, 1, 1, 0.15)
    p:Hide()
    RegisterUnitWatch(p)
    petButtons[i] = p
  end
  ApplyClickLayout()
end

local function ApplyLayout()
  anchor:ClearAllPoints()
  anchor:SetPoint(db.point, UIParent, db.point, db.x, db.y)
  anchor:SetScale(db.scale)
  anchor:SetWidth(db.width)
  anchor:SetHeight(16)
  local h = db.height
  for i = 1, 5 do
    local f = rows[i]
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2 - (i - 1) * (h + RowGap(h)))
    f:SetWidth(db.width)
    f:SetHeight(h)
    f.classBox:SetWidth(h); f.classBox:SetHeight(h)
    f.ccText:SetFont(FONT, math.floor(h * 0.45), "OUTLINE")
    local ph = math.max(6, math.floor(h * 0.28))
    f.power:SetHeight(ph)
    f.hp:SetPoint("BOTTOM", f.power, "TOP", 0, 1)
    f.trinket:SetWidth(h)
    f.trinket:SetHeight(h)
    f.trinket.text:SetFont(FONT, math.floor(h * 0.4), "OUTLINE")
    f.racial:SetWidth(h); f.racial:SetHeight(h)
    f.racial.text:SetFont(FONT, math.floor(h * 0.4), "OUTLINE")
    f.cast:SetWidth(110); f.cast:SetHeight(math.floor(h * 0.5))
    f.cast.icon:SetWidth(math.floor(h * 0.5)); f.cast.icon:SetHeight(math.floor(h * 0.5))
    f.kill:SetWidth(h - 6)
    f.kill:SetHeight(h - 6)
    f.pet:ClearAllPoints()
    f.pet:SetPoint("TOPLEFT", f.trinket, "BOTTOMLEFT", 0, -3)
    f.pet:SetWidth(2 * h + 3); f.pet:SetHeight(12)
    local us = math.floor(h * 0.6)
    for k, b in ipairs(f.used) do
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", f, "BOTTOMLEFT", (k - 1) * (us + 2), -3)
      b:SetWidth(us); b:SetHeight(us)
    end
    local ds = math.floor(h * 0.8 + 0.5)
    for k = 1, MAX_DR do
      local d = f.drs[k]
      d:ClearAllPoints()
      -- DRs grow leftwards from the class square; the oldest DR sits next to it
      d:SetPoint("RIGHT", k == 1 and f.classBox or f.drs[k - 1], "LEFT", -3, 0)
      d:SetWidth(ds)
      d:SetHeight(ds)
    end
  end
  ApplyClickLayout()
end

local function ApplyCooldownLayout()
  cdBar:ClearAllPoints()
  cdBar:SetPoint(db.cdpoint, UIParent, db.cdpoint, db.cdx, db.cdy)
  cdBar:SetWidth(200)
  cdBar:SetHeight(16)
  local size = db.cdsize
  for k, b in ipairs(cdBar.icons) do
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", cdBar, "BOTTOMLEFT", (k - 1) * (size + 3), -4)
    b:SetWidth(size)
    b:SetHeight(size)
    b.text:SetFont(FONT, math.floor(size * 0.45 + 0.5), "OUTLINE")
  end
end

-- a frame with a dark "drag to move" handle (shown in test mode) that saves its position
local function NewMover(name, text, keyPoint, keyX, keyY)
  local m = CreateFrame("Frame", name, UIParent)
  m:SetMovable(true)
  m:SetClampedToScreen(true)
  m:EnableMouse(true)
  m:RegisterForDrag("LeftButton")
  m:SetScript("OnDragStart", function(self) self:StartMoving() end)
  m:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, _, x, y = self:GetPoint()
    db[keyPoint], db[keyX], db[keyY] = point, math.floor(x + 0.5), math.floor(y + 0.5)
  end)
  m.bg = m:CreateTexture(nil, "BACKGROUND")
  m.bg:SetAllPoints(m)
  m.bg:SetTexture(0, 0, 0, 0.7)
  m.label = NewText(m, 11)
  m.label:SetPoint("CENTER", m, "CENTER", 0, 0)
  m.label:SetText(text)
  return m
end

local function CreateAnchor()
  anchor = NewMover("ArenaFramesAnchor", "ArenaFrames - drag to move", "point", "x", "y")
  anchor:HookScript("OnDragStop", function() ApplyClickLayout() end)
  for i = 1, 5 do CreateRow(i) end

  cdBar = NewMover("ArenaFramesCooldowns", "Enemy cooldowns - drag", "cdpoint", "cdx", "cdy")
  cdBar.icons = {}
  for k = 1, MAX_CD_ICONS do
    local b = NewIcon(cdBar)
    b.badge = NewText(b.over, 10, "LEFT")      -- arena number of who used it
    b.badge:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
    b:Hide()
    cdBar.icons[k] = b
  end
end

-------------------------------------------------------------- data model --

local function DRCategory(spellId, spellName)
  return DR.SPELLS[spellId] or (spellName and drByName[spellName])
end

local function BuildNameMaps()
  local blocked = {}
  for id in pairs(DR.NO_NAME_MATCH) do
    local name = GetSpellInfo(id)
    if name then blocked[name] = true end
  end
  for id, cat in pairs(DR.SPELLS) do
    local name = GetSpellInfo(id)
    if name and not blocked[name] then
      if drByName[name] and drByName[name] ~= cat then blocked[name] = true end
      drByName[name] = cat
    end
  end
  for name in pairs(blocked) do drByName[name] = nil end
  for id in pairs(TRINKET_SPELLS) do
    local name = GetSpellInfo(id)
    if name then trinketNames[name] = true end
  end
end

local function TrinketUsed(guid)
  local now = GetTime()
  local last = trinketUsed[guid]
  if last and now - last < 2 then return end   -- same use seen by the log and the cast event
  trinketUsed[guid] = now
end

local function DRApplied(guid, cat, spellId)
  local now = GetTime()
  local byCat = drState[guid]
  if not byCat then byCat = {}; drState[guid] = byCat end
  local s = byCat[cat]
  if not s or now >= s.resetAt then
    s = { count = 0, startedAt = now }
    byCat[cat] = s
  end
  s.count = math.min(s.count + 1, 3)
  s.active = true
  s.endedAt = nil
  s.resetAt = now + DR_MAX_ACTIVE + DR_RESET
  s.spell = spellId
  s.icon = select(3, GetSpellInfo(spellId)) or s.icon or UNKNOWN_ICON
end

local function DRRemoved(guid, cat)
  local s = drState[guid] and drState[guid][cat]
  if not s then return end
  local now = GetTime()
  s.active = false
  s.endedAt = now
  s.resetAt = now + DR_RESET
end

local function NoteUnknown(spellId, spellName)
  for i = 1, #unknownDebuffs do
    if unknownDebuffs[i].id == spellId then return end
  end
  table.insert(unknownDebuffs, 1, { id = spellId, name = spellName })
  if #unknownDebuffs > 8 then table.remove(unknownDebuffs) end
end

local function IsArenaGUID(guid)
  for i = 1, 5 do
    if slots[i] and slots[i].guid == guid then return true end
  end
  return false
end

---------------------------------------------------------------- specs --
-- 3.3.5 has no API for an enemy's spec: it's inferred from spells, auras and pets only one
-- spec has (ArenaFrames_Specs in DRList.lua). Each spell counts once with its weight; the
-- spec with the most points wins. Below 2 points it's shown with a "?".

local function BuildSpecMaps()
  for _, e in ipairs(ArenaFrames_Specs or {}) do
    local names = {}
    if e.name then names[e.name] = true end
    for _, id in ipairs(e.ids) do
      specById[id] = e
      local name = GetSpellInfo(id)
      if name then names[name] = true end
    end
    for name in pairs(names) do
      specByName[name] = specByName[name] or {}
      specByName[name][e] = true
    end
  end
end

local function ArenaIndexOf(guid)
  if not guid then return nil end
  for i = 1, 5 do
    local s = slots[i]
    if s and (s.guid == guid or s.petGuid == guid) then return i end
  end
end

local function SpecEvidence(i, spellId, spellName)
  local s = slots[i]
  if not (s and s.guid and s.class) then return end
  local e = spellId and specById[spellId]
  if not (e and e.class == s.class) then
    e = nil
    for cand in pairs(spellName and specByName[spellName] or {}) do
      if cand.class == s.class then e = cand; break end
    end
  end
  if not e then return end
  local st = specState[s.guid]
  if not st then st = { score = {}, seen = {}, hints = {} }; specState[s.guid] = st end
  if st.seen[e] then return end
  st.seen[e] = true
  st.score[e.spec] = (st.score[e.spec] or 0) + e.weight
  table.insert(st.hints, e.name)
  for spec, n in pairs(st.score) do
    if not st.spec or n > st.score[st.spec] then st.spec = spec end
  end
end

-- auras the arena enemies carry (forms, Earth Shield on a teammate...), credited to the caster
local function ScanSpecAuras(unit)
  for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
    for k = 1, 40 do
      local name, _, _, _, _, _, _, caster, _, _, spellId = UnitAura(unit, k, filter)
      if not name then break end
      if caster then
        for i = 1, 5 do
          if UnitIsUnit(caster, "arena" .. i) or UnitIsUnit(caster, "arenapet" .. i) then
            SpecEvidence(i, spellId, name)
            break
          end
        end
      end
    end
  end
end

------------------------------------------------------------ cooldowns --
-- Who used which tracked cooldown, for the enemy cooldown bar and the party icons.

local REACTION_HOSTILE, TYPE_PET_OR_GUARDIAN = 0x00000040, 0x00001000 + 0x00002000

-- PvP Trinket's own spell icon (42292) looks like Dispel Magic: use the faction trinket instead
local function SetTrinketIcons()
  local icon = TRINKET_ICON[UnitFactionGroup("player") or ""] or TRINKET_ICON.Alliance
  for _, e in ipairs(ArenaFrames_Cooldowns or {}) do
    if e.trinket then e.icon = icon end
  end
end

local function BuildCooldownMaps()
  local byName = {}
  for _, e in ipairs(ArenaFrames_Cooldowns or {}) do
    byName[e.name] = byName[e.name] or e          -- Nature's Swiftness: druid and shaman
    for _, id in ipairs(e.ids) do
      cdById[id] = e
      local name = GetSpellInfo(id)
      if name then cdByName[name] = cdByName[name] or e end
    end
    e.icon = select(3, GetSpellInfo(e.ids[1])) or UNKNOWN_ICON
  end
  SetTrinketIcons()
  for _, e in ipairs(ArenaFrames_Cooldowns or {}) do
    e.shared = {}
    for _, n in ipairs(e.shares or {}) do
      if byName[n] then table.insert(e.shared, byName[n]) end
    end
  end
  NS.cooldownsByName = byName
  NS.racialByRace = {}
  for _, e in ipairs(ArenaFrames_Cooldowns or {}) do
    if e.race and not NS.racialByRace[e.race] then NS.racialByRace[e.race] = e end
  end
  -- per class, everyone's (trinket) first, in the list's order
  local byClass = { ANY = {} }
  for class in pairs(CLASS_COORDS) do byClass[class] = {} end
  for _, e in ipairs(ArenaFrames_Cooldowns or {}) do
    if e.class == "ANY" then
      for _, list in pairs(byClass) do table.insert(list, e) end
    end
  end
  for _, e in ipairs(ArenaFrames_Cooldowns or {}) do
    if e.class ~= "ANY" and byClass[e.class] then table.insert(byClass[e.class], e) end
  end
  NS.cooldownsByClass = byClass
end

local function UseCooldown(guid, e, now)
  local byE = cdUsed[guid]
  if not byE then byE = {}; cdUsed[guid] = byE end
  byE[e] = { start = now, dur = e.cd }
  cdSeen[guid] = cdSeen[guid] or {}
  cdSeen[guid][e] = true
  for _, o in ipairs(e.shared) do                  -- e.g. PvP Trinket <-> Every Man for Himself
    local cur, dur = byE[o], math.min(e.cd, o.cd)
    if not cur or cur.start + cur.dur < now + dur then byE[o] = { start = now, dur = dur, shared = true } end
  end
end

-- a pet's spell (Spell Lock, Intimidation...) belongs to its owner
local function OwnerOfPet(petGUID)
  if not petGUID then return nil end
  if petGUID == UnitGUID("pet") then return UnitGUID("player") end
  for i = 1, 5 do
    if slots[i] and slots[i].petGuid == petGUID then return slots[i].guid end
  end
  for i = 1, 4 do
    if UnitGUID("partypet" .. i) == petGUID then return UnitGUID("party" .. i) end
  end
end

local function TrackCooldown(event, srcGUID, srcName, srcFlags, spellId, spellName)
  if not srcFlags then return end
  local isPlayer = band(srcFlags, TYPE_PLAYER) ~= 0
  -- by name only for players (unknown rank); pets share names (a gorilla's Pummel, a pet's Charge)
  local e = cdById[spellId] or (isPlayer and spellName and cdByName[spellName])
  if not e or (e.event or "SPELL_CAST_SUCCESS") ~= event then return end
  local guid = srcGUID
  if not isPlayer then
    if band(srcFlags, TYPE_PET_OR_GUARDIAN) == 0 then return end
    guid = OwnerOfPet(srcGUID)
    if not guid then return end
  end
  UseCooldown(guid, e, GetTime())
  local info = cdInfo[guid]
  if not info then info = {}; cdInfo[guid] = info end
  if guid == srcGUID then info.name = srcName end
  info.hostile = band(srcFlags, REACTION_HOSTILE) ~= 0
  if NS.BigCD then NS.BigCD.Used(guid, e, info.hostile) end
end

-- [entry] = { start, dur } of the cooldowns this player has running (for other addons too)
function ArenaFrames_ActiveCooldowns(guid)
  return guid and cdUsed[guid]
end

local NO_FLASH = { ["Auto Shot"] = true, Shoot = true, ["Throw"] = true }   -- every few seconds, not news
local SPELL_FLASH = 1.5

local function OnCombatLog(_, event, srcGUID, srcName, srcFlags, dstGUID, _, dstFlags, spellId, spellName, _, auraType)
  if spellId then TrackCooldown(event, srcGUID, srcName, srcFlags, spellId, spellName) end
  if inArena and spellId and event:sub(1, 6) == "SPELL_" then
    local i = ArenaIndexOf(srcGUID)               -- the enemy or its pet did something
    if i then
      SpecEvidence(i, spellId, spellName)
      -- 3.13 (owner: "show all the spells they're using, dispel, frost nova..."): flash it in the class square
      if event == "SPELL_CAST_SUCCESS" and slots[i] and not NO_FLASH[spellName or ""] then
        slots[i].lastSpell = { icon = select(3, GetSpellInfo(spellId)) or UNKNOWN_ICON, t = GetTime() }
      end
    end
  end
  if event == "SPELL_INTERRUPT" then
    local dur = ArenaFrames_Auras and ArenaFrames_Auras.LOCKOUT[spellId]
    if dur and dstGUID then
      lockouts[dstGUID] = { start = GetTime(), dur = dur, spell = spellId,
        icon = select(3, GetSpellInfo(spellId)) or UNKNOWN_ICON }
    end
    return
  end
  if event == "SPELL_CAST_SUCCESS" then
    if TRINKET_SPELLS[spellId] then TrinketUsed(srcGUID) end
    return
  end
  if auraType ~= "DEBUFF" or not dstFlags or band(dstFlags, TYPE_PLAYER) == 0 then return end
  if event == "SPELL_AURA_APPLIED" or event == "SPELL_AURA_REFRESH" then
    local cat = DRCategory(spellId, spellName)
    if cat then
      DRApplied(dstGUID, cat, spellId)
    elseif IsArenaGUID(dstGUID) then
      NoteUnknown(spellId, spellName)
    end
  elseif event == "SPELL_AURA_REMOVED" then
    local cat = DRCategory(spellId, spellName)
    if cat then DRRemoved(dstGUID, cat) end
  end
end

local function ResetMatch()
  for i = 1, 5 do slots[i] = nil end
  wipe(trinketUsed)
  wipe(drState)
  wipe(lockouts)
  wipe(unknownDebuffs)
  wipe(specState)
  wipe(cdUsed)
  wipe(cdInfo)
  wipe(cdSeen)
end

-- Read arena1-5 into slots. A unit that disappears (stealth, out of sight) keeps its
-- slot with the last known values and is shown dimmed.
local function ReadUnits()
  for i = 1, 5 do
    local unit = "arena" .. i
    if UnitExists(unit) then
      local s = slots[i] or {}
      slots[i] = s
      local guid = UnitGUID(unit)
      if guid ~= s.guid then s.specScanAt, s.ccScanAt = nil, nil end   -- someone else in this slot: scan now
      s.guid = guid
      s.petGuid = UnitGUID("arenapet" .. i)
      s.name = UnitName(unit)
      s.class = select(2, UnitClass(unit))
      s.faction = UnitFactionGroup(unit)
      s.race = select(2, UnitRace(unit))
      s.power, s.maxpower, s.ptype = UnitPower(unit), UnitPowerMax(unit), UnitPowerType(unit)
      s.hp, s.maxhp = UnitHealth(unit), UnitHealthMax(unit)
      s.dead = UnitIsDeadOrGhost(unit) and true or false
      s.visible = true
      -- passive spec auras (Moonkin Aura, Trueshot Aura, Rampage...) only fire UNIT_AURA when
      -- they change: look again every 2 s while the spec isn't sure yet
      local st = specState[s.guid]
      local now = GetTime()
      if inArena and not (st and st.spec and st.score[st.spec] >= 3) and now >= (s.specScanAt or 0) then
        s.specScanAt = now + 2
        ScanSpecAuras(unit)
      end
      if now >= (s.ccScanAt or 0) and NS.ScanCC then     -- UNIT_AURA rescans too; this is the fallback
        s.ccScanAt = now + 1
        s.cc = NS.ScanCC(unit)
      end
    elseif slots[i] then
      slots[i].visible = false
    end
  end
end

----------------------------------------------------------------- render --

-- DRs of one enemy, oldest first. With fading, DRs that just reset stay listed for
-- FADE_TIME so their icon can fade out in place.
local function ActiveDRs(guid, now, fading)
  local list = {}
  local byCat = drState[guid]
  local until_ = fading and FADE_TIME or 0
  if byCat then
    for cat, s in pairs(byCat) do
      if now < s.resetAt + until_ then table.insert(list, { cat = cat, s = s }) end
    end
    table.sort(list, function(a, b) return a.s.startedAt < b.s.startedAt end)
  end
  return list
end

-- Fill holder.drs with one unit's DRs. Each icon fades in when its DR starts and out
-- when it resets. When an older DR goes away the others slide one slot over; an icon
-- that only moved keeps its alpha instead of fading in again. Returns the icon count.
local function RenderDRs(holder, guid, now)
  local list = guid and ActiveDRs(guid, now, true) or {}
  local prevAlpha = holder.prevAlpha
  wipe(prevAlpha)
  for k = 1, MAX_DR do
    local d = holder.drs[k]
    if d.key and d._shownKey then prevAlpha[d.key] = d.alpha end
  end
  for k = 1, MAX_DR do
    local d, e = holder.drs[k], list[k]
    if e then
      local key = guid .. ":" .. e.cat
      if d.key ~= key or not d._shownKey then
        d.key, d._shownKey = key, true
        d.alpha = prevAlpha[key] or 0
        d:SetAlpha(d.alpha)
      end
      local c = DR_COLORS[e.s.count] or DR_COLORS[3]
      d:SetBackdropBorderColor(c[1], c[2], c[3], 1)
      d.icon:SetTexture(e.s.icon)
      if e.s.active then
        SetCooldown(d, nil)
        d.text:SetText("")
        FadeTo(d, 1)
      elseif now < e.s.resetAt then
        SetCooldown(d, e.s.endedAt, DR_RESET)
        d.text:SetText(FormatTime(e.s.resetAt - now))
        FadeTo(d, 1)
      else
        SetCooldown(d, nil)
        d.text:SetText("")
        FadeTo(d, 0)
      end
      d:Show()
    else
      d._shownKey, d.fading = nil, nil
      d:SetScript("OnUpdate", nil)
      d:Hide()
    end
  end
  return math.min(#list, MAX_DR)
end

-- 3.12: rows fade when the enemy is out of range of your spell (first one you know)
local RANGE_SPELLS = { PRIEST = { 32379, 527 }, ROGUE = { 36554, 2094, 1766 }, MAGE = { 2139, 118 },
  WARLOCK = { 5782 }, HUNTER = { 75 }, SHAMAN = { 57994 }, DRUID = { 33786 }, PALADIN = { 853 },
  WARRIOR = { 100 }, DEATHKNIGHT = { 47528 } }
local rangeSpell
local function UpdateRangeSpell()
  rangeSpell = nil
  local _, class = UnitClass("player")
  for _, id in ipairs(RANGE_SPELLS[class] or {}) do
    local name = GetSpellInfo(id)
    if name and GetSpellInfo(name) then rangeSpell = name; return end     -- by name: only if you know it
  end
end

local function RenderRow(f, s, now)
  local alpha = s.visible and 1 or 0.45
  if s.visible and db.range and rangeSpell and not testMode
      and IsSpellInRange(rangeSpell, "arena" .. f.index) == 0 then
    alpha = 0.5
  elseif testMode and s.outOfRange and db.range then   -- unlock preview: row 1 = out of range
    alpha = 0.5
  end
  f:SetAlpha(alpha)
  local coords = CLASS_COORDS[s.class]
  if coords then
    f.class:SetTexture(CLASS_TEX)
    f.class:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
  else
    f.class:SetTexture(UNKNOWN_ICON)
    f.class:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  end
  local cc = not s.dead and NS.PickCCFrom and NS.PickCCFrom(s.cc, s.guid, now)
  if cc then
    f.cc:SetTexture(cc.icon)
    f.cc:Show()
    local c = ArenaFrames_Auras.CC_COLORS[cc.kind] or ArenaFrames_Auras.CC_COLORS.stun
    f.classBox:SetBackdropBorderColor(c[1], c[2], c[3], 1)       -- border by kind, big yellow timer
    local left = cc.expires > 0 and (cc.expires - now) or nil
    f.ccText:SetText(left and (left < 10 and string.format("%.1f", left) or FormatTime(left)) or "")
  elseif s.lastSpell and now - s.lastSpell.t < SPELL_FLASH then   -- the spell they just used (3.13)
    f.cc:SetTexture(s.lastSpell.icon)
    f.cc:Show()
    f.ccText:SetText("")
    f.classBox:SetBackdropBorderColor(1, 1, 1, 1)
  else
    f.cc:Hide()
    f.ccText:SetText("")
    f.classBox:SetBackdropBorderColor(0, 0, 0, 1)
  end

  local maxhp = (s.maxhp and s.maxhp > 0) and s.maxhp or 1
  local hp = math.max(0, math.min(s.hp or 0, maxhp))
  f.hp:SetMinMaxValues(0, maxhp)
  f.hp:SetValue(s.dead and 0 or hp)
  f.name:SetText("|cffaaaaaa" .. f.index .. "|r " .. (s.name or "?"))
  local st = s.guid and specState[s.guid]
  local spec = st and st.spec
  if spec then
    f.spec:SetText(spec .. ((st.score[spec] or 0) < 2 and "?" or ""))
    f.spec:Show()
  else
    f.spec:Hide()
  end
  if s.dead then
    f.hp:SetStatusBarColor(0.4, 0.4, 0.4)
    f.pct:SetText("DEAD")
  else
    f.hp:SetStatusBarColor(ClassColor(s.class))
    f.pct:SetText(math.floor(hp / maxhp * 100 + 0.5) .. "%")
  end
  if db.names then f.name:Show() else f.name:Hide() end
  if db.names or s.dead then f.pct:Show() else f.pct:Hide() end

  -- power bar (mana / rage / energy / runic power)
  local maxp = (s.maxpower and s.maxpower > 0) and s.maxpower or 1
  f.power:SetMinMaxValues(0, maxp)
  f.power:SetValue(s.dead and 0 or (s.power or 0))
  local pc = POWER_COLORS_ROW[s.ptype or 0] or POWER_COLORS_ROW[0]
  f.power:SetStatusBarColor(pc[1], pc[2], pc[3])

  -- trinket
  local t = f.trinket
  t.icon:SetTexture(TRINKET_ICON[s.faction] or TRINKET_ICON.Horde)
  local used = s.guid and trinketUsed[s.guid]
  if used and now - used < TRINKET_CD then
    SetCooldown(t, used, TRINKET_CD)
    t.text:SetText(FormatTime(TRINKET_CD - (now - used)))
    t.icon:SetVertexColor(0.6, 0.6, 0.6)
  else
    SetCooldown(t, nil)
    t.text:SetText("")
    t.icon:SetVertexColor(1, 1, 1)
  end

  if NS.Kill and NS.Kill.IsPick(s.guid) then f.kill:Show(); f.killGlow:Show() else f.kill:Hide(); f.killGlow:Hide() end

  -- their pet
  local pu = "arenapet" .. f.index
  local pname, php, pmax, pdead
  if s.pet then
    pname, php, pmax = s.pet.name, s.pet.hp, s.pet.maxhp
  elseif not testMode and UnitExists(pu) then
    pname, php, pmax, pdead = UnitName(pu), UnitHealth(pu), UnitHealthMax(pu), UnitIsDeadOrGhost(pu)
  end
  if pname then
    f.pet:SetMinMaxValues(0, (pmax and pmax > 0) and pmax or 1)
    f.pet:SetValue(pdead and 0 or (php or 0))
    if pdead then f.pet:SetStatusBarColor(0.4, 0.4, 0.4) else f.pet:SetStatusBarColor(0.2, 0.7, 0.2) end
    f.pet.text:SetText(pname)
    f.pet:Show()
  else
    f.pet:Hide()
  end

  -- their cast (live units only; test mode fakes one on arena1)
  local name, icon, cs, ce, notInt
  if s.cast then                                   -- test preview: loops every 2.2 s
    if now >= s.cast.e then s.cast.s, s.cast.e = now, now + 2.2 end
    name, icon, cs, ce, notInt = s.cast.name, s.cast.icon, s.cast.s, s.cast.e, s.cast.notInt
  elseif s.visible and not testMode and UnitGUID("arena" .. f.index) == s.guid then
    local u = "arena" .. f.index
    local n, _, _, ic, st0, en, _, _, ni = UnitCastingInfo(u)
    if not n then n, _, _, ic, st0, en, _, ni = UnitChannelInfo(u) end
    if n and st0 and en then name, icon, cs, ce, notInt = n, ic, st0 / 1000, en / 1000, ni end
  end
  local cb = f.cast
  if name and now < ce then
    cb:SetPoint("TOPLEFT", f.racial:IsShown() and f.racial or f.trinket, "TOPRIGHT", 4 + math.floor(db.height * 0.5), 0)
    cb.icon:SetTexture(icon)
    cb.text:SetText(name)
    cb.time:SetText(string.format("%.1f", ce - now))
    cb:SetValue((now - cs) / math.max(ce - cs, 0.01))
    if notInt then cb:SetStatusBarColor(0.6, 0.6, 0.6) else cb:SetStatusBarColor(1, 0.7, 0) end
    cb:Show()
  else
    cb:Hide()
  end

  RenderDRs(f, s.guid, now)
end

local CD_COLORS = {
  interrupt = { 0.3, 0.6, 1 }, cc = { 0.75, 0.35, 1 }, defensive = { 0.2, 0.9, 0.2 },
  offensive = { 1, 0.2, 0.2 }, mobility = { 1, 0.82, 0 }, healer = { 0.2, 1, 0.8 }, other = { 0.6, 0.6, 0.6 },
}

-- whose cooldowns go on the enemy bar: arena enemies in arena, else hostile players and an
-- attackable target / focus (duel opponents can be flagged friendly)
local function IsEnemyGUID(guid)
  if testMode then return guid:sub(1, 4) == "test" end
  if inArena then return ArenaIndexOf(guid) ~= nil end
  if cdInfo[guid] and cdInfo[guid].hostile then return true end
  for _, u in ipairs({ "target", "focus" }) do
    if UnitGUID(u) == guid and UnitCanAttack("player", u) then return true end
  end
  return false
end

local cdList, cdPool = {}, {}
local function ByNewest(a, b) return a.start > b.start end

local function RenderCooldownBar(now)
  local n = 0
  if db.cdbar then
    for guid, byE in pairs(cdUsed) do
      if IsEnemyGUID(guid) then
        for e, u in pairs(byE) do
          if now < u.start + u.dur and not u.shared then  -- only what they actually pressed
            n = n + 1
            local item = cdPool[n] or {}
            cdPool[n] = item
            item.e, item.start, item.dur, item.guid = e, u.start, u.dur, guid
            cdList[n] = item
          end
        end
      end
    end
  end
  for k = n + 1, #cdList do cdList[k] = nil end
  table.sort(cdList, ByNewest)
  for k, b in ipairs(cdBar.icons) do
    local item = cdList[k]
    if item then
      b.icon:SetTexture(item.e.icon)
      local c = CD_COLORS[item.e.cat] or CD_COLORS.other
      b:SetBackdropBorderColor(c[1], c[2], c[3], 1)
      SetCooldown(b, item.start, item.dur)
      b.text:SetText(FormatTime(item.start + item.dur - now))
      local i = (inArena or testMode) and ArenaIndexOf(item.guid)
      b.badge:SetText(i or "")
      b:Show()
    else
      b:Hide()
    end
  end
end

-- racial square next to the trinket + the cooldowns this enemy used, newest first (3.11)
local usedScratch = {}
local function RenderUsed(f, s, now)
  local rac = s.race and s.race ~= "Human" and NS.racialByRace and NS.racialByRace[s.race]  -- EMFH = trinket
  local r = f.racial
  if rac then
    r.icon:SetTexture(rac.icon)
    local u = s.guid and cdUsed[s.guid] and cdUsed[s.guid][rac]
    if u and now < u.start + u.dur then
      SetCooldown(r, u.start, u.dur)
      r.text:SetText(FormatTime(u.start + u.dur - now))
    else
      SetCooldown(r, nil)
      r.text:SetText("")
    end
    r:Show()
  else
    r:Hide()
  end
  wipe(usedScratch)
  for e, u in pairs(s.guid and cdUsed[s.guid] or {}) do
    if not u.shared and now < u.start + u.dur and not e.trinket and e ~= rac and e.name ~= "Every Man for Himself" then
      local item = { e = e, start = u.start, dur = u.dur }
      table.insert(usedScratch, item)
    end
  end
  table.sort(usedScratch, ByNewest)
  for k, b in ipairs(f.used) do
    local item = usedScratch[k]
    if item then
      b.icon:SetTexture(item.e.icon)
      local c = CD_COLORS[item.e.cat] or CD_COLORS.other
      b:SetBackdropBorderColor(c[1], c[2], c[3], 1)
      SetCooldown(b, item.start, item.dur)
      b.text:SetText(FormatTime(item.start + item.dur - now))
      b:Show()
    else
      b:Hide()
    end
  end
end

-- 3.18 (owner: "show a druid or rogue frame if one of them is stealthed: druid if the enemies have the
-- druid buff, else rogue"): once the gates are open (an enemy was seen), every arena index up to our team
-- size that never showed up gets a dimmed placeholder row of the probable class (NS.GuessHidden, Kill
-- module: Mark / Gift of the Wild on a visible enemy and no druid seen = DRUID, else ROGUE)
local ghosts = {}
local function TeamSize()
  local raid = GetNumRaidMembers()
  if raid > 0 then return math.min(raid, 5) end
  return GetNumPartyMembers() + 1
end

local function Ghost(i, k, faction)
  local g = ghosts[i] or {}
  ghosts[i] = g
  local guess = NS.GuessHidden and NS.GuessHidden() or "ROGUE"
  g.class = (k == 1) and guess or "ROGUE"
  g.name, g.ghost, g.visible, g.faction = "stealth", true, false, faction
  g.hp, g.maxhp, g.power, g.maxpower, g.ptype = 1, 1, 1, 1, g.class == "DRUID" and 0 or 3
  return g
end

local function Render()
  local now = GetTime()
  local show = inArena or testMode
  local seen, faction = 0, nil
  if inArena and not testMode then
    for i = 1, 5 do
      if slots[i] then seen = seen + 1; faction = faction or slots[i].faction end
    end
  end
  local missing = seen > 0 and TeamSize() or 0
  local k = 0
  for i = 1, 5 do
    local f, s = rows[i], slots[i]
    if show and not s and i <= missing then
      k = k + 1
      s = Ghost(i, k, faction)
    end
    if show and s then
      RenderRow(f, s, now)
      RenderUsed(f, s, now)
      if s.ghost then
        f.spec:SetText("stealth?")
        f.spec:Show()
        if NS.Kill and NS.Kill.IsPick("hidden") and k == 1 then f.kill:Show(); f.killGlow:Show() end
      end
      f:Show()
    elseif f:IsShown() then
      f:Hide()
    end
  end
  RenderCooldownBar(now)
end

-- rows are children of the anchor, so the anchor always stays shown; outside test mode
-- only its handle (background, label, mouse) goes away
local extraMovers = {}   -- drag handles of other modules (alerts)
local function UpdateAnchorVisuals()
  local all = { anchor, cdBar }
  for _, m in ipairs(extraMovers) do table.insert(all, m) end
  for _, m in ipairs(all) do
    if testMode then
      m.bg:Show(); m.label:Show(); m:EnableMouse(true)
    else
      m.bg:Hide(); m.label:Hide(); m:EnableMouse(false)
    end
  end
end

------------------------------------------------------------------- test --

local function FillTestData()
  ResetMatch()
  local now = GetTime()
  local fake = {
    { "Kisame", "ROGUE", "Alliance", 0.58 },
    { "Paracetomol", "PRIEST", "Alliance", 0.96 },
    { "Twilights", "MAGE", "Alliance", 0.31 },
  }
  for i, v in ipairs(fake) do
    slots[i] = { guid = "test" .. i, name = v[1], class = v[2], faction = v[3],
      hp = math.floor(v[4] * 20000), maxhp = 20000, dead = false, visible = true }
  end
  slots[3].visible = false                       -- shows how a stealthed / unseen enemy looks
  for i, v in ipairs({ { 3, 60, 100, "Human" }, { 0, 14000, 20000, "Scourge" }, { 0, 8000, 17000, "Gnome" } }) do
    slots[i].ptype, slots[i].power, slots[i].maxpower, slots[i].race = v[1], v[2], v[3], v[4]
  end
  slots[3].pet = { name = "Water Elemental", hp = 9000, maxhp = 12000 }   -- pet bar preview
  slots[1].outOfRange = true                     -- range fade preview (row 3 = not visible)
  slots[3].lastSpell = { icon = select(3, GetSpellInfo(122)) or UNKNOWN_ICON, t = now + 3600 }  -- Frost Nova
  slots[2].cast = { name = "Flash Heal", icon = select(3, GetSpellInfo(2061)) or UNKNOWN_ICON, s = now - 0.6,
    e = now + 0.9 }                               -- cast bar preview
  slots[2].cc = { { kind = "stun", icon = select(3, GetSpellInfo(8643)) or UNKNOWN_ICON, dur = 6,
    expires = now + 3.4, spell = 8643 } }         -- Kidney Shot on arena2: CC timer over the class icon
  local byName = NS.cooldownsByName or {}
  for _, v in ipairs({ { "test1", "Kick", 3 }, { "test1", "Blind", 40 }, { "test2", "PvP Trinket", 25 },
      { "test3", "Counterspell", 8 }, { "test3", "Ice Block", 70 } }) do
    local e = byName[v[2]]
    if e then UseCooldown(v[1], e, now - v[3]) end
  end
  for i, spec in ipairs({ "Subtlety", "Discipline", "Frost" }) do
    specState["test" .. i] = { score = { [spec] = 3 }, seen = {}, hints = { "(test)" }, spec = spec }
  end
  trinketUsed.test2 = now - 25
  DRApplied("test1", "stun", 8643)               -- Kidney Shot ended 5 s ago -> green, timer
  DRRemoved("test1", "stun")
  drState.test1.stun.endedAt = now - 5
  drState.test1.stun.resetAt = now - 5 + DR_RESET
  DRApplied("test1", "fear", 2094)               -- Blind twice, still running -> yellow
  DRApplied("test1", "fear", 2094)
  DRApplied("test2", "incap", 6770)              -- Sap x3 -> red (immune)
  DRApplied("test2", "incap", 6770)
  DRApplied("test2", "incap", 1776)
  DRRemoved("test2", "incap")
end

------------------------------------------------------------------- loop --

local function RefreshZone()
  local _, instanceType = IsInInstance()
  local nowArena = (instanceType == "arena")
  if nowArena ~= inArena then
    inArena = nowArena
    if not testMode then ResetMatch() end
  end
end

-- DR state is kept for every player (target/focus display works outside arena too);
-- drop what has fully reset now and then
local function PruneDR(now)
  for guid, byCat in pairs(drState) do
    for cat, st in pairs(byCat) do
      if now >= st.resetAt + FADE_TIME then byCat[cat] = nil end
    end
    if next(byCat) == nil then drState[guid] = nil end
  end
  for guid, l in pairs(lockouts) do
    if now > l.start + l.dur then lockouts[guid] = nil end
  end
  for guid, byE in pairs(cdUsed) do
    for e, u in pairs(byE) do
      if now > u.start + u.dur then byE[e] = nil end
    end
    if next(byE) == nil then cdUsed[guid] = nil; cdInfo[guid] = nil end
  end
end

local elapsedSince, pruneTimer = 0, 0
local function OnUpdate(self, elapsed)
  elapsedSince = elapsedSince + elapsed
  if elapsedSince < UPDATE_INTERVAL then return end
  pruneTimer = pruneTimer + elapsedSince
  elapsedSince = 0
  if inArena and not testMode then ReadUnits() end
  Render()
  if pruneTimer > 10 and not testMode then
    pruneTimer = 0
    UpdateRangeSpell()                            -- respec / new spells
    PruneDR(GetTime())
  end
end

local core = CreateFrame("Frame")
core:RegisterEvent("ADDON_LOADED")
core:SetScript("OnEvent", function(self, event, ...)
  if event == "COMBAT_LOG_EVENT_UNFILTERED" then
    OnCombatLog(...)
  elseif event == "UNIT_SPELLCAST_SUCCEEDED" or event == "UNIT_SPELLCAST_START" then
    local unit, spellName = ...
    local i = inArena and unit and tonumber(unit:match("^arena(%d)$"))
    if i then
      SpecEvidence(i, nil, spellName)                -- 3.3.5 passes the name, no spell ID
      local guid = UnitGUID(unit)
      if event == "UNIT_SPELLCAST_SUCCEEDED" and trinketNames[spellName] and guid then TrinketUsed(guid) end
    end
  elseif event == "UNIT_AURA" then
    local unit = ...
    if inArena and unit and unit:match("^arena%d$") then
      ScanSpecAuras(unit)
      local s = slots[tonumber(unit:sub(6))]
      if s and NS.ScanCC and UnitGUID(unit) == s.guid then s.cc = NS.ScanCC(unit) end
    end
  elseif event == "PLAYER_REGEN_DISABLED" then
    NS.EndTestForCombat()          -- fires just before the lockdown: clickable frames can still switch
    if NS.Alerts and NS.Alerts.EnterCombat then NS.Alerts.EnterCombat() end
  elseif event == "PLAYER_REGEN_ENABLED" then
    if clickPending then CreateClickButtons() end
  elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
    SetTrinketIcons()
    UpdateRangeSpell()
    RefreshZone()
    if not inArena and not testMode then Render() end
  elseif event == "ADDON_LOADED" and ... == ADDON then
    ArenaFramesDB = ArenaFramesDB or {}
    db = ArenaFramesDB
    for k, v in pairs(DEFAULTS) do
      if db[k] == nil then db[k] = v end
    end
    BuildNameMaps()
    BuildSpecMaps()
    BuildCooldownMaps()
    CreateAnchor()
    for _, k in ipairs({ "center", "csize", "cpoint", "cx", "cy" }) do db[k] = nil end   -- removed in 3.7
    ApplyLayout()
    CreateClickButtons()
    ApplyCooldownLayout()
    UpdateAnchorVisuals()
    self:UnregisterEvent("ADDON_LOADED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    self:RegisterEvent("UNIT_SPELLCAST_START")
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("UNIT_AURA")
    self:SetScript("OnUpdate", OnUpdate)
    RefreshZone()
    Render()
    -- last, so a problem in the target/focus frames can't take the arena frames down with it
    local ok, err = pcall(NS.UF.Init, db)
    if not ok then
      NS.UF.SetError(err)
      Print("|cffff4040player/target/focus frames failed to load:|r " .. tostring(err))
    end
    if NS.Alerts then
      local ok2, err2 = pcall(NS.Alerts.Init)
      if not ok2 then Print("|cffff4040alerts failed to load:|r " .. tostring(err2)) end
    end
    if NS.BigCD then
      local ok4, err4 = pcall(NS.BigCD.Init)
      if not ok4 then Print("|cffff4040big cooldown alert failed to load:|r " .. tostring(err4)) end
    end
    if NS.Kill then
      local ok3, err3 = pcall(NS.Kill.Init)
      if not ok3 then Print("|cffff4040kill target failed to load:|r " .. tostring(err3)) end
    end
  end
end)

------------------------------------------------------------------ slash --

local function Help()
  Print(string.format("v%s  scale=%.2f  width=%d  height=%d%s", VERSION, db.scale, db.width,
    db.height, testMode and "  |cff00ff00(test mode)|r" or ""))
  Print("/aframes unlock|lock (= test: move everything),  debug,  scale 0.5-2,  width 120-400,  height 20-64,  reset")
  Print("click an arena row: left = target, right = focus;  /aframes names on|off (now " .. (db.names and "on" or "off")
    .. "): name + health % on the bars")
  Print(string.format("/aframes cd on|off (now %s),  cdsize 16-64 (now %d): enemy cooldowns as they're used",
    db.cdbar and "on" or "off", db.cdsize))
  NS.UF.Help()
  if NS.Alerts then NS.Alerts.Help() end
  if NS.Kill then NS.Kill.Help() end
  Print(string.format("/aframes range on|off (now %s, %s), bigcd on|off (now %s), bigsound on|off (now %s)",
    db.range and "on" or "off", rangeSpell or "no range spell", db.bigcd and "on" or "off",
    db.bigsound and "on" or "off"))
  Print("/aframes bars save | load: copy your action bars to another character")
  Print("/aframes talents save | load 1|2 | learn 1|2: copy your talents (load = preview, you click Learn;"
    .. " learn = learns them now)")
  Print("DR border = next CC of that type: |cff1ae61ahalf|r, |cffffd900quarter|r, |cffff1a1aimmune|r")
end

local function Debug()
  Print(string.format("in arena: %s, test mode: %s", inArena and "yes" or "no", testMode and "on" or "off"))
  local now, any = GetTime(), false
  for i = 1, 5 do
    local s = slots[i]
    if s then
      any = true
      local used = s.guid and trinketUsed[s.guid]
      Print(string.format("arena%d %s (%s, %s) %s/%s%s%s | trinket: %s", i, s.name or "?",
        s.class or "?", s.faction or "?", tostring(s.hp), tostring(s.maxhp),
        s.dead and " DEAD" or "", s.visible and "" or " (not visible)",
        (used and now - used < TRINKET_CD) and ("used " .. math.floor(now - used) .. "s ago") or "ready"))
      local st = s.guid and specState[s.guid]
      Print("   spec: " .. (st and st.spec and string.format("%s (%d pts; seen: %s)", st.spec,
        st.score[st.spec], table.concat(st.hints, ", ")) or "unknown yet"))
      for _, e in ipairs(s.guid and ActiveDRs(s.guid, now) or {}) do
        Print(string.format("   DR %s: %d applied, %s, resets in %.0fs (last spell %s)",
          DR.LABELS[e.cat] or e.cat, e.s.count, e.s.active and "CC running" or "CC over",
          e.s.resetAt - now, tostring(e.s.spell)))
      end
    end
  end
  if not any then Print("no arena enemies seen yet") end
  local clicks = {}
  for i, b in ipairs(clickButtons) do
    if b:IsShown() then table.insert(clicks, "arena" .. i) end
  end
  Print("click to target / focus: " .. (not clickHolder and "not set up yet (waiting for combat to end)"
    or #clicks > 0 and table.concat(clicks, ", ") or "no arena enemy to click right now")
    .. (clickPending and " (layout update waiting for combat to end)" or ""))
  if #unknownDebuffs > 0 then
    local parts = {}
    for _, u in ipairs(unknownDebuffs) do table.insert(parts, (u.name or "?") .. " " .. u.id) end
    Print("debuffs on enemies with no DR category: " .. table.concat(parts, ", "))
  end
end

local function Clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

SLASH_ARENAFRAMES1 = "/aframes"
SLASH_ARENAFRAMES2 = "/arenaframes"
SlashCmdList.ARENAFRAMES = function(msg)
  if not db then return end
  local cmd, a = string.lower(msg or ""):match("^%s*(%S*)%s*(%S*)")
  local n = tonumber(a)

  if cmd == "test" or cmd == "unlock" or cmd == "lock" or cmd == "move" then
    local want = not testMode
    if cmd == "unlock" or cmd == "move" then want = true elseif cmd == "lock" then want = false end
    if want == testMode then
      Print(testMode and "already unlocked (test mode)" or "already locked")
      return
    end
    if InCombatLockdown() and NS.UF.IsReady() then
      Print("can't toggle test mode in combat (the player/target/focus frames are clickable)")
      return
    end
    testMode = want
    if testMode then FillTestData() else ResetMatch() end
    UpdateAnchorVisuals()
    Render()
    NS.UF.SetTest(testMode)
    if NS.Alerts then NS.Alerts.SetTest(testMode) end
    if NS.Kill then NS.Kill.SetTest(testMode) end
    Print(testMode and "unlocked (test mode) - drag any frame or dark bar to move it. /aframes lock when done."
      or "test mode OFF")
  elseif cmd == "debug" then
    Debug()
    NS.UF.Debug()
    if NS.Alerts then NS.Alerts.Debug() end
    if NS.Kill then NS.Kill.Debug() end
  elseif cmd == "scale" and n then
    db.scale = Clamp(n, 0.5, 2)
    ApplyLayout()
    Print("scale = " .. db.scale)
  elseif cmd == "width" and n then
    db.width = Clamp(math.floor(n), 120, 400)
    ApplyLayout()
    Print("width = " .. db.width)
  elseif cmd == "height" and n then
    db.height = Clamp(math.floor(n), 20, 64)
    ApplyLayout()
    Print("height = " .. db.height)
  elseif cmd == "names" and (a == "on" or a == "off") then
    db.names = (a == "on")
    Render()
    Print("names and health % on the arena bars " .. a)
  elseif cmd == "range" and (a == "on" or a == "off") then
    db.range = (a == "on")
    Print("out-of-range fading " .. a .. (rangeSpell and (" (" .. rangeSpell .. ")") or " (no range spell for your class)"))
  elseif cmd == "bigcd" and (a == "on" or a == "off") then
    db.bigcd = (a == "on")
    Print("big enemy cooldown alert " .. a)
  elseif cmd == "bigsound" and (a == "on" or a == "off") then
    db.bigsound = (a == "on")
    Print("big cooldown alert sound " .. a)
  elseif cmd == "cd" and (a == "on" or a == "off") then
    db.cdbar = (a == "on")
    Print("enemy cooldown bar " .. a)
  elseif cmd == "cdsize" and n then
    db.cdsize = Clamp(math.floor(n), 16, 64)
    ApplyCooldownLayout()
    Print("enemy cooldown icon size = " .. db.cdsize)
  elseif cmd == "bars" then
    NS.Bars(a)
  elseif cmd == "talents" then
    NS.Talents(a, tonumber(string.match(msg, "%a+%s+%a+%s+(%d)")))
  elseif cmd == "reset" then
    for k, v in pairs(DEFAULTS) do db[k] = v end
    ApplyLayout()
    ApplyCooldownLayout()
    NS.UF.Reset()
    if NS.Alerts then NS.Alerts.Reset() end
    Print("settings reset")
  elseif NS.UF.Slash(cmd, a, n) or (NS.Alerts and NS.Alerts.Slash(cmd, a, n))
      or (NS.Kill and NS.Kill.Slash(cmd, a, n)) then
    return
  else
    Help()
  end
end

-- leaving test mode when combat starts: PLAYER_REGEN_DISABLED fires just before the
-- lockdown, so the clickable frames can still be switched back to their real units
function NS.EndTestForCombat()
  if not testMode then return end
  testMode = false
  ResetMatch()
  UpdateAnchorVisuals()
  Render()
  NS.UF.SetTest(false)
  if NS.Alerts then NS.Alerts.SetTest(false) end
  if NS.Kill then NS.Kill.SetTest(false) end
  Print("test mode OFF (entering combat)")
end

NS.Print, NS.ClassColor, NS.FormatTime = Print, ClassColor, FormatTime
NS.SetBorder, NS.NewText, NS.NewIcon, NS.SetCooldown = SetBorder, NewText, NewIcon, SetCooldown
NS.FadeTo, NS.DRCategory, NS.Clamp = FadeTo, DRCategory, Clamp
NS.lockouts = lockouts
NS.extraMovers, NS.NewMover = extraMovers, NewMover
NS.IsTestMode = function() return testMode end
NS.InArena = function() return inArena end
NS.slots = slots
NS.ArenaIndexOf = function(guid) return ArenaIndexOf(guid) end
NS.SpecOf = function(guid) local st = guid and specState[guid]; return st and st.spec end
NS.cdUsed, NS.cdSeen, NS.UseCooldown = cdUsed, cdSeen, UseCooldown
NS.FLAT, NS.FONT, NS.CLASS_TEX, NS.CLASS_COORDS, NS.UNKNOWN_ICON = FLAT, FONT, CLASS_TEX, CLASS_COORDS, UNKNOWN_ICON

--[[
  Player, target and focus frames in Blizzard's style (WoW 3.3.5a). Kept in this file so
  an update never adds files to the .toc (WoW only re-reads the file list on a restart).

  * The game's own frame art (UI-TargetingFrame) and bar texture, with Blizzard's 3.3.5
    geometry, but class-colored health, clean texts and the important info on top.
  * Portrait: Blizzard's round class icon (UI-Classes-Circles). While the unit is CC'd it
    becomes the round CC icon (SetPortraitToTexture) with a big countdown colored by kind:
    immunity > Cyclone >
    stun > incapacitate/fear/horror > silence / interrupt lockout > disarm. No roots/slows.
    NPCs get Blizzard's round 2D portrait.
  * Target / focus: all buffs and debuffs under the bars like Blizzard's (yours and the
    important enemy buffs large, important ones with a gold border, debuff borders by
    type), wrapping rows; a cast bar under that (grey + "(no kick)" when it can't be interrupted, red
    "Interrupted"). Target: Blizzard's own combo points, and a Sap icon on the left while
    the target is an enemy player out of combat (asks CombatPlates when it's loaded).
  * You are a box at the top of the party stack (3.5: no Blizzard-style player frame).
  * Clickable: left click targets, shift + left click focuses, right click opens Blizzard's
    own menu for that frame (Inspect, Whisper, Set Focus...). Shown /
    hidden by RegisterUnitWatch, so it works in combat. Moving: /aframes test, drag, out
    of combat only. Blizzard's PlayerFrame / TargetFrame / FocusFrame are hidden.
]]

-- own function scope: the names below are separate from the arena code above, and Lua 5.1's
-- limit of 200 locals counts per function, not for the whole file
local function UnitFramesModule()
  local A = ArenaFrames_Auras
  local UF = {}
  NS.UF = UF

  -- Geometry is Blizzard's own (FrameXML 3.3.5 TargetFrame.xml / PlayerFrame.xml), so the
  -- game's frame art lines up: 232x100 frame, 64px round portrait, two 119x12 bars.
  -- Offsets are written for the target side (portrait on the right); the player frame is
  -- the mirror image (portrait on the left).
  local UNITS = { "target", "focus" }   -- Blizzard-style frames (the player is a box in GROUP)
  -- the group boxes, top to bottom: you, then party 1-4 (owner: "first player then party 1, 2")
  local GROUP = { "player", "party1", "party2", "party3", "party4" }
  local UF_DEFAULTS = { uf = true, ufscale = 1, pcdsize = 20 }
  local DEFAULT_POS = {        -- where Blizzard puts its own frames
    player = { "TOPLEFT", -19, -4 },
    target = { "TOPLEFT", 250, -4 },
    focus = { "TOPLEFT", 250, -135 },      -- under the target, clear of the arena rows
  }
  local ART = [[Interface\TargetingFrame\UI-TargetingFrame]]
  local ART_CLASSIFICATION = {
    worldboss = [[Interface\TargetingFrame\UI-TargetingFrame-Elite]],
    elite = [[Interface\TargetingFrame\UI-TargetingFrame-Elite]],
    rareelite = [[Interface\TargetingFrame\UI-TargetingFrame-Rare-Elite]],
    rare = [[Interface\TargetingFrame\UI-TargetingFrame-Rare]],
  }
  local BAR = [[Interface\TargetingFrame\UI-StatusBar]]
  local SKULL = [[Interface\TargetingFrame\UI-TargetingFrame-Skull]]
  local NAME_BG = [[Interface\TargetingFrame\UI-TargetingFrame-LevelBackground]]
  local RAID_ICONS = [[Interface\TargetingFrame\UI-RaidTargetingIcons]]
  local SAP_ICON = select(3, GetSpellInfo(6770)) or [[Interface\Icons\Ability_Sap]]
  local BLIZZARD_FRAME = { player = PlayerFrame, target = TargetFrame, focus = FocusFrame,
    party1 = PartyMemberFrame1, party2 = PartyMemberFrame2, party3 = PartyMemberFrame3, party4 = PartyMemberFrame4 }
  local AURA_LARGE, AURA_SMALL = 21, 17   -- Blizzard's sizes: yours / important ones large
  local AURA_ROW_WIDTH = 122               -- Blizzard's: the rows stay under the bars
  local AURA_TOP = -68                     -- first row, from the frame's top
  local MAX_DEBUFFS, MAX_BUFFS = 16, 16
  local PLAYER_UNITS = { player = true, pet = true, vehicle = true }
  local CLASS_ICON_SIZE = 62    -- round class icon filling the portrait ring
  -- Blizzard's round class icons (Blizzard_ArenaUI uses them), same layout as CLASS_ICON_TCOORDS
  local CLASS_CIRCLES = [[Interface\TargetingFrame\UI-Classes-Circles]]
  local INTERRUPTED_HOLD = 1.0
  local AURA_RESCAN = 1.0       -- safety rescan; normally UNIT_AURA triggers it
  local UF_UPDATE_INTERVAL = 0.1

  local POWER_COLORS = {
    [0] = { 0.25, 0.45, 1.00 }, [1] = { 1.00, 0.10, 0.10 }, [2] = { 1.00, 0.50, 0.25 },
    [3] = { 1.00, 0.90, 0.10 }, [6] = { 0.00, 0.82, 1.00 },
  }
  local REACTION_COLORS = {     -- UnitReaction 1-8, for NPC health
    { 0.85, 0.2, 0.2 }, { 0.85, 0.2, 0.2 }, { 0.85, 0.35, 0.2 }, { 0.9, 0.8, 0.2 },
    { 0.2, 0.8, 0.2 }, { 0.2, 0.8, 0.2 }, { 0.2, 0.8, 0.2 }, { 0.2, 0.8, 0.2 },
  }
  local CAST_COLOR = { 1.0, 0.7, 0.0 }      -- Blizzard's cast bar colors
  local CHANNEL_COLOR = { 0.0, 1.0, 0.0 }
  local LOCKED_COLOR = { 0.6, 0.6, 0.6 }
  local FAILED_COLOR = { 1.0, 0.0, 0.0 }

  local frames = {}            -- [unit] = frame
  local ufTest = false
  local ufState, ufError = "off", nil
  local immuneNames, buffNames = {}, {}
  local pendingOutOfCombat = {}  -- functions to run at PLAYER_REGEN_ENABLED
  local blizzHidden = false

  local function RunOutOfCombat(fn)
    if InCombatLockdown() then table.insert(pendingOutOfCombat, fn) else fn() end
  end

  local function BuildNames()
    for id in pairs(A.IMMUNE) do
      local name = GetSpellInfo(id)
      if name then immuneNames[name] = true end
    end
    for id in pairs(A.BUFFS) do
      local name = GetSpellInfo(id)
      if name then buffNames[name] = true end
    end
  end

  local function ShortNumber(v)
    if v >= 1000000 then return string.format("%.1fm", v / 1000000) end
    if v >= 10000 then return string.format("%.1fk", v / 1000) end
    return tostring(v)
  end

  ------------------------------------------------------------------ widgets --

  local function NewAuraIcon(parent)
    local b = NS.NewIcon(parent)
    b.text:SetFont(NS.FONT, 10, "OUTLINE")
    b.count = NS.NewText(b.over, 9, "RIGHT")
    b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
    b:Hide()
    return b
  end

  local function ShadowText(parent, size, r, g, b)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(NS.FONT, size)
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetTextColor(r or 1, g or 1, b or 1)
    return fs
  end

  local function OnDragStart(self)
    if ufTest and not InCombatLockdown() then
      self.moving = true
      self:StartMoving()
    end
  end

  -- positions are saved in UIParent units, so changing ufscale doesn't move the frames
  local function OnDragStop(self)
    if not self.moving then return end
    self.moving = nil
    self:StopMovingOrSizing()
    local point, _, _, x, y = self:GetPoint()
    local s = self:GetScale()
    db["ufpos_" .. self.unit] = { point, math.floor(x * s + 0.5), math.floor(y * s + 0.5) }
  end

  local function CreateUnitFrame(unit)
    local mirror = (unit == "player")       -- player: portrait on the left
    local function X(x) return mirror and -x or x end
    local corner = mirror and "TOPLEFT" or "TOPRIGHT"     -- Blizzard's XML anchors from here

    local name = "ArenaFrames" .. unit:sub(1, 1):upper() .. unit:sub(2)
    local f = CreateFrame("Button", name, UIParent, "SecureUnitButtonTemplate")
    f.unit = unit
    f:SetFrameStrata("LOW")
    f:SetToplevel(true)
    f:SetWidth(232)
    f:SetHeight(100)
    if mirror then f:SetHitRectInsets(6, 0, 4, 9) else f:SetHitRectInsets(0, 40, 10, 20) end
    f:SetAttribute("unit", unit)
    f:SetAttribute("*type1", "target")
    f:SetAttribute("shift-type1", "focus")
    -- right click = Blizzard's own menu (Inspect, Whisper, Invite, Trade, Set Focus...): the
    -- secure "click" action clicks the hidden Blizzard frame, whose own secure "menu" opens
    -- it. Opening it from addon code instead would taint it and block Set Focus.
    f:SetAttribute("*type2", "click")
    f:SetAttribute("*clickbutton2", BLIZZARD_FRAME[unit])
    f:RegisterForClicks("AnyUp")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    -- the player frame's art starts ~20 px in: let that empty strip go off screen so it
    -- can sit where Blizzard's does (x = -19)
    if mirror then f:SetClampRectInsets(19, 0, 0, 0) end
    f:SetScript("OnDragStart", OnDragStart)
    f:SetScript("OnDragStop", OnDragStop)
    -- Blizzard's unit tooltip on hover (also what makes @mouseover macros see the unit)
    f:SetScript("OnEnter", function(self)
      if not self.moving and UnitExists(self.unit) and UnitFrame_OnEnter then UnitFrame_OnEnter(self) end
    end)
    f:SetScript("OnLeave", function(self)
      if UnitFrame_OnLeave then UnitFrame_OnLeave(self) end
    end)

    -- BACKGROUND / BORDER layers on the frame itself, under the art
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetTexture(0, 0, 0, 0.5)
    f.bg:SetWidth(119); f.bg:SetHeight(41)
    f.bg:SetPoint(corner, f, corner, X(-106), -22)
    if not mirror then
      f.nameBg = f:CreateTexture(nil, "BORDER")
      f.nameBg:SetTexture(NAME_BG)
      f.nameBg:SetWidth(119); f.nameBg:SetHeight(19)
      f.nameBg:SetPoint(corner, f, corner, X(-106), -22)
    end

    -- portrait: dark disc + square class icon, or a round texture (CC icon / NPC face)
    f.disc = f:CreateTexture(nil, "BORDER")
    f.disc:SetWidth(64); f.disc:SetHeight(64)
    f.disc:SetPoint(corner, f, corner, X(-42), -12)
    SetPortraitToTexture(f.disc, NS.UNKNOWN_ICON)
    f.disc:SetVertexColor(0, 0, 0, 1)
    f.classIcon = f:CreateTexture(nil, "ARTWORK")
    f.classIcon:SetWidth(CLASS_ICON_SIZE); f.classIcon:SetHeight(CLASS_ICON_SIZE)
    f.classIcon:SetPoint("CENTER", f.disc, "CENTER", 0, 0)
    f.round = f:CreateTexture(nil, "ARTWORK")
    f.round:SetAllPoints(f.disc)
    f.round:Hide()

    -- bars
    f.hp = CreateFrame("StatusBar", nil, f)
    f.hp:SetStatusBarTexture(BAR)
    f.hp:SetMinMaxValues(0, 1)
    f.hp:SetWidth(119); f.hp:SetHeight(12)
    f.hp:SetPoint(corner, f, corner, X(-106), -41)
    f.power = CreateFrame("StatusBar", nil, f)
    f.power:SetStatusBarTexture(BAR)
    f.power:SetMinMaxValues(0, 1)
    f.power:SetWidth(119); f.power:SetHeight(12)
    f.power:SetPoint(corner, f, corner, X(-106), -52)

    -- Blizzard frame art + texts on top of bars and portrait
    local art = CreateFrame("Frame", nil, f)
    f.artFrame = art
    art:SetAllPoints(f)
    art:SetFrameLevel(f.power:GetFrameLevel() + 1)
    f.art = art:CreateTexture(nil, "BORDER")
    f.art:SetAllPoints(art)
    f.art:SetTexture(ART)
    if mirror then f.art:SetTexCoord(1, 0.09375, 0, 0.78125) else f.art:SetTexCoord(0.09375, 1, 0, 0.78125) end

    f.name = ShadowText(art, 11, 1, 0.82, 0)
    f.name:SetWidth(110); f.name:SetHeight(12)
    f.name:SetPoint("CENTER", f, "CENTER", X(-50), 19)
    f.level = ShadowText(art, 10, 1, 0.82, 0)
    f.level:SetPoint("CENTER", f, "CENTER", X(63), -16)
    f.skull = art:CreateTexture(nil, "OVERLAY")
    f.skull:SetTexture(SKULL)
    f.skull:SetWidth(16); f.skull:SetHeight(16)
    f.skull:SetPoint("CENTER", f.level, "CENTER", 0, 0)
    f.skull:Hide()
    f.hpText = NS.NewText(art, 10)
    f.hpText:SetPoint("CENTER", f.hp, "CENTER", 0, 0)
    f.powerText = NS.NewText(art, 9)
    f.powerText:SetPoint("CENTER", f.power, "CENTER", 0, 0)
    f.raidIcon = art:CreateTexture(nil, "OVERLAY")
    f.raidIcon:SetTexture(RAID_ICONS)
    f.raidIcon:SetWidth(26); f.raidIcon:SetHeight(26)
    f.raidIcon:SetPoint("CENTER", f, corner, X(-73), -14)
    f.raidIcon:Hide()
    f.ccText = NS.NewText(art, 20)         -- CC countdown over the round portrait
    f.ccText:SetPoint("CENTER", f.disc, "CENTER", 0, 0)

    if unit ~= "player" then
      -- auras under the bars like Blizzard's: all buffs and debuffs, rows that wrap
      f.debuffs, f.buffs = {}, {}
      for k = 1, MAX_DEBUFFS do f.debuffs[k] = NewAuraIcon(f) end
      for k = 1, MAX_BUFFS do f.buffs[k] = NewAuraIcon(f) end

      -- cast bar under the auras (moves down with them, like Blizzard's)
      local cb = CreateFrame("Frame", nil, f)
      f.cast = cb
      NS.SetBorder(cb)
      cb:SetBackdropColor(0, 0, 0, 0.6)
      cb:SetWidth(170); cb:SetHeight(16)
      cb.icon = cb:CreateTexture(nil, "ARTWORK")
      cb.icon:SetPoint("TOPLEFT", cb, "TOPLEFT", 1, -1)
      cb.icon:SetWidth(14); cb.icon:SetHeight(14)
      cb.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
      cb.bar = CreateFrame("StatusBar", nil, cb)
      cb.bar:SetStatusBarTexture(BAR)
      cb.bar:SetMinMaxValues(0, 1)
      cb.bar:SetPoint("TOPLEFT", cb.icon, "TOPRIGHT", 1, 0)
      cb.bar:SetPoint("BOTTOMRIGHT", cb, "BOTTOMRIGHT", -1, 1)
      cb.label = NS.NewText(cb.bar, 10, "LEFT")
      cb.label:SetPoint("LEFT", cb.bar, "LEFT", 3, 0)
      cb.label:SetPoint("RIGHT", cb.bar, "RIGHT", -28, 0)
      cb.label:SetHeight(12)
      cb.time = NS.NewText(cb.bar, 10, "RIGHT")
      cb.time:SetPoint("RIGHT", cb.bar, "RIGHT", -3, 0)
      cb:Hide()
    end

    if unit == "target" or unit == "focus" then
      -- "sappable" icon left of the frame: enemy player out of combat (same idea as
      -- CombatPlates' sap mode, and it asks CombatPlates when that addon is loaded)
      local s = NS.NewIcon(f)
      f.sap = s
      s.icon:SetTexture(SAP_ICON)
      s:SetWidth(30); s:SetHeight(30)
      s:SetPoint("RIGHT", f, "TOPLEFT", 2, -46)
      s:Hide()
    end

    f.ccList = {}
    f.auraTimer = 0
    frames[unit] = f
    return f
  end

  local Party                     -- the party frames' functions, filled in further down

  local function ApplyUFLayout()
    if Party and frames.party1 then Party.ApplyLayout() end
    for _, unit in ipairs(UNITS) do
      local f = frames[unit]
      local pos = db["ufpos_" .. unit] or DEFAULT_POS[unit]
      local s = db.ufscale
      f:SetScale(s)
      if blizzHidden then BLIZZARD_FRAME[unit]:SetScale(s) end   -- covers ours exactly (menu spot)
      f:ClearAllPoints()
      f:SetPoint(pos[1], UIParent, pos[1], pos[2] / s, pos[3] / s)
    end
  end

  ----------------------------------------------------------------- reading --

  -- What the frame shows comes either from the real unit or from test data.
  local function ReadInfo(f)
    local d = f.fake
    if d then
      return d.name, d.class, d.hp, d.maxhp, d.ptype, d.power, d.maxpower, false, true, 2, d.guid, 80
    end
    local u = f.unit
    local _, class = UnitClass(u)
    return UnitName(u), class, UnitHealth(u), UnitHealthMax(u), UnitPowerType(u),
      UnitPower(u), UnitPowerMax(u), UnitIsDeadOrGhost(u), UnitIsPlayer(u),
      UnitReaction(u, "player"), UnitGUID(u), UnitLevel(u)
  end

  -- large ones (yours / important) first, then the game's order
  local function SortAuras(a, b)
    if a.big ~= b.big then return a.big end
    return a.order < b.order
  end

  -- Scan the unit's auras into f.ccList / f.buffList / f.debuffList.
  local function ScanAuras(f)
    f.auraTimer = 0
    if f.fake then return end
    local u = f.unit
    local cc, buffs, debuffs = {}, {}, {}
    for i = 1, 40 do
      local name, _, icon, count, dtype, dur, expires, caster, _, _, spellId = UnitAura(u, i, "HARMFUL")
      if not name then break end
      local cat = NS.DRCategory(spellId, name)
      if cat and A.CC_PRIORITY[cat] then                -- roots / slows have no priority
        table.insert(cc, { kind = cat, icon = icon, dur = dur or 0, expires = expires or 0, spell = spellId })
      end
      if f.debuffs then
        table.insert(debuffs, { icon = icon, count = count or 0, dur = dur or 0, expires = expires or 0,
          big = PLAYER_UNITS[caster] or false, dtype = dtype, order = i })
      end
    end
    for i = 1, 40 do
      local name, _, icon, count, _, dur, expires, caster, _, _, spellId = UnitAura(u, i, "HELPFUL")
      if not name then break end
      if A.IMMUNE[spellId] or immuneNames[name] then
        table.insert(cc, { kind = "immune", icon = icon, dur = dur or 0, expires = expires or 0, spell = spellId })
      end
      if f.buffs then
        local important = (A.BUFFS[spellId] or buffNames[name]) and true or false
        table.insert(buffs, { icon = icon, count = count or 0, dur = dur or 0, expires = expires or 0,
          big = important or PLAYER_UNITS[caster] or false, important = important, order = i })
      end
    end
    table.sort(debuffs, SortAuras)
    table.sort(buffs, SortAuras)
    f.ccList, f.buffList, f.debuffList = cc, buffs, debuffs
  end

  -- The CC (or immunity / interrupt lockout) that wins the portrait right now.
  local function PickCC(f, guid, now)
    local best, bestPrio, bestLeft
    for _, c in ipairs(f.ccList) do
      local left = c.expires > 0 and (c.expires - now) or math.huge
      if left > 0 then
        local prio = A.CC_PRIORITY[c.kind] or 0
        if not best or prio > bestPrio or (prio == bestPrio and left > bestLeft) then
          best, bestPrio, bestLeft = c, prio, left
        end
      end
    end
    local l = guid and NS.lockouts[guid]
    if l and now < l.start + l.dur then
      local left, prio = l.start + l.dur - now, A.CC_PRIORITY.lockout
      if not best or prio > bestPrio or (prio == bestPrio and left > bestLeft) then
        l.kind = "lockout"
        l.expires = l.start + l.dur
        best = l
      end
    end
    return best
  end

  -- for the arena rows (same CC priority as the target / focus portraits)
  NS.ScanCC = function(unit)
    local f = { unit = unit }
    ScanAuras(f)
    return f.ccList
  end
  NS.PickCCFrom = function(list, guid, now)
    return PickCC({ ccList = list or {} }, guid, now)
  end

  -- Enemy player who isn't fighting: Sap works. CombatPlates (if loaded) also looks at the
  -- combat log, which catches duels and fights the API misses on Warmane.
  -- Every check, for /aframes debug. Enemy = other faction (like the red nameplates
  -- CombatPlates marks, even when they aren't PvP flagged) or attackable right now (duels).
  local function SapChecks(u)
    return UnitIsPlayer(u) and true or false, UnitIsEnemy("player", u) and true or false,
      UnitCanAttack("player", u) and true or false, UnitIsDeadOrGhost(u) and true or false,
      UnitAffectingCombat(u) and true or false,
      (CombatPlates_InCombat and CombatPlates_InCombat(u)) and true or false
  end

  local function Sappable(f)
    if f.fake then return true end
    local isPlayer, enemy, attackable, dead, apiCombat, logCombat = SapChecks(f.unit)
    return isPlayer and (enemy or attackable) and not dead and not apiCombat and not logCombat
  end

  ------------------------------------------------------------------ render --

  -- one group of aura icons in the row under the bars, starting at x; returns the next x
  -- Lay one group of aura icons out in rows from (x, y), wrapping at Blizzard's row width.
  -- Returns where the next icon would go and the current row's height.
  local function RenderAuraGroup(f, icons, list, x, y, rowH, now)
    for k, b in ipairs(icons) do
      local a = list and list[k]
      if a and (a.expires == 0 or a.expires > now) then
        local size = a.big and AURA_LARGE or AURA_SMALL
        if x > 5 and x + size > 5 + AURA_ROW_WIDTH then
          x, y, rowH = 5, y - rowH - 3, 0
        end
        if b.x ~= x or b.y ~= y or b.size ~= size then
          b:ClearAllPoints()
          b:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
          b:SetWidth(size)
          b:SetHeight(size)
          b.x, b.y, b.size = x, y, size
        end
        x = x + size + 2
        if size > rowH then rowH = size end
        b.icon:SetTexture(a.icon)
        if a.important then
          b:SetBackdropBorderColor(1, 0.82, 0, 1)            -- important enemy buff: gold
        elseif a.dtype ~= nil or list == f.debuffList then
          local c = DebuffTypeColor and DebuffTypeColor[a.dtype or "none"]
          if c then b:SetBackdropBorderColor(c.r, c.g, c.b, 1) else b:SetBackdropBorderColor(0.8, 0, 0, 1) end
        else
          b:SetBackdropBorderColor(0, 0, 0, 1)
        end
        if a.dur > 0 and a.expires > 0 then
          NS.SetCooldown(b, a.expires - a.dur, a.dur)
          local left = a.expires - now
          b.text:SetText((a.big and left < 60) and NS.FormatTime(left) or "")
        else
          NS.SetCooldown(b, nil)
          b.text:SetText("")
        end
        b.count:SetText(a.count > 1 and a.count or "")
        b:Show()
      else
        b:Hide()
      end
    end
    return x, y, rowH
  end

  -- Debuffs first on enemies, buffs first on friends (Blizzard's order); the cast bar goes
  -- under the last row, or to Blizzard's spot under the frame when there are no auras.
  local function RenderAuras(f, now)
    local g1, l1, g2, l2 = f.debuffs, f.debuffList, f.buffs, f.buffList
    if not f.fake and UnitIsFriend("player", f.unit) then g1, l1, g2, l2 = g2, l2, g1, l1 end
    local x, y, rowH = RenderAuraGroup(f, g1, l1, 5, AURA_TOP, 0, now)
    local bottom = rowH > 0 and (y - rowH) or nil
    if rowH > 0 then x, y, rowH = 5, y - rowH - 3, 0 end
    x, y, rowH = RenderAuraGroup(f, g2, l2, x, y, rowH, now)
    if rowH > 0 then bottom = y - rowH end
    local castY = bottom and (bottom - 6) or -93
    if f.cast.y ~= castY then
      f.cast:ClearAllPoints()
      f.cast:SetPoint("TOPLEFT", f, "TOPLEFT", 6, castY)
      f.cast.y = castY
    end
  end

  local function RenderPortrait(f, class, isPlayer, guid, now)
    local cc = PickCC(f, guid, now)
    if cc then
      if f.roundSrc ~= cc.icon then
        SetPortraitToTexture(f.round, cc.icon)
        f.roundSrc = cc.icon
      end
      f.round:Show()
      f.classIcon:Hide()
      local c = A.CC_COLORS[cc.kind] or A.CC_COLORS.stun
      f.ccText:SetTextColor(c[1], c[2], c[3])
      local left = cc.expires > 0 and (cc.expires - now) or nil
      if left then
        f.ccText:SetText(left < 10 and string.format("%.1f", left) or NS.FormatTime(left))
      else
        f.ccText:SetText("")
      end
      f.ccShown = cc
      return
    end
    f.ccShown = nil
    f.ccText:SetText("")
    local coords = isPlayer and NS.CLASS_COORDS[class]
    if coords then
      f.round:Hide()
      f.classIcon:SetTexture(CLASS_CIRCLES)
      f.classIcon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
      f.classIcon:Show()
    elseif not f.fake then
      -- NPC: Blizzard's round 2D portrait; only redraw when the unit changes
      if f.roundSrc ~= guid then
        SetPortraitTexture(f.round, f.unit)
        f.roundSrc = guid
      end
      f.round:Show()
      f.classIcon:Hide()
    end
  end

  local function RenderFrame(f, now)
    local name, class, hp, maxhp, ptype, power, maxpower, dead, isPlayer, reaction, guid, level = ReadInfo(f)
    if not name then return end
    maxhp = (maxhp and maxhp > 0) and maxhp or 1
    hp = math.max(0, math.min(hp or 0, maxhp))
    f.hp:SetMinMaxValues(0, maxhp)
    f.hp:SetValue(dead and 0 or hp)
    f.name:SetText(name)
    if dead then
      f.hp:SetStatusBarColor(0.4, 0.4, 0.4)
      f.hpText:SetText("DEAD")
    else
      if isPlayer and class then
        f.hp:SetStatusBarColor(NS.ClassColor(class))
      else
        local c = REACTION_COLORS[reaction or 4] or REACTION_COLORS[4]
        f.hp:SetStatusBarColor(c[1], c[2], c[3])
      end
      if f.unit == "player" then
        f.hpText:SetText(ShortNumber(hp) .. " / " .. ShortNumber(maxhp))
      else
        f.hpText:SetText(math.floor(hp / maxhp * 100 + 0.5) .. "%")
      end
    end

    maxpower = (maxpower and maxpower > 0) and maxpower or 1
    f.power:SetMinMaxValues(0, maxpower)
    f.power:SetValue(power or 0)
    local pc = POWER_COLORS[ptype or 0] or POWER_COLORS[0]
    f.power:SetStatusBarColor(pc[1], pc[2], pc[3])
    f.powerText:SetText(f.unit == "player" and ShortNumber(power or 0) or "")

    -- level: number colored by difficulty, skull for ?? units
    if level and level > 0 then
      f.level:SetText(level)
      if f.fake then
        f.level:SetTextColor(1, 1, 0)                -- enemy of your level, as Blizzard colors it
      elseif f.unit ~= "player" and UnitCanAttack("player", f.unit) then
        local c = GetQuestDifficultyColor(level)
        f.level:SetTextColor(c.r, c.g, c.b)
      else
        f.level:SetTextColor(1, 0.82, 0)             -- Blizzard's gold for everyone else
      end
      f.level:Show(); f.skull:Hide()
    else
      f.level:Hide(); f.skull:Show()
    end

    if not f.fake then
      if f.nameBg then f.nameBg:SetVertexColor(UnitSelectionColor(f.unit)) end
      if f.unit ~= "player" then
        local c = UnitClassification(f.unit)
        local tex = (not isPlayer) and ART_CLASSIFICATION[c] or ART
        if f.artTex ~= tex then f.art:SetTexture(tex); f.artTex = tex end
      end
      local idx = GetRaidTargetIndex(f.unit)
      if idx then SetRaidTargetIconTexture(f.raidIcon, idx); f.raidIcon:Show() else f.raidIcon:Hide() end
    else
      if f.nameBg then f.nameBg:SetVertexColor(1, 0, 0) end
    end

    RenderPortrait(f, class, isPlayer, guid, now)
    if f.debuffs then RenderAuras(f, now) end
    if f.sap then
      if Sappable(f) then f.sap:Show() else f.sap:Hide() end
    end
  end

  ---------------------------------------------------------------- cast bar --

  local function CastOnUpdate(cb, elapsed)
    local now = GetTime()
    local c = cb.info
    if not c then cb:Hide(); return end
    if c.interruptedAt then
      local t = now - c.interruptedAt
      if t >= INTERRUPTED_HOLD then cb.info = nil; cb:Hide() else cb:SetAlpha(1 - 0.7 * t / INTERRUPTED_HOLD) end
      return
    end
    if now >= c.endt then
      if c.loop then                          -- test mode: keep casting
        c.start, c.endt = now, now + (c.endt - c.start)
      else
        cb.info = nil
        cb:Hide()
        return
      end
    end
    local total = c.endt - c.start
    local v = total > 0 and (now - c.start) / total or 1
    if c.channel then v = 1 - v end
    cb.bar:SetValue(v)
    cb.time:SetText(string.format("%.1f", c.endt - now))
  end

  local function ShowCast(f, info)
    local cb = f.cast
    if not cb then return end
    cb.info = info
    if not info then cb:Hide(); return end
    local col = info.notInterruptible and LOCKED_COLOR or (info.channel and CHANNEL_COLOR or CAST_COLOR)
    cb.bar:SetStatusBarColor(col[1], col[2], col[3])
    cb.icon:SetTexture(info.icon)
    cb.label:SetText(info.notInterruptible and (info.name .. " |cffaaaaaa(no kick)|r") or info.name)
    cb:SetAlpha(1)
    cb:SetScript("OnUpdate", CastOnUpdate)
    cb:Show()
    CastOnUpdate(cb, 0)
  end

  local function ReadCast(f)
    if f.fake or not f.cast then return end
    local u = f.unit
    local name, _, _, icon, startMs, endMs, _, _, notInt = UnitCastingInfo(u)
    local channel = false
    if not name then
      name, _, _, icon, startMs, endMs, _, notInt = UnitChannelInfo(u)
      channel = true
    end
    if name and startMs and endMs then
      ShowCast(f, { name = name, icon = icon, start = startMs / 1000, endt = endMs / 1000,
        channel = channel, notInterruptible = notInt and true or false })
    elseif not (f.cast.info and f.cast.info.interruptedAt) then
      ShowCast(f, nil)
    end
  end

  local function CastInterrupted(f)
    local cb = f.cast
    if not cb or not cb.info then return end
    cb.info.interruptedAt = GetTime()
    cb.bar:SetStatusBarColor(FAILED_COLOR[1], FAILED_COLOR[2], FAILED_COLOR[3])
    cb.bar:SetValue(1)
    cb.label:SetText("Interrupted")
    cb.time:SetText("")
  end

  ------------------------------------------------------------------- test --

  local function FakeAura(id, dur, left, count, big, important, dtype)
    return { icon = select(3, GetSpellInfo(id)) or NS.UNKNOWN_ICON, count = count or 0, dur = dur,
      expires = GetTime() + left, spell = id, big = big or false, important = important, dtype = dtype, order = id }
  end

  local function FillTest()
    local now = GetTime()
    local p, t, fo = frames.player, frames.target, frames.focus
    p.ccList = { FakeAura(2094, 10, 7) }                    -- you're Blinded
    p.ccList[1].kind = "fear"
    t.fake = { name = "Kisame", class = "ROGUE", hp = 11600, maxhp = 20000, ptype = 3,
      power = 70, maxpower = 100, guid = "testT" }
    t.ccList = { FakeAura(8643, 6, 6) }                     -- Kidney Shot
    t.ccList[1].kind = "stun"
    t.buffList = { FakeAura(26669, 15, 12, 0, true, true),   -- Evasion (important)
      FakeAura(48469, 3600, 3000), FakeAura(48161, 3600, 3000) }  -- Mark of the Wild, Fortitude
    t.debuffList = { FakeAura(57970, 12, 9, 5, true, nil, "Poison"), FakeAura(48672, 16, 14, 0, true),  -- yours
      FakeAura(47813, 18, 10, 0, false, nil, "Magic") }      -- someone else's Corruption
    ShowCast(t, nil)
    fo.fake = { name = "Paracetomol", class = "PRIEST", hp = 21000, maxhp = 22500, ptype = 0,
      power = 18000, maxpower = 25000, guid = "testF" }
    fo.ccList, fo.debuffList = {}, {}
    fo.buffList = { FakeAura(33206, 8, 6, 0, true, true) }  -- Pain Suppression
    ShowCast(fo, { name = GetSpellInfo(48063) or "Greater Heal", icon = select(3, GetSpellInfo(48063)) or NS.UNKNOWN_ICON,
      start = now, endt = now + 2.5, channel = false, notInterruptible = false, loop = true })
    -- Blizzard's combo points, 4 lit
    if ComboFrame then
      ComboFrame:Show()
      ComboFrame:SetAlpha(1)
      for i = 1, 5 do
        local h = _G["ComboPoint" .. i .. "Highlight"]
        if h then h:SetAlpha(i <= 4 and 1 or 0) end
      end
    end
  end

  -- test auras run out after a few seconds; restart them so the preview stays up
  local function KeepAlive(list, now)
    if not list then return end
    for _, a in ipairs(list) do
      if a.expires > 0 and a.expires <= now then a.expires = now + a.dur end
    end
  end

  -------------------------------------------------------------- blizzard --

  -- keeps UIParent's scale and has a real rect, so Blizzard code that re-anchors one of the
  -- hidden frames relative to its parent (Interface Options' focus size) still lands somewhere
  local hiddenParent = CreateFrame("Frame", nil, UIParent)
  hiddenParent:SetAllPoints(UIParent)
  hiddenParent:Hide()

  -- the hidden Blizzard frame covers ours exactly: its right-click menu opens on ours, and
  -- frames anchored to it (pet frame, DK runes) follow ours
  local function CoverOurs(unit)
    local b = BLIZZARD_FRAME[unit]
    if b.IsUserPlaced and b:IsUserPlaced() then b:SetUserPlaced(false) end   -- else the client may move it back
    b:ClearAllPoints()
    b:SetAllPoints(frames[unit])
  end

  local function HideBlizzard()
    for unit, f in pairs(BLIZZARD_FRAME) do
      f:UnregisterAllEvents()
      f:Hide()
      f:SetParent(hiddenParent)       -- stays hidden even if Blizzard code calls Show()
      CoverOurs(unit)
    end
    -- Interface > "Larger Focus Frame" makes Blizzard re-anchor FocusFrame: put it back
    if FocusFrame_SetSmallSize then
      hooksecurefunc("FocusFrame_SetSmallSize", function() RunOutOfCombat(function() CoverOurs("focus") end) end)
    end
    -- these live inside PlayerFrame but have their own events: keep them (pets, DK runes,
    -- totems on other characters). They're anchored to PlayerFrame, which now sits on ours.
    for _, f in ipairs({ PetFrame, RuneFrame, TotemFrame }) do
      if f and PlayerFrame and f:GetParent() == PlayerFrame then f:SetParent(UIParent) end
    end
    -- keep Blizzard's combo points (they still update themselves), just on our target frame
    if ComboFrame and frames.target then
      ComboFrame:SetParent(frames.target)
      ComboFrame:SetFrameStrata("MEDIUM")   -- SetParent took our LOW strata: back above the art
      ComboFrame:ClearAllPoints()
      ComboFrame:SetPoint("TOPRIGHT", frames.target, "TOPRIGHT", -44, -9)
    end
    blizzHidden = true
  end

  ------------------------------------------------------------------- loop --

  local driver = CreateFrame("Frame")
  local ufElapsed = 0

  local function UFOnUpdate(self, elapsed)
    ufElapsed = ufElapsed + elapsed
    if ufElapsed < UF_UPDATE_INTERVAL then return end
    local dt = ufElapsed
    ufElapsed = 0
    local now = GetTime()
    for _, unit in ipairs(UNITS) do
      local f = frames[unit]
      if f:IsShown() then
        if ufTest then
          KeepAlive(f.ccList, now); KeepAlive(f.buffList, now); KeepAlive(f.debuffList, now)
        else
          f.auraTimer = f.auraTimer + dt
          if f.auraTimer >= AURA_RESCAN then ScanAuras(f) end
        end
        RenderFrame(f, now)
      end
    end
    for _, unit in ipairs(GROUP) do
      local f = frames[unit]
      if f:IsShown() then
        if ufTest then
          KeepAlive(f.ccList, now); KeepAlive(f.buffList, now); KeepAlive(f.debuffList, now)
        else
          f.auraTimer = f.auraTimer + dt
          if f.auraTimer >= AURA_RESCAN then ScanAuras(f) end
        end
        Party.Render(f, now)
      end
      if f.pet and f.pet:IsShown() then Party.RenderPet(f.pet) end
    end
  end

  function UF.SetTest(on)
    if ufState ~= "ready" then return end
    ufTest = on
    for _, unit in ipairs(UNITS) do
      local f = frames[unit]
      if on then
        UnregisterUnitWatch(f)
        f:Show()
        f:RegisterForDrag("LeftButton")
      else
        if f.moving then OnDragStop(f) end    -- finish a drag that combat interrupted
        f:RegisterForDrag()                  -- outside test mode a left click always targets
        f.fake = nil
        f.ccList, f.buffList, f.debuffList = {}, nil, nil
        f.roundSrc = nil
        ShowCast(f, nil)
        RegisterUnitWatch(f)
      end
    end
    for k, unit in ipairs(GROUP) do
      local f = frames[unit]
      if on then
        UnregisterUnitWatch(f)
        if k <= 3 then f:Show() end                  -- preview you + party1 / party2
        f:RegisterForDrag("LeftButton")
      else
        if frames[GROUP[1]].moving then Party.DragStop(f) end
        f:RegisterForDrag()
        f.fake = nil
        f.ccList, f.buffList, f.debuffList = {}, nil, nil
        Party.Watch(f)
      end
    end
    if on then FillTest(); Party.FillTest()
    elseif ComboFrame_Update then
      -- undo the faked points so Blizzard redraws the real count from zero
      for i = 1, 5 do
        local h, sh = _G["ComboPoint" .. i .. "Highlight"], _G["ComboPoint" .. i .. "Shine"]
        if h then h:SetAlpha(0) end
        if sh then sh:SetAlpha(0) end
      end
      COMBO_FRAME_LAST_NUM_POINTS = 0
      ComboFrame_Update()
    end
    for _, unit in ipairs(UNITS) do
      local f = frames[unit]
      if not on then ScanAuras(f); ReadCast(f) end
      RenderFrame(f, GetTime())
    end
    for _, unit in ipairs(GROUP) do
      local f = frames[unit]
      if not on then ScanAuras(f) end
      Party.Render(f, GetTime())
    end
  end

  local CAST_EVENTS = {
    UNIT_SPELLCAST_START = true, UNIT_SPELLCAST_CHANNEL_START = true, UNIT_SPELLCAST_DELAYED = true,
    UNIT_SPELLCAST_CHANNEL_UPDATE = true, UNIT_SPELLCAST_STOP = true, UNIT_SPELLCAST_CHANNEL_STOP = true,
    UNIT_SPELLCAST_FAILED = true, UNIT_SPELLCAST_INTERRUPTIBLE = true,
    UNIT_SPELLCAST_NOT_INTERRUPTIBLE = true,
  }

  -- the unit token now points at someone else: drop everything of the previous unit and
  -- draw the new one right away (also while hidden: the unit watch shows the frame a moment later)
  local function Refresh(f)
    if ufTest or not f then return end
    ScanAuras(f)
    if f.isParty then                     -- party boxes have their own drawing (3.4.2 crashed here)
      Party.Render(f, GetTime())
      return
    end
    f.roundSrc = nil
    ShowCast(f, nil)
    ReadCast(f)
    RenderFrame(f, GetTime())
  end

  -- Blizzard's target frame played these; it's unregistered now
  local function TargetSounds()
    if UnitExists("target") then
      if UnitIsEnemy("target", "player") then PlaySound("igCreatureAggroSelect")
      elseif UnitIsFriend("player", "target") then PlaySound("igCharacterNPCSelect")
      else PlaySound("igCreatureNeutralSelect") end
    else
      PlaySound("INTERFACESOUND_LOSTTARGETUNIT")
    end
    -- a target menu left open must not act on the new target (Blizzard closed all menus;
    -- only the target's is ours to close)
    if DropDownList1 and DropDownList1:IsShown() and UIDROPDOWNMENU_OPEN_MENU == TargetFrameDropDown then
      CloseDropDownMenus()
    end
  end

  driver:SetScript("OnEvent", function(self, event, unit)
    if event == "UNIT_AURA" then
      local f = frames[unit]
      if f and not ufTest then ScanAuras(f) end
    elseif CAST_EVENTS[event] then
      local f = frames[unit]
      if f and not ufTest then ReadCast(f) end
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
      local f = frames[unit]
      if f and not ufTest then CastInterrupted(f) end
    elseif event == "UNIT_PORTRAIT_UPDATE" then
      local f = frames[unit]
      if f then f.roundSrc = nil end
    elseif event == "PLAYER_TARGET_CHANGED" then
      if blizzHidden then TargetSounds() end
      Refresh(frames.target)
    elseif event == "PLAYER_FOCUS_CHANGED" then
      Refresh(frames.focus)
    elseif event == "PARTY_MEMBERS_CHANGED" then
      if frames.party1 and not ufTest then
        for _, unit in ipairs(GROUP) do ScanAuras(frames[unit]); Party.Render(frames[unit], GetTime()) end
      end
    elseif event == "PLAYER_REGEN_DISABLED" then
      -- Interface > Display > Screen Edge Flash: Blizzard's PlayerFrame did this
      if blizzHidden and GetCVarBool("screenEdgeFlash") and CombatFeedback_StartFullscreenStatus then
        CombatFeedback_StartFullscreenStatus()
      end
    elseif event == "PLAYER_REGEN_ENABLED" then
      if blizzHidden and CombatFeedback_StopFullscreenStatus then CombatFeedback_StopFullscreenStatus() end
      local todo = pendingOutOfCombat
      pendingOutOfCombat = {}
      for _, fn in ipairs(todo) do
        local ok, err = pcall(fn)
        if not ok then
          ufState, ufError = "error", tostring(err)
          NS.Print("|cffff4040target/focus/player frames failed:|r " .. ufError)
        end
      end
    end
  end)

  -- party frames live in their own scope (Lua 5.1 allows 200 locals per chunk); the
  -- rest of this file reaches them through Party
  Party = {}
  do
    ------------------------------------------------------------------ party --
    -- Party 1-4: minimal boxes (class-colored health fills the box, name on top, thin mana
    -- bar for mana users, CC in the middle, debuffs bottom left, important buffs bottom right)
    -- and their cooldowns as a small grid of icons on the left (time left on the used ones).

    local PARTY_W, PARTY_H, PARTY_GAP = 130, 50, 12
    local PARTY_AURA = 16
    local PARTY_CD_COLS, PARTY_CD_MAX = 6, 12
    local PARTY_POS = { "LEFT", 175, -150 }
    local DISPEL_ORDER = { Magic = 1, Curse = 2, Poison = 3, Disease = 4 }

    local function PartyDragStart(self)
      local p1 = frames[GROUP[1]]                       -- the whole stack hangs off the top box
      if ufTest and not InCombatLockdown() then
        p1.moving = true
        p1:StartMoving()
      end
    end

    local function PartyDragStop(self)
      local p1 = frames[GROUP[1]]
      if not p1.moving then return end
      p1.moving = nil
      p1:StopMovingOrSizing()
      local point, _, _, x, y = p1:GetPoint()
      local s = p1:GetScale()
      db.ufpos_party = { point, math.floor(x * s + 0.5), math.floor(y * s + 0.5) }
    end

    -- Party pets (owner: "no party pet frames at all"): Blizzard's PartyMemberFrameNPetFrame are
    -- children of the hidden party frames, so they went with them. A small clickable box right of
    -- each teammate's box: name + health (left click target, shift focus). Your own pet keeps
    -- Blizzard's PetFrame.
    local PET_W, PET_H = 80, 20
    local function CreatePetFrame(owner)
      local n = owner.unit:sub(6)
      local p = CreateFrame("Button", "ArenaFramesPartyPet" .. n, UIParent, "SecureUnitButtonTemplate")
      p.unit = "partypet" .. n
      p:SetFrameStrata("LOW")
      p:SetAttribute("unit", p.unit)
      p:SetAttribute("*type1", "target")
      p:SetAttribute("shift-type1", "focus")
      p:RegisterForClicks("AnyUp")
      p:SetScript("OnEnter", function(self)
        if UnitExists(self.unit) and UnitFrame_OnEnter then UnitFrame_OnEnter(self) end
      end)
      p:SetScript("OnLeave", function(self)
        if UnitFrame_OnLeave then UnitFrame_OnLeave(self) end
      end)
      NS.SetBorder(p)
      p:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
      p.hp = CreateFrame("StatusBar", nil, p)
      p.hp:SetStatusBarTexture(NS.FLAT)
      p.hp:SetMinMaxValues(0, 1)
      p.hp:SetPoint("TOPLEFT", p, "TOPLEFT", 1, -1)
      p.hp:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -1, 1)
      local bg = p.hp:CreateTexture(nil, "BACKGROUND")
      bg:SetAllPoints(p.hp)
      bg:SetTexture(0.15, 0.15, 0.15, 1)
      p.name = NS.NewText(p.hp, 10, "LEFT")
      p.name:SetPoint("LEFT", p.hp, "LEFT", 3, 0)
      p.name:SetWidth(PET_W - 30)
      p.name:SetHeight(12)
      p.pct = NS.NewText(p.hp, 10, "RIGHT")
      p.pct:SetPoint("RIGHT", p.hp, "RIGHT", -3, 0)
      owner.pet = p
      return p
    end

    local function RenderPet(p)
      local name, hp, maxhp, dead
      if p.fake then
        name, hp, maxhp, dead = p.fake.name, p.fake.hp, p.fake.maxhp, false
      elseif UnitExists(p.unit) then
        name, hp, maxhp = UnitName(p.unit), UnitHealth(p.unit), UnitHealthMax(p.unit)
        dead = UnitIsDeadOrGhost(p.unit)
      else
        return
      end
      maxhp = (maxhp and maxhp > 0) and maxhp or 1
      hp = math.max(0, math.min(hp or 0, maxhp))
      p.name:SetText(name or "")
      p.hp:SetMinMaxValues(0, maxhp)
      p.hp:SetValue(dead and 0 or hp)
      if dead then
        p.hp:SetStatusBarColor(0.4, 0.4, 0.4)
        p.pct:SetText("DEAD")
      else
        p.hp:SetStatusBarColor(0.2, 0.75, 0.2)
        p.pct:SetText(math.floor(hp / maxhp * 100 + 0.5) .. "%")
      end
      p:SetAlpha((p.fake or UnitInRange(p.unit)) and 1 or 0.55)
    end

    local function CreatePartyFrame(unit)
      local name = "ArenaFrames" .. unit:sub(1, 1):upper() .. unit:sub(2)   -- ArenaFramesPlayer, ArenaFramesParty1...
      local f = CreateFrame("Button", name, UIParent, "SecureUnitButtonTemplate")
      f.unit, f.isParty = unit, true
      f:SetFrameStrata("LOW")
      f:SetAttribute("unit", unit)
      f:SetAttribute("*type1", "target")
      f:SetAttribute("shift-type1", "focus")
      f:SetAttribute("*type2", "click")                 -- Blizzard's party menu, like the others
      f:SetAttribute("*clickbutton2", BLIZZARD_FRAME[unit])
      f:RegisterForClicks("AnyUp")
      f:SetMovable(true)
      f:SetClampedToScreen(true)
      f:SetScript("OnDragStart", PartyDragStart)
      f:SetScript("OnDragStop", PartyDragStop)
      f:SetScript("OnEnter", function(self)
        if UnitExists(self.unit) and UnitFrame_OnEnter then UnitFrame_OnEnter(self) end
      end)
      f:SetScript("OnLeave", function(self)
        if UnitFrame_OnLeave then UnitFrame_OnLeave(self) end
      end)
      NS.SetBorder(f)
      f:SetBackdropColor(0.05, 0.05, 0.05, 0.9)

      f.hp = CreateFrame("StatusBar", nil, f)
      f.hp:SetStatusBarTexture(NS.FLAT)
      f.hp:SetMinMaxValues(0, 1)
      local bg = f.hp:CreateTexture(nil, "BACKGROUND")
      bg:SetAllPoints(f.hp)
      bg:SetTexture(0.15, 0.15, 0.15, 1)
      local gloss = f.hp:CreateTexture(nil, "OVERLAY")
      gloss:SetAllPoints(f.hp)
      gloss:SetTexture(NS.FLAT)
      gloss:SetGradientAlpha("VERTICAL", 0, 0, 0, 0.3, 1, 1, 1, 0.08)
      f.power = CreateFrame("StatusBar", nil, f)
      f.power:SetStatusBarTexture(NS.FLAT)
      f.power:SetMinMaxValues(0, 1)
      f.power:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 1)
      f.power:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
      f.power:SetHeight(4)

      local top = CreateFrame("Frame", nil, f)           -- texts and icons above the bars
      top:SetAllPoints(f)
      top:SetFrameLevel(f.hp:GetFrameLevel() + 2)
      f.name = NS.NewText(top, 11)
      f.name:SetPoint("TOP", f, "TOP", 0, -3)
      f.name:SetWidth(PARTY_W - 8)
      f.name:SetHeight(12)
      f.status = NS.NewText(top, 11)
      f.status:SetPoint("CENTER", f, "CENTER", 0, 0)

      if unit == "player" then
        -- in combat (owner: "can't see if I'm in combat"; Blizzard's player frame showed it):
        -- crossed swords on the top-left corner + a red outline around your box
        f.combatGlow = CreateFrame("Frame", nil, f)
        f.combatGlow:SetPoint("TOPLEFT", f, "TOPLEFT", -2, 2)
        f.combatGlow:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 2, -2)
        f.combatGlow:SetBackdrop({ edgeFile = NS.FLAT, edgeSize = 2 })
        f.combatGlow:SetBackdropBorderColor(1, 0.1, 0.1, 1)
        f.combatGlow:Hide()
        f.combat = top:CreateTexture(nil, "OVERLAY")
        f.combat:SetTexture([[Interface\CharacterFrame\UI-StateIcon]])
        f.combat:SetTexCoord(0.5, 1, 0, 0.484)
        f.combat:SetWidth(22); f.combat:SetHeight(22)
        f.combat:SetPoint("CENTER", f, "TOPLEFT", 2, -2)
        f.combat:Hide()
      end

      f.cc = NS.NewIcon(top)                             -- the CC they're in, with time left
      f.cc:SetWidth(24); f.cc:SetHeight(24)
      f.cc:SetPoint("CENTER", f, "CENTER", 0, 1)
      f.cc.text:SetFont(NS.FONT, 11, "OUTLINE")
      f.cc:Hide()

      f.debuffs, f.buffs = {}, {}
      for k = 1, 4 do
        local b = NewAuraIcon(top)
        b:SetWidth(PARTY_AURA); b:SetHeight(PARTY_AURA)
        b:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 2 + (k - 1) * (PARTY_AURA + 1), 6)
        f.debuffs[k] = b
      end
      for k = 1, 3 do
        local b = NewAuraIcon(top)
        b:SetWidth(PARTY_AURA); b:SetHeight(PARTY_AURA)
        b:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2 - (k - 1) * (PARTY_AURA + 1), 6)
        f.buffs[k] = b
      end

      f.cds = {}
      for k = 1, PARTY_CD_MAX do
        local b = NS.NewIcon(f)
        b.text:SetFont(NS.FONT, 10, "OUTLINE")
        b:Hide()
        f.cds[k] = b
      end

      f.ccList = {}
      f.auraTimer = 0
      frames[unit] = f
      if unit ~= "player" then CreatePetFrame(f) end
      return f
    end

    local function ApplyPartyLayout()
      local s = db.ufscale
      local size = db.pcdsize
      for i, unit in ipairs(GROUP) do
        local f = frames[unit]
        f:SetScale(s)
        if blizzHidden then BLIZZARD_FRAME[f.unit]:SetScale(s) end
        f:SetWidth(PARTY_W)
        f:SetHeight(PARTY_H)
        f:ClearAllPoints()
        if i == 1 then
          local pos = db.ufpos_party or PARTY_POS
          f:SetPoint(pos[1], UIParent, pos[1], pos[2] / s, pos[3] / s)
        else
          f:SetPoint("TOPLEFT", frames[GROUP[i - 1]], "BOTTOMLEFT", 0, -PARTY_GAP)
        end
        for k, b in ipairs(f.cds) do                     -- grid on the left, filled from the frame outwards
          local row, col = math.floor((k - 1) / PARTY_CD_COLS), (k - 1) % PARTY_CD_COLS
          b:ClearAllPoints()
          b:SetPoint("TOPRIGHT", f, "TOPLEFT", -3 - col * (size + 2), -row * (size + 2))
          b:SetWidth(size)
          b:SetHeight(size)
        end
        if f.pet then                                    -- right of the owner's box, top-aligned
          f.pet:SetScale(s)
          f.pet:SetWidth(PET_W)
          f.pet:SetHeight(PET_H)
          f.pet:ClearAllPoints()
          f.pet:SetPoint("TOPLEFT", f, "TOPRIGHT", 3, 0)
        end
      end
    end

    -- the cooldowns shown for a party member: everyone's (trinket) + their class's baseline
    -- ones, plus talent ones once they've used them
    local function PartyCooldownList(class, race, guid, out)
      wipe(out)
      local seen = NS.cdSeen[guid]
      for _, e in ipairs(NS.cooldownsByClass[class] or NS.cooldownsByClass.ANY or {}) do
        local talent = e.talent and e.talent ~= "baseline"
        if (not talent or (seen and seen[e])) and (not e.race or e.race == race) then
          table.insert(out, e)
          if #out >= PARTY_CD_MAX then break end
        end
      end
      return out
    end

    local function RenderPartyAuras(icons, list, now, filter)
      local k = 0
      for _, a in ipairs(list or {}) do
        if k >= #icons then break end
        if (a.expires == 0 or a.expires > now) and filter(a) then
          k = k + 1
          local b = icons[k]
          b.icon:SetTexture(a.icon)
          local c = a.dtype and DebuffTypeColor and DebuffTypeColor[a.dtype]
          if c then b:SetBackdropBorderColor(c.r, c.g, c.b, 1)
          elseif a.important then b:SetBackdropBorderColor(1, 0.82, 0, 1)
          else b:SetBackdropBorderColor(0, 0, 0, 1) end
          if a.dur > 0 and a.expires > 0 then NS.SetCooldown(b, a.expires - a.dur, a.dur) else NS.SetCooldown(b, nil) end
          b.text:SetText("")
          b.count:SetText(a.count > 1 and a.count or "")
          b:Show()
        end
      end
      for j = k + 1, #icons do icons[j]:Hide() end
    end

    local function ByDispelType(a, b)
      local da, dbb = DISPEL_ORDER[a.dtype or ""] or 9, DISPEL_ORDER[b.dtype or ""] or 9
      if da ~= dbb then return da < dbb end
      return a.order < b.order
    end
    local function AnyAura() return true end
    local function ImportantAura(a) return a.important end

    local cdScratch = {}
    local function RenderParty(f, now)
      local name, class, hp, maxhp, ptype, power, maxpower, dead, _, _, guid = ReadInfo(f)
      if not name then return end
      local offline = not f.fake and not UnitIsConnected(f.unit)
      maxhp = (maxhp and maxhp > 0) and maxhp or 1
      hp = math.max(0, math.min(hp or 0, maxhp))
      f.name:SetText(name)
      f.hp:SetMinMaxValues(0, maxhp)
      f.hp:SetValue((dead or offline) and 0 or hp)
      if dead or offline then
        f.hp:SetStatusBarColor(0.4, 0.4, 0.4)
        f.status:SetText(offline and "OFFLINE" or "DEAD")
      else
        f.hp:SetStatusBarColor(NS.ClassColor(class))
        f.status:SetText("")
      end

      -- thin power bar: mana users, and always your own (your energy as a rogue)
      local showPower = (ptype or 0) == 0 or f.unit == "player"
      if showPower ~= f.powerShown then
        f.powerShown = showPower
        f.hp:ClearAllPoints()
        f.hp:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
        f.hp:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, showPower and 6 or 1)
        if showPower then f.power:Show() else f.power:Hide() end
      end
      if showPower then
        f.power:SetMinMaxValues(0, (maxpower and maxpower > 0) and maxpower or 1)
        f.power:SetValue(power or 0)
        local pc = POWER_COLORS[ptype or 0] or POWER_COLORS[0]
        f.power:SetStatusBarColor(pc[1], pc[2], pc[3])
      end

      if f.combat then
        local fight = ufTest or UnitAffectingCombat("player")   -- test mode previews it
        if fight then f.combat:Show(); f.combatGlow:Show() else f.combat:Hide(); f.combatGlow:Hide() end
      end

      -- faded out of range, like Blizzard (you're never out of your own range)
      f:SetAlpha((f.fake or f.unit == "player" or UnitInRange(f.unit)) and 1 or 0.55)

      local cc = PickCC(f, guid, now)
      if cc then
        f.cc.icon:SetTexture(cc.icon)
        local c = A.CC_COLORS[cc.kind] or A.CC_COLORS.stun
        f.cc:SetBackdropBorderColor(c[1], c[2], c[3], 1)
        local left = cc.expires > 0 and (cc.expires - now) or nil
        f.cc.text:SetText(left and (left < 10 and string.format("%.1f", left) or NS.FormatTime(left)) or "")
        f.cc:Show()
      else
        f.cc:Hide()
      end

      if f.debuffList then table.sort(f.debuffList, ByDispelType) end
      RenderPartyAuras(f.debuffs, f.debuffList, now, AnyAura)
      RenderPartyAuras(f.buffs, f.buffList, now, ImportantAura)

      local race = f.fake and f.fake.race or select(2, UnitRace(f.unit))
      local list = PartyCooldownList(class, race, guid, cdScratch)
      local used = guid and NS.cdUsed[guid]
      for k, b in ipairs(f.cds) do
        local e = list[k]
        if e then
          b.icon:SetTexture(e.icon)
          local u = used and used[e]
          if u and now < u.start + u.dur then
            NS.SetCooldown(b, u.start, u.dur)
            b.text:SetText(NS.FormatTime(u.start + u.dur - now))
          else
            NS.SetCooldown(b, nil)
            b.text:SetText("")
          end
          b:Show()
        else
          b:Hide()
        end
      end
    end

    -- shown whenever partyN exists, raid group or not: Warmane's solo queue puts the arena
    -- team in a raid group (3.4 hid them there, like Blizzard does, and they never showed)
    local function WatchParty(f)
      RegisterUnitWatch(f)
      if f.pet then
        f.pet.fake = nil
        RegisterUnitWatch(f.pet)
      end
    end

    local function FillPartyTest()
      local now = GetTime()
      local p1, p2 = frames.party1, frames.party2
      p1.fake = { name = "Elcemento", class = "ROGUE", race = "Human", hp = 15000, maxhp = 20000, ptype = 3,
        power = 60, maxpower = 100, guid = "testP1" }
      p1.ccList = { FakeAura(1833, 4, 3) }               -- Cheap Shot on your mate
      p1.ccList[1].kind = "opener"
      p1.debuffList = { FakeAura(47813, 18, 12, 0, false, nil, "Magic") }
      p1.buffList = { FakeAura(1044, 6, 5, 0, true, true) }        -- Hand of Freedom
      p2.fake = { name = "Hydramon", class = "PRIEST", hp = 9000, maxhp = 18000, ptype = 0, power = 9000,
        maxpower = 20000, guid = "testP2" }
      p2.ccList, p2.debuffList, p2.buffList = {}, {}, {}
      if p1.pet then                                     -- party pet preview
        UnregisterUnitWatch(p1.pet)
        p1.pet.fake = { name = "Felhunter", hp = 6000, maxhp = 9000 }
        p1.pet:Show()
        RenderPet(p1.pet)
      end
      local byName = NS.cooldownsByName or {}
      for _, v in ipairs({ { "testP1", "Blind", 44 }, { "testP1", "Kick", 6 }, { "testP2", "PvP Trinket", 30 } }) do
        if byName[v[2]] then NS.UseCooldown(v[1], byName[v[2]], now - (byName[v[2]].cd - v[3])) end
      end
    end

    Party.Create, Party.ApplyLayout, Party.Render = CreatePartyFrame, ApplyPartyLayout, RenderParty
    Party.Watch, Party.FillTest, Party.DragStop = WatchParty, FillPartyTest, PartyDragStop
    Party.RenderPet = RenderPet
  end

  local function Setup()
    for _, unit in ipairs(UNITS) do CreateUnitFrame(unit) end
    for _, unit in ipairs(GROUP) do Party.Create(unit) end
    ApplyUFLayout()
    for _, unit in ipairs(UNITS) do RegisterUnitWatch(frames[unit]) end
    for _, unit in ipairs(GROUP) do Party.Watch(frames[unit]) end
    HideBlizzard()
    driver:SetScript("OnUpdate", UFOnUpdate)
    ufState = "ready"
    for _, unit in ipairs(UNITS) do Refresh(frames[unit]) end
    for _, unit in ipairs(GROUP) do Refresh(frames[unit]) end
  end

  function UF.Init()
    for k, v in pairs(UF_DEFAULTS) do
      if db[k] == nil then db[k] = v end
    end
    if not db.uf then return end
    BuildNames()
    for _, e in ipairs({ "UNIT_AURA", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_PORTRAIT_UPDATE",
        "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
        "PARTY_MEMBERS_CHANGED" }) do
      driver:RegisterEvent(e)
    end
    for e in pairs(CAST_EVENTS) do driver:RegisterEvent(e) end
    if InCombatLockdown() then
      ufState = "waiting for combat to end"
      NS.Print("target/focus/player frames will appear when combat ends")
    end
    RunOutOfCombat(Setup)
  end

  function UF.IsReady() return ufState == "ready" end

  function UF.SetError(err)
    ufState, ufError = "error", tostring(err)
  end

  ------------------------------------------------------------------ slash --

  function UF.Help()
    local state = ufState == "ready" and (db.uf and "on" or "off") or ufState
    NS.Print(string.format("player/target/focus/party frames: %s,  ufscale %.2f,  pcdsize %d  (/aframes uf on|off needs /reload)",
      state, db.ufscale, db.pcdsize))
  end

  function UF.Reset()
    db.ufscale = UF_DEFAULTS.ufscale
    for _, unit in ipairs(UNITS) do db["ufpos_" .. unit] = nil end
    db.ufpos_party = nil
    db.pcdsize = UF_DEFAULTS.pcdsize
    if ufState == "ready" then RunOutOfCombat(ApplyUFLayout) end
  end

  function UF.Slash(cmd, a, n)
    if cmd == "uf" and (a == "on" or a == "off") then
      db.uf = (a == "on")
      NS.Print("player/target/focus frames " .. a .. " - type /reload to apply")
      return true
    end
    if ufState ~= "ready" then return false end
    if cmd == "pcdsize" and n then
      db.pcdsize = NS.Clamp(math.floor(n), 12, 40)
      RunOutOfCombat(ApplyUFLayout)
      NS.Print("party cooldown icon size = " .. db.pcdsize)
      return true
    end
    if cmd == "ufscale" and n then
      db.ufscale = NS.Clamp(n, 0.5, 2)
      RunOutOfCombat(ApplyUFLayout)
      NS.Print("player/target/focus scale = " .. db.ufscale)
      return true
    end
    return false
  end

  local function PartyDebug()
    NS.Print(string.format("party: %d members, raid members %d", GetNumPartyMembers(), GetNumRaidMembers()))
    for _, u in ipairs(GROUP) do
      local f = frames[u]
      if UnitExists(u) or f:IsShown() then
        NS.Print(string.format("   %s: %s, frame %s", u, UnitExists(u) and (UnitName(u) or "?") or "no unit",
          f:IsShown() and "shown" or "hidden"))
      end
    end
  end

  function UF.Debug()
    if ufState ~= "ready" then
      NS.Print("player/target/focus frames: " .. ufState .. (ufError and (" - " .. ufError) or "") ..
        (db.uf and "" or " (/aframes uf on, then /reload)"))
      return
    end
    local now = GetTime()
    for _, unit in ipairs(UNITS) do
      local f = frames[unit]
      if f:IsShown() then
        local name, class, hp, maxhp, _, _, _, dead, isPlayer, _, guid = ReadInfo(f)
        NS.Print(string.format("%s: %s (%s) %s/%s%s", unit, tostring(name), tostring(class),
          tostring(hp), tostring(maxhp), dead and " DEAD" or ""))
        local cc = PickCC(f, guid, now)
        NS.Print("   portrait: " .. (cc and string.format("%s (spell %s, %.1fs left)", cc.kind,
          tostring(cc.spell), cc.expires > 0 and cc.expires - now or 0) or "class icon / portrait"))
        local kinds = {}
        for _, c in ipairs(f.ccList) do table.insert(kinds, c.kind .. " " .. tostring(c.spell)) end
        if #kinds > 0 then NS.Print("   CCs on it: " .. table.concat(kinds, ", ")) end
        if f.cast then
          NS.Print(string.format("   important buffs: %d, your debuffs: %d, cast: %s",
            f.buffList and #f.buffList or 0, f.debuffList and #f.debuffList or 0,
            f.cast.info and f.cast.info.name or "-"))
        end
        if f.sap then
          local yn = function(v) return v and "yes" or "no" end
          local isPlayer, enemy, attackable, dead, apiCombat, logCombat = SapChecks(f.unit)
          NS.Print(string.format("   sappable: %s (player %s, enemy %s, attackable %s, dead %s, " ..
            "in combat: API %s, combat log %s)", yn(Sappable(f)), yn(isPlayer), yn(enemy), yn(attackable),
            yn(dead), yn(apiCombat), CombatPlates_InCombat and yn(logCombat) or "n/a - CombatPlates not loaded"))
        end
      else
        NS.Print(unit .. ": none")
      end
    end
    PartyDebug()
  end
end
UnitFramesModule()

--[[
  Alerts, by your own class / spec (owner: "differentiate: SWD poly/scatter for disc priest,
  for the rogue only kickable Poly and heals"):
  * Rogue: an enemy (arena1-5, target, focus) casts something you want to Kick - Polymorph
    or a heal (Penance, Flash Heal, Greater Heal, Flash of Light, Holy Light, Healing Wave,
    Chain Heal, Regrowth, Nourish...). Shows the cast with time left and your Kick: "KICK!"
    when it's ready, you have the energy and the caster is in range; else why not.
    Uninterruptible casts are left out.
  * Disc priest: an enemy Polymorph or Succubus Seduction cast (both break on damage, so the
    SWD backlash breaks them) -> Shadow Word: Death with the cast's time left and
    "NOW" just before it lands (your latency counted in); and a hunter with Scatter Shot ready
    close to you (~11 yd red, ~28 yd yellow). Mages Poly through focus / arena1-3 macros, and
    3.3.5 can't show an enemy's focus (no "arena1focus" unit) nor a cast's target, so: caster's
    target is you -> "Polymorph on you"; else, within SWD range -> "Polymorph (you?)" (owner:
    "mostly no one target polys"; `/aframes swd target` = only the first kind). If the server
    ever puts the target in SPELL_CAST_START, that wins (/aframes debug shows what it sends).
    Succubi are watched as arenapet1-5 in arena; elsewhere only as your target / focus.
  Display only: nothing is cast for you.
]]
local function AlertsModule()
  local Alerts = {}
  NS.Alerts = Alerts

  local MAX_ROWS = 3
  local ALERT_DEFAULTS = { alerts = true, apoint = "CENTER", ax = 0, ay = 170, swdpoly = "all",
    los = true, loshp = 50, losparty = false, lowcall = true, lowhp = 35,
    swdbutton = true, swdsize = 64, sbpoint = "CENTER", sbx = -200, sby = 150 }
  -- rogue: casts worth a Kick (names from these IDs cover every rank / Polymorph variant)
  local KICK_IDS = { 118, 2061, 2060, 47540, 596, 32546, 64843, 19750, 635, 331, 8004, 1064, 5185, 8936,
    50464, 740 }
  local POLY_ID, SWD_ID, KICK_ID, SCATTER_ID, SEDUCE_ID = 118, 32379, 1766, 19503, 6358
  local SWD_WINDOW = 0.9              -- press SWD with at most latency + this left (backlash ticks at +1.0 s)
  local kickNames, polyName, swdName, kickName = {}, nil, nil, nil
  local swdCasts = {}                 -- spell name -> true: casts SWD answers (Polymorph, Seduction)
  local profile                       -- "rogue", "disc" or nil
  local polyDest = {}                 -- caster GUID -> { dst = GUID or nil, t = GetTime() }
  local lastPolyStart                 -- what the last enemy Poly / Seduction cast start said (debug)
  -- 3.15.2 (owner: "mage casted poly near me a couple of times and swd didn't appear"; the log shows 4
  -- Polys on him from his focus mage, the code can't explain it): every enemy Poly / Seduction cast is
  -- recorded with what the alert saw (db.swdTrace, last 20) -> read from SavedVariables after a /reload
  local tracing = {}                  -- caster GUID -> { e = trace entry, t = GetTime() }
  -- 3.16 (owner: "stop LoSing me notification for priest, if party is low and LoSing / out of ranging me"):
  -- range = Flash Heal out of range; LoS has no API on 3.3.5, so it's known only when a cast of yours on
  -- that teammate fails with "Target not in line of sight" (UNIT_SPELLCAST_SENT gives the target name)
  local FLASH_ID, LOS_HOLD = 2061, 4
  local PENANCE_ID, recheck = 47540, 0
  local flashName
  local sentTarget, sentAt            -- name of your last cast's target, GetTime() it was sent
  local losUntil = {}                 -- teammate name -> GetTime() until which he counts as out of LoS
  local losSince, losSaid = {}, {}    -- name -> start of the current warning (sound once) / last party message
  -- 3.20 (owner: "announce on priest that I'm low, need BoP if we have a pala, or need peel"): under lowhp
  -- in arena combat, once per dip (rearmed above lowhp + 15, at most every 12 s), party chat says who hit
  -- you in the last 5 s and asks the paladin for BoP (mostly physical damage, BoP not used, no Forbearance
  -- on you) or Sacrifice, else for a peel
  local HELP_WINDOW, HELP_GAP, HELP_REARM = 5, 12, 15
  local FORBEARANCE_ID = 25771
  local CLASS_WORD = { WARRIOR = "warr", ROGUE = "rogue", PALADIN = "pala", DEATHKNIGHT = "dk", HUNTER = "hunter",
    DRUID = "druid", SHAMAN = "sham", MAGE = "mage", WARLOCK = "lock", PRIEST = "priest" }
  local hits = {}                     -- attacker GUID -> { name, class, phys, magic, t }
  local helpArmed, helpSaid, lastHelp = true, -100, nil
  local mover, rows = nil, {}
  local alertTest = false
  local elapsed = 0

  local function SpellName(id) return (GetSpellInfo(id)) end
  local function SpellIcon(id) return select(3, GetSpellInfo(id)) or NS.UNKNOWN_ICON end

  -- your class / spec decides which alerts you get
  local function PlayerProfile()
    local _, class = UnitClass("player")
    if class == "ROGUE" then return "rogue" end
    if class == "PRIEST" then
      -- 3.17.1: after a fresh login the talent trees can read 0 points for a while (owner's
      -- Simulator stayed "no profile" a whole session); Penance in the spellbook = disc
      local penance = GetSpellInfo(PENANCE_ID)
      if penance and GetSpellInfo(penance) then return "disc" end
      local best, bestPts = nil, -1
      for tab = 1, 3 do
        local _, _, pts = GetTalentTabInfo(tab)
        if (pts or 0) > bestPts then best, bestPts = tab, pts or 0 end
      end
      if best == 1 and bestPts > 0 then return "disc" end
    end
    return nil
  end

  local function NewRow(i)
    local r = CreateFrame("Frame", "ArenaFramesAlert" .. i, mover)
    r:SetWidth(260); r:SetHeight(40)
    r:SetPoint("TOP", mover, "BOTTOM", 0, -4 - (i - 1) * 46)
    r.icon = NS.NewIcon(r)
    r.icon:SetWidth(40); r.icon:SetHeight(40)
    r.icon:SetPoint("LEFT", r, "LEFT", 0, 0)
    r.bar = CreateFrame("StatusBar", nil, r)
    r.bar:SetStatusBarTexture(NS.FLAT)
    r.bar:SetMinMaxValues(0, 1)
    r.bar:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 4, 1)
    r.bar:SetPoint("RIGHT", r, "RIGHT", 0, 0)
    r.bar:SetHeight(12)
    local bg = r.bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(r.bar)
    bg:SetTexture(0, 0, 0, 0.6)
    r.label = NS.NewText(r, 12, "LEFT")
    r.label:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 4, -2)
    r.label:SetPoint("RIGHT", r, "RIGHT", -70, 0)
    r.label:SetHeight(14)
    r.status = NS.NewText(r, 14, "RIGHT")
    r.status:SetPoint("TOPRIGHT", r, "TOPRIGHT", 0, -1)
    r.time = NS.NewText(r.bar, 10, "RIGHT")
    r.time:SetPoint("RIGHT", r.bar, "RIGHT", -2, 0)
    r:Hide()
    return r
  end

  local function ApplyAlertLayout()
    mover:ClearAllPoints()
    mover:SetPoint(db.apoint, UIParent, db.apoint, db.ax, db.ay)
    mover:SetWidth(260)
    mover:SetHeight(16)
  end

  local GREEN, YELLOW, GREY, RED = { 0.2, 1, 0.2 }, { 1, 0.85, 0.1 }, { 0.6, 0.6, 0.6 }, { 1, 0.15, 0.15 }

  local function ShowRow(r, icon, label, status, statusColor, barValue, timeText, glow)
    r.icon.icon:SetTexture(icon)
    r.label:SetText(label)
    r.status:SetText(status)
    r.status:SetTextColor(statusColor[1], statusColor[2], statusColor[3])
    r.bar:SetValue(barValue)
    r.bar:SetStatusBarColor(statusColor[1], statusColor[2], statusColor[3])
    r.time:SetText(timeText)
    if glow then r.icon:SetBackdropBorderColor(statusColor[1], statusColor[2], statusColor[3], 1)
    else r.icon:SetBackdropBorderColor(0, 0, 0, 1) end
    r:Show()
  end

  -- the units whose casts we watch, each enemy once
  local WATCH = { "arena1", "arena2", "arena3", "arena4", "arena5", "target", "focus" }
  -- disc: also the arena pets (Succubus Seduction)
  local DISC_WATCH = { "arena1", "arena2", "arena3", "arena4", "arena5", "arenapet1", "arenapet2", "arenapet3",
    "arenapet4", "arenapet5", "target", "focus" }
  local seenGuid = {}

  local function CastOf(u)
    local name, _, _, icon, s, e, _, _, notInt = UnitCastingInfo(u)
    if not name then
      name, _, _, icon, s, e, _, notInt = UnitChannelInfo(u)
    end
    if name and s and e then return name, icon, s / 1000, e / 1000, notInt end
  end

  local function CallerLabel(u)
    local n = UnitName(u) or "?"
    local i = NS.ArenaIndexOf(UnitGUID(u)) or u:match("^arenapet(%d)$")
    return i and (n .. " (" .. i .. ")") or n
  end

  local function KickStatus(u, now)
    local start, dur = GetSpellCooldown(kickName)
    local left = (start and start > 0) and (start + dur - now) or 0
    if left > 1.5 then return string.format("Kick %.1f", left), GREY, false end   -- not just the GCD
    local usable, noEnergy = IsUsableSpell(kickName)
    if noEnergy then return "no energy", GREY, false end
    if IsSpellInRange(kickName, u) ~= 1 then return "out of range", YELLOW, false end
    return "KICK!", GREEN, true
  end

  local function RogueAlerts(now)
    local n = 0
    wipe(seenGuid)
    for _, u in ipairs(WATCH) do
      local guid = UnitExists(u) and UnitCanAttack("player", u) and UnitGUID(u)
      if guid and not seenGuid[guid] then
        seenGuid[guid] = true
        local name, icon, s, e, notInt = CastOf(u)
        if name and kickNames[name] and not notInt and now < e and n < MAX_ROWS then
          n = n + 1
          local status, col, glow = KickStatus(u, now)
          ShowRow(rows[n], icon, name .. " - " .. CallerLabel(u), status, col,
            (now - s) / math.max(e - s, 0.01), string.format("%.1f", e - now), glow)
        end
      end
    end
    return n
  end

  local swdBest                       -- "now" / "wait" / nil: the most urgent SWD alert this tick
  local function DiscAlerts(now)
    swdBest = nil
    local n = 0
    wipe(seenGuid)
    local latency = (select(3, GetNetStats()) or 100) / 1000
    for _, u in ipairs(DISC_WATCH) do
      local guid = UnitExists(u) and UnitCanAttack("player", u) and UnitGUID(u)
      if guid and not seenGuid[guid] and n < MAX_ROWS then
        seenGuid[guid] = true
        -- Polymorph / Seduction that may be aimed at you: his target is you, or (focus / arena
        -- macro) he is within SWD range; a target sent in SPELL_CAST_START overrides both
        local name, _, s, e = CastOf(u)
        local onYou, maybe = false, false
        if name and swdCasts[name] and now < e then
          local sent = polyDest[guid]
          if sent and sent.dst and sent.t >= s - 0.5 then
            onYou = (sent.dst == UnitGUID("player"))
          else
            onYou = UnitIsUnit(u .. "target", "player") and true or false
            maybe = not onYou and db.swdpoly ~= "target" and IsSpellInRange(swdName, u) ~= 0
          end
        end
        local tr = name and swdCasts[name] and tracing[guid]
        if tr and not tr.e.unit then
          tr.e.unit, tr.e.cast = u, string.format("%s %.2fs left", name, e - now)
          tr.e.targetsMe, tr.e.range = onYou and "yes" or "no", tostring(IsSpellInRange(swdName, u))
        end
        if onYou or maybe then
          n = n + 1
          local left = e - now
          local cdStart, cdDur = GetSpellCooldown(swdName)
          local swdLeft = (cdStart and cdStart > 0) and (cdStart + cdDur - now) or 0
          local status, col, glow
          -- the SWD backlash (32409) is a 1 s DoT that ticks once 1.0 s after SWD hits, and that
          -- tick breaks the CC: it must land after the Poly / Seduction, and SWD must reach the
          -- server before it. Window: latency + 1.0 s .. latency left on the cast bar.
          if swdLeft > left then status, col, glow = "SWD on cd", GREY, false
          elseif left <= latency then status, col, glow = "too late", GREY, false
          elseif left <= latency + SWD_WINDOW then status, col, glow = "NOW!", RED, true
          else status, col, glow = string.format("SWD in %.1f", left - latency - SWD_WINDOW), YELLOW, false end
          if glow then swdBest = "now"
          elseif col == YELLOW then if swdBest ~= "now" then swdBest = "wait" end
          elseif not swdBest then swdBest = "cd" end            -- on cooldown / too late: shown grey
          if tr and not tr.e.alert then tr.e.alert = status end
          ShowRow(rows[n], SpellIcon(SWD_ID), name .. (onYou and " on you - " or " (you?) - ")
            .. CallerLabel(u), status, col,
            (now - s) / math.max(e - s, 0.01), string.format("%.1f", left), glow)
        end
        -- a hunter with Scatter Shot ready, close to you
        local _, class = UnitClass(u)
        if class == "HUNTER" and n < MAX_ROWS then
          local e2 = NS.cooldownsByName and NS.cooldownsByName["Scatter Shot"]
          local u2 = e2 and NS.cdUsed[guid] and NS.cdUsed[guid][e2]
          local ready = not (u2 and now < u2.start + u2.dur)
          local seen = e2 and NS.cdSeen[guid] and NS.cdSeen[guid][e2]
          local spec = NS.SpecOf(guid)
          local has = seen or spec == "Marksmanship" or (spec == nil and "maybe")
          if ready and has then
            local close, near = CheckInteractDistance(u, 2), CheckInteractDistance(u, 4)
            if close or near then
              n = n + 1
              ShowRow(rows[n], SpellIcon(SCATTER_ID), "Scatter " .. (has == "maybe" and "maybe " or "") ..
                "ready - " .. CallerLabel(u), close and "IN RANGE" or "close", close and RED or YELLOW, 1, "",
                close and true or false)
            end
          end
        end
      end
    end
    return n
  end

  local function Short(name) return name and (name:match("^([^%-]+)") or name) end

  local function LosCheck(u, now, n)
    if n >= MAX_ROWS or not UnitExists(u) or UnitIsUnit(u, "player") or UnitIsDeadOrGhost(u)
        or not UnitIsConnected(u) then return n end
    local max = UnitHealthMax(u) or 0
    local pct = max > 0 and UnitHealth(u) / max or 1
    local name = Short(UnitName(u))
    local los = name and losUntil[name] and now < losUntil[name]
    local far = not los and flashName and IsSpellInRange(flashName, u) == 0
    if pct * 100 > db.loshp or not (los or far) then
      if name then losSince[name] = nil end
      return n
    end
    n = n + 1
    ShowRow(rows[n], SpellIcon(FLASH_ID), string.format("%s %d%% - %s", name, math.floor(pct * 100 + 0.5),
      los and "stop LoSing me" or "come closer"), los and "NO LOS" or "OUT OF RANGE", RED, pct, "", true)
    if not losSince[name] then
      losSince[name] = now
      PlaySound("RaidWarning")
      if db.losparty and select(2, IsInInstance()) == "arena" and now - (losSaid[name] or -100) > 8 then
        losSaid[name] = now
        local msg = string.format("%s, %s! (%d%%)", name, los and "stop LoSing me" or "come to me, out of range",
          math.floor(pct * 100 + 0.5))
        if GetNumPartyMembers() > 0 then SendChatMessage(msg, "PARTY")
        elseif GetNumRaidMembers() > 0 then SendChatMessage(msg, "RAID") end
      end
    end
    return n
  end

  -- teammates who are low and that you can't heal (out of range / out of LoS), in combat only
  local function LosAlerts(now, n)
    if not db.los or not UnitAffectingCombat("player") then
      wipe(losSince)
      return n
    end
    local party = GetNumPartyMembers()
    if party > 0 then
      for i = 1, party do n = LosCheck("party" .. i, now, n) end
    else
      for i = 1, GetNumRaidMembers() do n = LosCheck("raid" .. i, now, n) end
    end
    return n
  end

  local function AttackerClass(guid)
    local i = NS.ArenaIndexOf(guid)
    if i and UnitGUID("arena" .. i) == guid then return select(2, UnitClass("arena" .. i)) end
    for _, u in ipairs({ "target", "focus", "mouseover" }) do
      if UnitGUID(u) == guid then return select(2, UnitClass(u)) end
    end
  end

  local function TookDamage(guid, name, phys, amount)
    local h = hits[guid]
    if not h then h = { name = name, phys = 0, magic = 0 }; hits[guid] = h end
    local now = GetTime()
    if now - (h.t or now) > HELP_WINDOW then h.phys, h.magic = 0, 0 end
    h.t = now
    h.class = h.class or AttackerClass(guid)
    if phys then h.phys = h.phys + amount else h.magic = h.magic + amount end
  end

  local function TeamPaladin()
    local party = GetNumPartyMembers()
    local prefix, n = party > 0 and "party" or "raid", party > 0 and party or GetNumRaidMembers()
    for i = 1, n do
      local u = prefix .. i
      if select(2, UnitClass(u)) == "PALADIN" and not UnitIsUnit(u, "player") and not UnitIsDeadOrGhost(u)
          and UnitIsConnected(u) then return u end
    end
  end

  local function CdReady(guid, name, now)
    local e = NS.cooldownsByName and NS.cooldownsByName[name]
    local u = e and NS.cdUsed[guid] and NS.cdUsed[guid][e]
    return not (u and now < u.start + u.dur)
  end

  local function HasDebuff(unit, name)
    for i = 1, 40 do
      local n = UnitAura(unit, i, "HARMFUL")
      if not n then return false end
      if n == name then return true end
    end
  end

  local function HelpMessage(now, pct)
    local list, phys, total = {}, 0, 0
    for guid, h in pairs(hits) do
      if now - h.t > HELP_WINDOW then hits[guid] = nil
      else
        table.insert(list, h)
        phys, total = phys + h.phys, total + h.phys + h.magic
      end
    end
    table.sort(list, function(a, b) return a.phys + a.magic > b.phys + b.magic end)
    local who = {}
    for i = 1, math.min(2, #list) do who[i] = CLASS_WORD[list[i].class or ""] or Short(list[i].name) end
    local on = #who > 0 and (" - " .. table.concat(who, " + ") .. " on me") or ""
    local p = math.floor(pct * 100 + 0.5)
    local pala = TeamPaladin()
    if pala then
      local guid, name = UnitGUID(pala), Short(UnitName(pala))
      local forb = SpellName(FORBEARANCE_ID)
      if total > 0 and phys / total >= 0.6 and CdReady(guid, "Hand of Protection", now)
          and not (forb and HasDebuff("player", forb)) then
        return string.format("%s, BOP me! %d%%%s", name, p, on)
      elseif CdReady(guid, "Hand of Sacrifice", now) then
        return string.format("%s, SAC me! %d%%%s", name, p, on)
      end
    end
    return string.format("PEEL me! %d%%%s", p, on)
  end

  local function LowCall(now)
    if not db.lowcall or select(2, IsInInstance()) ~= "arena" or UnitIsDeadOrGhost("player") then return end
    local max = UnitHealthMax("player") or 0
    local pct = (max > 0 and UnitHealth("player") / max or 1) * 100
    if pct > db.lowhp + HELP_REARM then helpArmed = true end
    if not helpArmed or pct > db.lowhp or not UnitAffectingCombat("player") or now - helpSaid < HELP_GAP then return end
    helpArmed, helpSaid = false, now
    lastHelp = HelpMessage(now, pct / 100)
    if GetNumPartyMembers() > 0 then SendChatMessage(lastHelp, "PARTY")
    elseif GetNumRaidMembers() > 0 then SendChatMessage(lastHelp, "RAID") end
  end

  ------------------------------------------------------------- SWD button --
  -- Big clickable SWD (owner: "big swd icon and stopcasting so I can click swd instantly"): a
  -- SecureActionButton with a fixed macro that YOU click (like an action button, no automation).
  -- Its target can't change in combat, so the macro picks the first of: your target if it's a
  -- live enemy, focus, arena1-5. Any enemy works: the backlash comes from SWD hitting someone.
  -- The button shows who it will hit. Keybind: a macro with /click ArenaFramesSWD.
  -- Only visible while a Poly / Seduction alert runs (owner: "should be displayed only when poly is
  -- casted"). Show / Hide are protected in combat, so: hidden out of combat, shown at alpha 0 the
  -- moment combat starts (REGEN_DISABLED fires before the lockdown), then alpha 1 during an alert.
  -- While invisible in combat it still takes clicks on its spot: nothing else is possible on 3.3.5.
  local SWD_UNITS = { "target", "focus", "arena1", "arena2", "arena3", "arena4", "arena5" }
  local swdBtn, swdPending

  local function SwdMacro()
    local conds = {}
    for _, u in ipairs(SWD_UNITS) do
      table.insert(conds, u == "target" and "[harm,nodead]" or ("[target=" .. u .. ",harm,nodead]"))
    end
    return "/stopcasting\n/cast " .. table.concat(conds) .. " " .. swdName
  end

  -- the unit the macro will pick right now (same order as the macro's conditions)
  local function SwdUnit()
    for _, u in ipairs(SWD_UNITS) do
      if UnitExists(u) and UnitCanAttack("player", u) and not UnitIsDeadOrGhost(u) then return u end
    end
  end

  local function SwdDragStart(self)
    if alertTest and not InCombatLockdown() then self:StartMoving() end
  end
  local function SwdDragStop(self)
    self:StopMovingOrSizing()
    local point, _, _, x, y = self:GetPoint()
    db.sbpoint, db.sbx, db.sby = point, math.floor(x + 0.5), math.floor(y + 0.5)
  end

  local function CreateSwdButton()
    local b = CreateFrame("Button", "ArenaFramesSWD", UIParent, "SecureActionButtonTemplate")
    b:SetFrameStrata("MEDIUM")
    b:RegisterForClicks("AnyUp")
    b:SetMovable(true)
    b:SetClampedToScreen(true)
    b:SetScript("OnDragStart", SwdDragStart)
    b:SetScript("OnDragStop", SwdDragStop)
    NS.SetBorder(b)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
    b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
    b.icon:SetTexture(SpellIcon(SWD_ID))
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.cd = CreateFrame("Cooldown", nil, b)
    b.cd:SetAllPoints(b.icon)
    local top = CreateFrame("Frame", nil, b)          -- texts above the cooldown sweep
    top:SetAllPoints(b)
    top:SetFrameLevel(b.cd:GetFrameLevel() + 2)
    b.now = NS.NewText(top, 20)
    b.now:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.now:SetTextColor(1, 0.15, 0.15)
    b.who = NS.NewText(top, 11)
    b.who:SetPoint("TOP", b, "BOTTOM", 0, -3)
    swdBtn = b
  end

  -- everything protected (create, attributes, show / hide, size, position): out of combat only
  local function ApplySwdButton()
    if InCombatLockdown() then swdPending = true; return end
    swdPending = nil
    local want = db.swdbutton and profile == "disc"
    if not swdBtn then
      if not want then return end
      CreateSwdButton()
    end
    local b = swdBtn
    b:SetWidth(db.swdsize); b:SetHeight(db.swdsize)
    b:ClearAllPoints()
    b:SetPoint(db.sbpoint, UIParent, db.sbpoint, db.sbx, db.sby)
    if alertTest then                                 -- unlocked: drag it, clicks do nothing
      b:SetAttribute("type", nil)
      b:RegisterForDrag("LeftButton")
    else
      b:SetAttribute("type", "macro")
      b:SetAttribute("macrotext", SwdMacro())
      b:RegisterForDrag()
    end
    if want and alertTest then b:Show(); b:SetAlpha(1) else b:Hide() end
  end

  local function SwdWanted() return swdBtn and db.swdbutton and profile == "disc" end

  local function RenderSwdButton(now)
    local b = swdBtn
    if not SwdWanted() or swdPending then return end
    local state = alertTest and "now" or swdBest
    if InCombatLockdown() then
      b:SetAlpha(state and 1 or 0)                    -- can't Show / Hide now
    elseif state then
      b:Show(); b:SetAlpha(1)
    else
      b:Hide()
    end
    if not state then return end
    local start, dur = GetSpellCooldown(swdName)
    if start and start > 0 and dur > 1.5 then
      if b.cdStart ~= start then b.cd:SetCooldown(start, dur); b.cdStart = start end
    elseif b.cdStart then
      b.cd:SetCooldown(0, 0); b.cdStart = nil
    end
    if state == "now" then
      b:SetBackdropBorderColor(1, 0.15, 0.15, 1)
      b.now:SetText((math.floor(now * 6) % 2 == 0) and "NOW!" or "")   -- blinks 3x a second
    elseif state == "wait" then
      b:SetBackdropBorderColor(1, 0.85, 0.1, 1)
      b.now:SetText("")
    else
      b:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
      b.now:SetText("")
    end
    local u = alertTest and "focus" or SwdUnit()
    if alertTest then
      b.who:SetText("-> Frostbolt (focus)")
      b.who:SetTextColor(1, 1, 1)
    elseif u then
      b.who:SetText("-> " .. (UnitName(u) or "?") .. " (" .. u .. ")")
      if IsSpellInRange(swdName, u) == 0 then b.who:SetTextColor(1, 0.3, 0.3) else b.who:SetTextColor(1, 1, 1) end
    else
      b.who:SetText("no enemy to SWD")
      b.who:SetTextColor(1, 0.3, 0.3)
    end
  end

  local function PreviewRows()
    if profile == "disc" then
      ShowRow(rows[1], SpellIcon(SWD_ID), "Polymorph on you - Frostbolt (3)", "NOW!", RED, 0.85, "0.2", true)
      ShowRow(rows[2], SpellIcon(SCATTER_ID), "Scatter ready - Huntard (2)", "IN RANGE", RED, 1, "", true)
      ShowRow(rows[3], SpellIcon(FLASH_ID), "Kisame 34% - stop LoSing me", "NO LOS", RED, 0.34, "", true)
      return 3
    end
    ShowRow(rows[1], SpellIcon(19750), "Flash of Light - Healbot (2)", "KICK!", GREEN, 0.4, "0.9", true)
    ShowRow(rows[2], SpellIcon(POLY_ID), "Polymorph - Frostbolt (3)", "out of range", YELLOW, 0.7, "0.5", false)
    return 2
  end

  local function Update(self, dt)
    elapsed = elapsed + dt
    if elapsed < 0.05 then return end
    elapsed = 0
    local now, n = GetTime(), 0
    swdBest = nil
    if not profile and now - recheck > 2 then      -- talents / spellbook may load after login
      recheck = now
      profile = PlayerProfile()
      if profile then ApplySwdButton() end
    end
    if alertTest then n = PreviewRows()
    elseif db.alerts and profile == "rogue" then n = RogueAlerts(now)
    elseif db.alerts and profile == "disc" then n = LosAlerts(now, DiscAlerts(now)) end
    if profile == "disc" and not alertTest then LowCall(now) end
    for i = n + 1, MAX_ROWS do rows[i]:Hide() end
    RenderSwdButton(now)
    for guid, tr in pairs(tracing) do
      local e = tr.e
      if now - tr.t > 3 then
        tracing[guid] = nil
      elseif e.alert and not e.button then
        e.button = not swdBtn and "none" or string.format("shown %s, alpha %.1f, pending %s, combat %s",
          swdBtn:IsShown() and "yes" or "no", swdBtn:GetAlpha(), tostring(swdPending), tostring(InCombatLockdown()))
      end
    end
  end

  local driver = CreateFrame("Frame")
  driver:SetScript("OnEvent", function(self, event, a1, sub, srcGUID, srcName, srcFlags, dstGUID, dstName, _, p9,
      spellName, school, amount)
    if event == "UNIT_SPELLCAST_SENT" then              -- unit, spell, rank, target name
      if a1 == "player" then sentTarget, sentAt = Short(srcName), GetTime() end
      return
    elseif event == "UI_ERROR_MESSAGE" then
      if a1 == SPELL_FAILED_LINE_OF_SIGHT and sentTarget and GetTime() - sentAt < 2 then
        losUntil[sentTarget] = GetTime() + LOS_HOLD
      end
      return
    end
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
      -- a heal / shield of yours landed on him: he's back in LoS
      if (sub == "SPELL_HEAL" or sub == "SPELL_AURA_APPLIED" or sub == "SPELL_AURA_REFRESH")
          and bit.band(srcFlags or 0, 0x1) ~= 0 and dstName then
        losUntil[Short(dstName)] = nil
      end
      -- damage on you (arena only): who's hitting you, physical or magic, for the low-health call
      if profile == "disc" and dstGUID and dstGUID == UnitGUID("player") and srcGUID and srcGUID ~= dstGUID
          and select(2, IsInInstance()) == "arena" then
        if sub == "SWING_DAMAGE" then TookDamage(srcGUID, srcName, true, tonumber(p9) or 0)
        elseif sub == "RANGE_DAMAGE" or sub == "SPELL_DAMAGE" or sub == "SPELL_PERIODIC_DAMAGE" then
          TookDamage(srcGUID, srcName, school == 1, tonumber(amount) or 0)
        end
      end
      if sub == "SPELL_CAST_START" and spellName and swdCasts[spellName] and profile == "disc"
          and bit.band(srcFlags or 0, 0x1) == 0 then
        local dst = dstGUID
        if dst == "" or dst == "0x0000000000000000" then dst = nil end
        polyDest[srcGUID] = { dst = dst, t = GetTime() }
        lastPolyStart = spellName .. " by " .. (srcName or "?") .. " -> "
          .. (dst and (dstName or dst) or "no target in the log")
      end
      if sub == "SPELL_CAST_START" and spellName and swdCasts[spellName] and bit.band(srcFlags or 0, 0x40) ~= 0 then
        db.swdTrace = db.swdTrace or {}
        local e = { when = date("%m/%d %H:%M:%S"), spell = spellName, caster = srcName or "?",
          profile = tostring(profile), alerts = tostring(db.alerts), swd = tostring(db.swdpoly),
          zone = select(2, IsInInstance()) }
        table.insert(db.swdTrace, e)
        while #db.swdTrace > 20 do table.remove(db.swdTrace, 1) end
        tracing[srcGUID] = { e = e, t = GetTime() }
      end
      return
    end
    if event == "PLAYER_ENTERING_WORLD" then wipe(polyDest); wipe(hits); helpArmed = true end
    if event == "PLAYER_REGEN_ENABLED" then
      if swdPending then ApplySwdButton() end
      return
    end
    local old = profile
    profile = PlayerProfile()
    if profile ~= old or not swdBtn then ApplySwdButton() end
  end)

  function Alerts.Init()
    for k, v in pairs(ALERT_DEFAULTS) do
      if db[k] == nil then db[k] = v end
    end
    for _, id in ipairs(KICK_IDS) do
      local name = SpellName(id)
      if name then kickNames[name] = true end
    end
    polyName, swdName, kickName = SpellName(POLY_ID), SpellName(SWD_ID), SpellName(KICK_ID)
    flashName = SpellName(FLASH_ID)
    for _, id in ipairs({ POLY_ID, SEDUCE_ID }) do
      local name = SpellName(id)
      if name then swdCasts[name] = true end
    end
    mover = NS.NewMover("ArenaFramesAlerts", "Alerts - drag", "apoint", "ax", "ay")
    for i = 1, MAX_ROWS do rows[i] = NewRow(i) end
    table.insert(NS.extraMovers, mover)
    mover.bg:Hide(); mover.label:Hide(); mover:EnableMouse(false)
    ApplyAlertLayout()
    profile = PlayerProfile()
    ApplySwdButton()
    for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED",
        "COMBAT_LOG_EVENT_UNFILTERED", "PLAYER_REGEN_ENABLED", "UNIT_SPELLCAST_SENT", "UI_ERROR_MESSAGE" }) do
      driver:RegisterEvent(e)
    end
    driver:SetScript("OnUpdate", Update)
  end

  -- called by the core on PLAYER_REGEN_DISABLED after test mode ended (that would Hide it): the
  -- last moment Show() is allowed, so the button goes in shown but invisible
  function Alerts.EnterCombat()
    if SwdWanted() and not swdPending and not InCombatLockdown() then
      swdBtn:SetAlpha(swdBest and 1 or 0)
      swdBtn:Show()
    end
  end

  function Alerts.SetTest(on)
    if not mover then return end
    alertTest = on
    ApplySwdButton()
  end

  function Alerts.Help()
    NS.Print(string.format("/aframes alerts on|off (now %s): %s", db.alerts and "on" or "off",
      profile == "rogue" and "Kick alerts for Polymorph and heals"
      or profile == "disc" and "SWD on Polymorph / Seduction aimed at you, Scatter warning, low teammate out of LoS / range"
      or "no alerts for your class / spec yet"))
    if profile == "disc" then
      NS.Print(string.format("/aframes swd all|target (now %s): all = every enemy Polymorph / Seduction within"
        .. " SWD range (focus / arena macros), target = only when the caster targets you", db.swdpoly))
      NS.Print(string.format("/aframes swdbutton on|off (now %s), swdsize 32-128 (now %d): big SWD button,"
        .. " click = /stopcasting + SWD on your enemy target, else focus, else arena1-5;"
        .. " keybind: a macro with /click ArenaFramesSWD", db.swdbutton and "on" or "off", db.swdsize))
      NS.Print(string.format("/aframes los on|off (now %s), loshp 20-90 (now %d%%), losparty on|off (now %s):"
        .. " teammate under loshp you can't heal (out of range, or your cast on him failed: not in LoS);"
        .. " losparty also tells him in party chat (arena)", db.los and "on" or "off", db.loshp,
        db.losparty and "on" or "off"))
      NS.Print(string.format("/aframes lowcall on|off (now %s), lowhp 15-60 (now %d%%): in arena, under lowhp party"
        .. " chat asks your paladin for BoP (physical damage) / Sacrifice, else for a peel, naming who hits you",
        db.lowcall and "on" or "off", db.lowhp))
    end
  end

  function Alerts.Reset()
    for k, v in pairs(ALERT_DEFAULTS) do db[k] = v end
    if mover then ApplyAlertLayout(); ApplySwdButton() end
  end

  function Alerts.Slash(cmd, a)
    if cmd == "alerts" and (a == "on" or a == "off") then
      db.alerts = (a == "on")
      NS.Print("alerts " .. a)
      return true
    elseif cmd == "swd" and (a == "all" or a == "target") then
      db.swdpoly = a
      NS.Print("SWD alert: " .. (a == "all" and "every enemy Polymorph / Seduction within SWD range"
        or "only when the caster targets you"))
      return true
    elseif cmd == "lowcall" and (a == "on" or a == "off") then
      db.lowcall = (a == "on")
      NS.Print("low health party call " .. a)
      return true
    elseif cmd == "lowhp" and tonumber(a) then
      db.lowhp = NS.Clamp(math.floor(tonumber(a)), 15, 60)
      NS.Print("low health party call under " .. db.lowhp .. "% health")
      return true
    elseif (cmd == "los" or cmd == "losparty") and (a == "on" or a == "off") then
      db[cmd] = (a == "on")
      NS.Print((cmd == "los" and "low teammate LoS / range alert " or "LoS party message ") .. a)
      return true
    elseif cmd == "loshp" and tonumber(a) then
      db.loshp = NS.Clamp(math.floor(tonumber(a)), 20, 90)
      NS.Print("LoS / range alert under " .. db.loshp .. "% health")
      return true
    elseif cmd == "swdbutton" and (a == "on" or a == "off") then
      db.swdbutton = (a == "on")
      ApplySwdButton()
      NS.Print("SWD button " .. a .. (swdPending and " (after combat)" or ""))
      return true
    elseif cmd == "swdsize" and tonumber(a) then
      db.swdsize = NS.Clamp(math.floor(tonumber(a)), 32, 128)
      ApplySwdButton()
      NS.Print("SWD button size = " .. db.swdsize .. (swdPending and " (after combat)" or ""))
      return true
    end
    return false
  end

  function Alerts.Profile() return profile end

  function Alerts.Debug()
    NS.Print("alerts: profile " .. tostring(profile) .. ", " .. (db.alerts and "on" or "off"))
    if profile == "disc" then
      NS.Print("swd: " .. tostring(db.swdpoly) .. ", last enemy Polymorph / Seduction cast start: "
        .. (lastPolyStart or "none seen since login"))
      NS.Print("low call: " .. (db.lowcall and "on" or "off") .. " under " .. db.lowhp .. "%, last: "
        .. (lastHelp or "none since login"))
    end
    local list = db.swdTrace or {}
    for i = math.max(1, #list - 4), #list do
      local e = list[i]
      NS.Print(string.format("%s %s by %s: profile %s, unit %s, %s, targets you %s, range %s, alert %s, button %s",
        e.when, e.spell, e.caster, e.profile, e.unit or "NONE", e.cast or "-", e.targetsMe or "-", e.range or "-",
        e.alert or "NONE", e.button or "-"))
    end
  end
end
AlertsModule()

--[[
  Kill target + arena logging (3.10; owner: "suggest a kill target after the door opens, the one
  that gives the highest chance to win"). Display only: one pick per match, shown as a skull on
  the arena row and a line above the rows; /aframes call says it in party chat when YOU type it.

  Score per enemy = how killable the spec is (ArenaFrames_KillPrior, corrected by your own logs
  through ArenaFrames_Data.specs) + what's known about that player (armory gear / resilience,
  SoloQ rating, how often he died first against you: ArenaFrames_Data.players, written by
  tools/arena.py) - racial escapes (EMFH, WotF...). The pick locks once the whole enemy team was
  seen, or 15 s after the first enemy showed up (stealthers). Every match is stored in
  db.killHistory (pick, first enemy death, result) so the picks can be checked over time.

  Arena logging: /combatlog is switched on when you enter an arena and off when you leave
  (only if this addon switched it on), so tools/arena.py always has your games.
]]
local function KillModule()
  local Kill = {}
  NS.Kill = Kill
  local KILL_DEFAULTS = { kill = true, autolog = true, killtext = false, autocall = true }
  -- 3.14 (owner: "2 seconds after the gates open announce the kill target in party: go lock, go rog...")
  local CALL_WORDS = { WARLOCK = "lock", PRIEST = "priest", MAGE = "mage", HUNTER = "hunter", SHAMAN = "sham",
    DRUID = "druid", WARRIOR = "warr", ROGUE = "rog", DEATHKNIGHT = "dk", PALADIN = "pala" }
  local CALL_DELAY = 2       -- after the first enemy shows up (= the gates opened)
  -- 3.15 (owner: "check stealthed rogues / druids by their party buffs"): an enemy still hidden at the
  -- gates is a stealther; their team's buffs tell which: Mark / Gift of the Wild without a visible druid
  -- = a druid, else a rogue (rogues buff nothing). A Night Elf in Shadowmeld would look like a rogue.
  local DRUID_BUFFS = { 1126, 21849 }
  local druidBuffNames = {}
  local LOCK_AFTER = 15
  local MAX_HISTORY = 300
  local RACE_ESCAPE = { Human = { -8, "EMFH" }, Scourge = { -4, "WotF" }, Dwarf = { -3, "Stoneform" },
    Gnome = { -2, "Escape Artist" } }
  local CLASS_NAMES = { WARLOCK = "lock", PRIEST = "priest", MAGE = "mage", HUNTER = "hunter", SHAMAN = "shaman",
    DRUID = "druid", WARRIOR = "warrior", ROGUE = "rogue", DEATHKNIGHT = "DK", PALADIN = "paladin" }
  local match                -- the current arena (or test preview)
  local wasArena, loggingByUs = false, false
  local elapsed = 0
  local frame = CreateFrame("Frame")
  local plan

  local function Clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

  local function Prior(class, spec)
    local c = ArenaFrames_KillPrior and ArenaFrames_KillPrior[class]
    if not c then return 50 end
    return (spec and c[spec]) or c._ or 50
  end

  -- score (higher = kill this one) and the reasons, most important first
  -- 3.15.1 (owner: "do we check enemies' gear? prioritize low geared ones"): max health is a live gear
  -- check for everyone (stamina): rough max health of a decently PvP-geared 80 of each class
  local GEARED_HP = { WARRIOR = 28000, PALADIN = 27000, DEATHKNIGHT = 29000, HUNTER = 24000, ROGUE = 23500,
    SHAMAN = 23000, DRUID = 23000, MAGE = 21000, WARLOCK = 24500, PRIEST = 21500 }

  -- 3.17 (owner: "in 2v2 pull the 2v2 brackets, for SoloQ take SoloQ"): tools/arena.py writes the 2v2
  -- numbers next to the SoloQ ones with a "2" suffix (classes2, avgDeath2, specs2, hgames2, mmr2, vsMet2,
  -- met2...). In 2v2 those are used; a group without 2v2 data falls back to the SoloQ one, marked "(SoloQ)".
  local function Pick(t, two, key, need)
    if not t then return end
    if two and t[key .. "2"] ~= nil and (not need or need(t, "2")) then return "2", nil end
    if t[key] ~= nil and (not need or need(t, "")) then return "", two and " (SoloQ)" or nil end
  end

  function Kill.Score(class, spec, name, race, maxhp, bracket)
    local D = ArenaFrames_Data or {}
    local two = bracket == "2v2"
    local parts = {}
    local p = name and D.players and D.players[name]
    local armorySpec = not spec and p and p.class == class and p.spec   -- not seen in game yet: the armory's
    spec = spec or armorySpec or nil
    local base = Prior(class, spec)
    local label = (spec and (spec .. (armorySpec and "? " or " ")) or "") .. (CLASS_NAMES[class] or "?")
    local key = spec and (class .. ":" .. spec)
    local st = key and two and D.specs2 and D.specs2[key]
    if not (st and (st.seen or 0) > 0) then st = key and D.specs and D.specs[key] end
    if st and (st.seen or 0) > 0 then
      -- your logs: how often this spec died first, pulled toward the prior while there's little data
      base = ((st.firstDeath or 0) + 6 * base / 100) / (st.seen + 6) * 100
      label = label .. string.format(" (died first %d/%d)", st.firstDeath or 0, st.seen)
    end
    local score = base
    table.insert(parts, { 100, label })
    -- 3.10.1: Warmane match history (tools/arena.py): how often each class / player dies
    local c2 = two and D.classes2 and D.classes2[class]
    local useTwo = c2 and (c2.games or 0) >= 10
    local cs = useTwo and c2 or (D.classes and D.classes[class])
    local avg = ((useTwo and D.avgDeath2 or D.avgDeath) or 40) / 100
    if cs and (cs.games or 0) >= 10 then
      local rate = cs.deaths / cs.games
      local d = Clamp((rate - avg) * 60 * cs.games / (cs.games + 30), -15, 15)
      score = score + d
      table.insert(parts, { d, string.format("%ss die in %d%% of your %s games", CLASS_NAMES[class] or "?", rate * 100,
        useTwo and "2v2" or "SoloQ") })
    end
    local sfx, tag = Pick(p, two, "hdeaths", function(t, x) return (t["hgames" .. x] or 0) >= 3 end)
    if sfx then
      local hg, hd = p["hgames" .. sfx], p["hdeaths" .. sfx]
      local d = Clamp((hd / 100 - avg) * 40 * hg / (hg + 4), -12, 12)
      score = score + d
      table.insert(parts, { d, string.format("dies in %d%% of his games", hd) .. (tag or "") })
    end
    sfx, tag = Pick(p, two, "vsMet", function(t, x) return t["vsMet" .. x] >= 2 end)
    if sfx then
      local met, died = p["vsMet" .. sfx], p["vsDied" .. sfx] or 0
      local d = Clamp((died / met - avg) * 30 * met / (met + 3), -10, 10)
      score = score + d
      table.insert(parts, { d, string.format("died in %d/%d vs you", died, met) .. (tag or "") })
    end
    if p then
      if p.resil then
        local d = Clamp((650 - p.resil) / 25, -15, 15)   -- items only; 2000+ ladder median ~650
        score = score + d
        if math.abs(d) >= 3 then table.insert(parts, { d, (d > 0 and "low" or "high") .. " resil " .. p.resil }) end
      elseif p.ilvl then
        local d = Clamp((264 - p.ilvl) / 2, -10, 10)
        score = score + d
        if math.abs(d) >= 3 then table.insert(parts, { d, "ilvl " .. p.ilvl }) end
      end
      sfx, tag = Pick(p, two, "mmr")
      if sfx then
        local mmr = p["mmr" .. sfx]
        local d = Clamp((1450 - mmr) / 40, -10, 8)
        score = score + d
        if math.abs(d) >= 3 then table.insert(parts, { d, (sfx == "2" and "2v2 MMR " or "MMR ") .. mmr .. (tag or "") }) end
      elseif p.rating then
        local d = Clamp((1600 - p.rating) / 50, -10, 6)
        score = score + d
        if math.abs(d) >= 3 then table.insert(parts, { d, "SoloQ " .. p.rating }) end
      end
      sfx, tag = Pick(p, two, "met", function(t, x) return t["met" .. x] > 0 and t["firstDeath" .. x] end)
      if sfx then
        local met, first = p["met" .. sfx], p["firstDeath" .. sfx]
        local d = 10 * first / met - 3
        score = score + d
        table.insert(parts, { d, string.format("died first %d/%d vs you", first, met) .. (tag or "") })
      end
    end
    local geared = GEARED_HP[class]
    if geared and maxhp and maxhp > 1000 then
      local d = Clamp((geared - maxhp) / 500, -8, 12)
      score = score + d
      if math.abs(d) >= 3 then
        table.insert(parts, { d, string.format("%s health %dk", d > 0 and "low" or "high", math.floor(maxhp / 1000 + 0.5)) })
      end
    end
    local r = race and RACE_ESCAPE[race]
    if r then
      score = score + r[1]
      table.insert(parts, { r[1], r[2] })
    elseif race then
      table.insert(parts, { 1, "no EMFH" })
    end
    table.sort(parts, function(a, b) return math.abs(a[1]) > math.abs(b[1]) end)
    local reasons = {}
    for i = 1, math.min(#parts, 3) do reasons[i] = parts[i][2] end
    return score, table.concat(reasons, ", ")
  end

  local function TeamSize()
    local raid = GetNumRaidMembers()
    if raid > 0 then return raid end
    return GetNumPartyMembers() + 1
  end

  local function NewMatch(test)
    match = { start = GetTime(), test = test, enemies = {}, deaths = {}, ourDeaths = 0, size = TeamSize() }
  end

  -- the class of the enemies we can't see yet (stealthed), from the buffs on the ones we can
  local function HiddenClass(classesSeen)
    if classesSeen.DRUID then return "ROGUE" end
    for i = 1, 5 do
      local u = "arena" .. i
      if UnitExists(u) then
        for k = 1, 40 do
          local name = UnitAura(u, k, "HELPFUL")
          if not name then break end
          if druidBuffNames[name] then return "DRUID" end
        end
      end
    end
    return "ROGUE"
  end

  -- for the placeholder rows of the core (3.18)
  function NS.GuessHidden()
    local classesSeen = {}
    for i = 1, 5 do
      local s = NS.slots[i]
      if s and s.class then classesSeen[s.class] = true end
    end
    return HiddenClass(classesSeen)
  end

  local function Evaluate(now)
    if NS.IsTestMode() and not match.test then return end   -- the preview's fake players aren't this match
    local seen, best = 0, nil
    local classesSeen = {}
    for i = 1, 5 do
      local s = NS.slots[i]
      if s and s.guid and s.class then
        seen = seen + 1
        local e = match.enemies[s.guid]
        if not e then
          e = { class = s.class, index = i }
          match.enemies[s.guid] = e
          match.firstSeen = match.firstSeen or now
        end
        -- names come in a moment after the unit ("Unknown" first): keep the real one (3.15.1)
        if s.name and s.name ~= UNKNOWN and s.name ~= "Unknown" then e.name = s.name end
        e.name = e.name or "?"
        e.maxhp = s.maxhp
        if not e.race and UnitExists("arena" .. i) and UnitGUID("arena" .. i) == s.guid then
          e.race = select(2, UnitRace("arena" .. i))
        end
        if match.test then e.race = e.race or (i == 1 and "Human" or "Orc") end
        e.spec = NS.SpecOf(s.guid)
        e.score, e.why = Kill.Score(e.class, e.spec, e.name, e.race, e.maxhp, match.size == 2 and "2v2" or nil)
        if not best or e.score > match.enemies[best].score then best = s.guid end
        classesSeen[e.class] = true
        -- the hidden one we picked just showed up: the skull goes on him
        if match.pick == "hidden" and match.enemies.hidden and e.class == match.enemies.hidden.class then
          match.pick = s.guid
          match.enemies.hidden = nil
        end
      end
    end
    -- still hidden at the gates (stealth): score them as their probable class
    if not match.test and match.firstSeen and seen < match.size and not match.locked then
      local class = HiddenClass(classesSeen)
      local score, why = Kill.Score(class, nil, nil, nil, nil, match.size == 2 and "2v2" or nil)
      match.enemies.hidden = { name = "stealthed " .. (CLASS_NAMES[class] or "?"), class = class, score = score,
        why = why .. " (not seen yet)", index = 0 }
      if not best or score > match.enemies[best].score then best = "hidden" end
    elseif match.enemies.hidden and match.pick ~= "hidden" then
      match.enemies.hidden = nil
    end
    if not best then return end
    if not match.locked then
      match.pick = best
      if seen >= match.size or (match.firstSeen and now - match.firstSeen >= LOCK_AFTER) or match.test then
        match.locked = true
      end
    end
    -- auto call: once, 2 s after the gates, of the current pick (which then stays locked)
    if db.autocall and db.kill and not match.test and not match.called and match.pick and match.firstSeen
        and now - match.firstSeen >= CALL_DELAY then
      match.called, match.locked = true, true
      local msg = "go " .. (CALL_WORDS[match.enemies[match.pick].class] or "kill")
      if GetNumPartyMembers() > 0 then SendChatMessage(msg, "PARTY")
      elseif GetNumRaidMembers() > 0 then SendChatMessage(msg, "RAID") end
    end
  end

  local function PlanText()
    local e = match and match.pick and match.enemies[match.pick]
    if not (db.kill and db.killtext and e) then return nil end   -- 3.11: off by default (owner: "skull is enough")
    local line = string.format("|cffff4040KILL|r %s (%d) - %s%s", e.name or "?", e.index or 0, e.why or "",
      match.locked and "" or " |cffaaaaaa(waiting for the whole team)|r")
    local classes = {}
    for _, x in pairs(match.enemies) do table.insert(classes, x.class) end
    table.sort(classes)
    local card = ArenaFrames_CompPlans and ArenaFrames_CompPlans[table.concat(classes, "+")]
    if card and match.locked then line = line .. "\n|cffffd100" .. card .. "|r" end
    return line
  end

  local function RenderPlan()
    local text = PlanText()
    if text then plan:SetText(text); plan:Show() else plan:Hide() end
  end

  local function Finish()
    if not match or match.test then match = nil; return end
    if next(match.enemies) then
      local enemies = {}
      for key, e in pairs(match.enemies) do
        if key ~= "hidden" then
          table.insert(enemies, { name = e.name, class = e.class, spec = e.spec, score = e.score and math.floor(e.score) })
        end
      end
      local pick = match.pick and match.enemies[match.pick]
      local first = match.deaths[1] and match.enemies[match.deaths[1]]
      local result = match.result or "?"
      db.killHistory = db.killHistory or {}
      table.insert(db.killHistory, { t = time(), size = match.size, enemies = enemies, pick = pick and pick.name,
        firstDeath = first and first.name, result = result })
      while #db.killHistory > MAX_HISTORY do table.remove(db.killHistory, 1) end
    end
    match = nil
  end

  local function SetLogging(on)
    if on then
      if db.autolog and not LoggingCombat() then
        LoggingCombat(true)
        loggingByUs = true
        NS.Print("combat log ON for this arena (Logs\\WoWCombatLog.txt)")
      end
    elseif loggingByUs then
      LoggingCombat(false)   -- not 0: the client reads it as a boolean, 0 would be true
      loggingByUs = false
    elseif db.autolog and LoggingCombat() then
      -- 3.15.1: the client only writes the log to disk when logging stops (or at logout). Logging you
      -- started yourself (or left on from earlier) stays on: off + on again writes the arena out.
      LoggingCombat(false)
      LoggingCombat(true)
    end
  end

  local function OnUpdate(self, dt)
    elapsed = elapsed + dt
    if elapsed < 0.5 then return end
    elapsed = 0
    local arena = NS.InArena()
    if arena ~= wasArena then
      wasArena = arena
      if arena then
        Finish(); NewMatch(false); SetLogging(true)
      else
        Finish(); SetLogging(false)
      end
    end
    if match then Evaluate(GetTime()) end
    RenderPlan()
  end

  local function OnEvent(self, event, _, sub, _, _, _, dstGUID, _, dstFlags)
    if sub ~= "UNIT_DIED" or not match or match.test then return end
    if match.enemies[dstGUID] then
      if not match.dead then match.dead = {} end
      if not match.dead[dstGUID] then
        match.dead[dstGUID] = true
        table.insert(match.deaths, dstGUID)
        if #match.deaths >= match.size then match.result = match.result or "win" end
      end
    elseif dstFlags and bit.band(dstFlags, 0x400) ~= 0 and bit.band(dstFlags, 0x10) ~= 0 then
      match.ourDeaths = match.ourDeaths + 1                   -- one of your team (or you)
      if match.ourDeaths >= match.size then match.result = match.result or "loss" end
    end
  end

  function Kill.IsPick(guid)
    return db.kill and match and guid ~= nil and match.pick == guid
  end

  function Kill.Init()
    for k, v in pairs(KILL_DEFAULTS) do
      if db[k] == nil then db[k] = v end
    end
    for _, id in ipairs(DRUID_BUFFS) do
      local name = GetSpellInfo(id)
      if name then druidBuffNames[name] = true end
    end
    local anchor = _G.ArenaFramesAnchor
    plan = anchor:CreateFontString(nil, "OVERLAY")
    plan:SetFont(NS.FONT, 12, "OUTLINE")
    plan:SetJustifyH("LEFT")
    plan:SetWidth(320)
    plan:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 4)
    plan:Hide()
    frame:SetScript("OnUpdate", OnUpdate)
    frame:SetScript("OnEvent", OnEvent)
    frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  end

  function Kill.SetTest(on)
    if not plan then return end
    if on and not (match and not match.test) then NewMatch(true); Evaluate(GetTime())
    elseif match and match.test then match = nil end
    RenderPlan()
  end

  local function Summary()
    local h = db.killHistory or {}
    local n, picked, pickFirst, winPickFirst, winOther, other = #h, 0, 0, 0, 0, 0
    for _, m in ipairs(h) do
      if m.pick then
        picked = picked + 1
        if m.firstDeath == m.pick then
          pickFirst = pickFirst + 1
          if m.result == "win" then winPickFirst = winPickFirst + 1 end
        else
          other = other + 1
          if m.result == "win" then winOther = winOther + 1 end
        end
      end
    end
    NS.Print(string.format("kill target history: %d arenas, pick died first in %d/%d", n, pickFirst, picked))
    if picked > 0 then
      NS.Print(string.format("  won %d/%d when the pick died first, %d/%d otherwise", winPickFirst, pickFirst,
        winOther, other))
    end
    for i = math.max(1, n - 4), n do
      local m = h[i]
      local names = {}
      for _, e in ipairs(m.enemies or {}) do table.insert(names, e.name .. " " .. (e.spec or "") .. " " .. e.class) end
      NS.Print(string.format("  %s %s: pick %s, first death %s - %s", date("%m/%d %H:%M", m.t), m.result or "?",
        m.pick or "-", m.firstDeath or "-", table.concat(names, ", ")))
    end
  end

  function Kill.Help()
    NS.Print(string.format("/aframes kill on|off (now %s): kill target skull; autocall on|off (now %s): \"go lock\" in"
      .. " party 2 s after the gates; call: say it now; kills: how the picks did", db.kill and "on" or "off",
      db.autocall and "on" or "off"))
    NS.Print(string.format("/aframes autolog on|off (now %s): /combatlog on in arena (for tools/arena.py); data: %s",
      db.autolog and "on" or "off", ArenaFrames_Data and ArenaFrames_Data.generated or "none yet"))
  end

  function Kill.Slash(cmd, a)
    if cmd == "kill" and (a == "on" or a == "off") then
      db.kill = (a == "on")
      NS.Print("kill target " .. a)
      return true
    elseif cmd == "autocall" and (a == "on" or a == "off") then
      db.autocall = (a == "on")
      NS.Print("auto call of the kill target in party chat " .. a)
      return true
    elseif cmd == "killtext" and (a == "on" or a == "off") then
      db.killtext = (a == "on")
      NS.Print("kill target text + comp tip " .. a)
      return true
    elseif cmd == "autolog" and (a == "on" or a == "off") then
      db.autolog = (a == "on")
      NS.Print("arena combat logging " .. a)
      return true
    elseif cmd == "call" then
      local e = match and match.pick and match.enemies[match.pick]
      if not e then NS.Print("no kill target yet"); return true end
      local msg = "go " .. (CALL_WORDS[e.class] or "kill")
      if GetNumPartyMembers() > 0 then SendChatMessage(msg, "PARTY")
      elseif GetNumRaidMembers() > 0 then SendChatMessage(msg, "RAID")
      else NS.Print(msg .. " (not in a group)") end
      return true
    elseif cmd == "kills" then
      Summary()
      return true
    end
    return false
  end

  function Kill.Debug()
    NS.Print(string.format("kill target: %s, autolog %s (logging now: %s), data %s", db.kill and "on" or "off",
      db.autolog and "on" or "off", LoggingCombat() and "yes" or "no",
      ArenaFrames_Data and ArenaFrames_Data.generated or "none"))
    if match then
      for _, e in pairs(match.enemies) do
        NS.Print(string.format("  %s%s %s %s: %.0f - %s", match.pick and match.enemies[match.pick] == e and "> " or "  ",
          e.name or "?", e.spec or "?", e.class, e.score or 0, e.why or ""))
      end
    end
  end
end
KillModule()

--[[
  Big enemy cooldown alert (3.12; owner picked it from the "glad player" list): when an enemy pops a
  big offensive cooldown (cat = "offensive" in ArenaFrames_Cooldowns: Bladestorm, Shadow Dance, Wings,
  Icy Veins, Metamorphosis, Berserk, Bloodlust...), its icon flashes in the middle of the screen for
  2.5 s with the arena number, plus Blizzard's raid warning sound. Movable (unlock), up to 3 at once.
]]
local function BigCDModule()
  local BigCD = {}
  NS.BigCD = BigCD
  local SHOW, FADE, MAX = 2.5, 0.4, 3
  local mover
  local slotsUI, queue = {}, {}

  local function Layout()
    mover:ClearAllPoints()
    mover:SetPoint(db.bpoint, UIParent, db.bpoint, db.bx, db.by)
    mover:SetWidth(3 * 56 + 16)
    mover:SetHeight(16)
    for k, b in ipairs(slotsUI) do
      b:ClearAllPoints()
      b:SetPoint("TOP", mover, "BOTTOM", (k - 2) * 62, -4)
    end
  end

  local function Create()
    mover = NS.NewMover("ArenaFramesBigCD", "Big enemy cooldowns - drag", "bpoint", "bx", "by")
    table.insert(NS.extraMovers, mover)
    mover.bg:Hide(); mover.label:Hide(); mover:EnableMouse(false)
    for k = 1, MAX do
      local b = NS.NewIcon(mover)
      b:SetWidth(56); b:SetHeight(56)
      b.text:SetFont(NS.FONT, 22, "OUTLINE")
      b.text:SetTextColor(1, 0.9, 0.1)
      b.label = NS.NewText(b.over, 11)
      b.label:SetPoint("TOP", b, "BOTTOM", 0, -2)
      b:Hide()
      slotsUI[k] = b
    end
    Layout()
  end

  function BigCD.Used(guid, e, hostile)
    if not (db and db.bigcd and mover) or e.cat ~= "offensive" then return end
    local idx = NS.ArenaIndexOf(guid)
    if NS.InArena() then
      if not idx then return end                  -- your teammates' cooldowns aren't news
    elseif not hostile then
      return
    end
    table.insert(queue, 1, { icon = e.icon, name = e.name, idx = idx, t = GetTime() })
    while #queue > MAX do table.remove(queue) end
    if db.bigsound then PlaySound("RaidWarning") end
  end

  local elapsed = 0
  local function OnUpdate(self, dt)
    elapsed = elapsed + dt
    if elapsed < 0.05 then return end
    elapsed = 0
    local now = GetTime()
    for k = #queue, 1, -1 do
      if now - queue[k].t > SHOW + FADE then table.remove(queue, k) end
    end
    local test = NS.IsTestMode()
    for k, b in ipairs(slotsUI) do
      local q = queue[k]
      if test and not q then
        q = ({ { icon = select(3, GetSpellInfo(46924)) or NS.UNKNOWN_ICON, name = "Bladestorm", idx = 1, t = now },
          { icon = select(3, GetSpellInfo(51713)) or NS.UNKNOWN_ICON, name = "Shadow Dance", idx = 2, t = now } })[k]
      end
      if q then
        b.icon:SetTexture(q.icon)
        b.text:SetText(q.idx or "")
        b.label:SetText(q.name)
        local age = now - q.t
        b:SetAlpha(age > SHOW and math.max(0, 1 - (age - SHOW) / FADE) or 1)
        b:Show()
      else
        b:Hide()
      end
    end
  end

  local driver = CreateFrame("Frame")
  driver:RegisterEvent("PLAYER_ENTERING_WORLD")   -- nothing to do on it; keeps test harnesses ticking it
  function BigCD.Init()
    if not mover then Create() end
    driver:SetScript("OnUpdate", OnUpdate)
  end
end
BigCDModule()

-- 3.19 (owner made a 2nd priest to learn a new layout and wanted "every single thing from Simulator"): action
-- bars live on the server, so they can't be copied as files. /aframes bars save stores slots 1-120 (spell by
-- name, macro by body - all his macros are named "s" -, item, equipment set) in the account-wide db;
-- /aframes bars load puts them back on the character you're on (out of combat; like ActionBarSaver). The
-- player places nothing in combat and nothing is cast: plain UI setup.
do
  local function Book()
    local book, i = {}, 1
    while true do
      local name = GetSpellName(i, BOOKTYPE_SPELL or "spell")
      if not name then break end
      book[name] = i                                -- the last one = the highest rank
      i = i + 1
    end
    return book
  end

  -- macros: 1-36 account-wide ("General" tab), 37-54 this character's
  local function MacroByBody(body, name)
    local global, char = GetNumMacros()
    local byName
    for i = 1, 36 + char do
      if i <= global or i > 36 then
        local n, _, b = GetMacroInfo(i)
        if b == body then return i end
        if n == name and not byName then byName = i end
      end
    end
    return byName
  end

  local function Save()
    local t, n = {}, 0
    for slot = 1, 120 do
      local kind, id, sub = GetActionInfo(slot)
      if kind == "spell" then
        t[slot] = { kind = "spell", name = GetSpellName(id, sub or BOOKTYPE_SPELL or "spell") }
      elseif kind == "macro" then
        local name, _, body = GetMacroInfo(id)
        t[slot] = { kind = "macro", name = name, body = body }
      elseif kind == "item" then
        t[slot] = { kind = "item", id = id }
      elseif kind == "equipmentset" then
        t[slot] = { kind = "equipmentset", name = id }
      end
      if t[slot] then n = n + 1 end
    end
    ArenaFramesDB.bars = { from = UnitName("player"), slots = t }
    NS.Print(string.format("saved %d action buttons of %s. Log in on the other character and type /aframes bars load",
      n, UnitName("player")))
  end

  local function Load()
    local saved = ArenaFramesDB.bars
    if not saved then NS.Print("nothing saved yet: /aframes bars save on the character to copy from"); return end
    if InCombatLockdown() then NS.Print("not in combat"); return end
    local book, placed, missing = Book(), 0, {}
    for slot = 1, 120 do
      local e = saved.slots[slot]
      ClearCursor()
      if e then
        if e.kind == "spell" and book[e.name] then PickupSpell(book[e.name], BOOKTYPE_SPELL or "spell")
        elseif e.kind == "macro" then
          local m = MacroByBody(e.body, e.name)
          if m then PickupMacro(m) end
        elseif e.kind == "item" then PickupItem(e.id)
        elseif e.kind == "equipmentset" and PickupEquipmentSetByName then PickupEquipmentSetByName(e.name) end
        if CursorHasSpell() or CursorHasMacro() or CursorHasItem() or GetCursorInfo() then
          PlaceAction(slot)
          placed = placed + 1
        else
          table.insert(missing, slot .. " " .. tostring(e.name or e.id))
        end
      elseif GetActionInfo(slot) then
        PickupAction(slot)                          -- empty there too
      end
      ClearCursor()
    end
    NS.Print(string.format("placed %d buttons from %s", placed, saved.from or "?"))
    if #missing > 0 then NS.Print("not found on this character: " .. table.concat(missing, ", ")) end
  end

  function NS.Bars(a)
    if a == "save" then Save()
    elseif a == "load" then Load()
    else NS.Print("/aframes bars save (on the character to copy from), then /aframes bars load (on the new one)") end
  end
end

-- 3.21 (owner: "set also Kisame's talents" on his 2nd rogue Mugen): talents live on the server too.
-- /aframes talents save stores both specs (tab, tier, column, rank); /aframes talents load [1|2] fills the
-- talent PREVIEW of your active spec with saved spec 1 or 2 - nothing is learned until you check it and click
-- Learn in the talent frame (Blizzard's 3.1+ preview: AddPreviewTalentPoints / LearnPreviewTalents).
do
  local function TalentSave()
    local _, class = UnitClass("player")
    local groups = {}
    for g = 1, GetNumTalentGroups() do
      local list = {}
      for tab = 1, GetNumTalentTabs() do
        for i = 1, GetNumTalents(tab) do
          local name, _, tier, col, rank = GetTalentInfo(tab, i, false, false, g)
          if (rank or 0) > 0 then table.insert(list, { tab = tab, tier = tier, col = col, rank = rank, name = name }) end
        end
      end
      groups[g] = list
    end
    ArenaFramesDB.talents = { from = UnitName("player"), class = class, groups = groups, active = GetActiveTalentGroup() }
    NS.Print(string.format("saved %d talent spec(s) of %s. On the other character: /aframes talents load 1 (or 2),"
      .. " then check the talent frame and click Learn", #groups, UnitName("player")))
  end

  -- the saved spec as single points in learning order (tier by tier), matched to this character's tree
  local function Plan(which)
    local saved = ArenaFramesDB.talents
    if not saved then NS.Print("nothing saved yet: /aframes talents save on the character to copy from"); return end
    if select(2, UnitClass("player")) ~= saved.class then NS.Print("saved talents are for a " .. saved.class); return end
    if InCombatLockdown() then NS.Print("not in combat"); return end
    local src = saved.groups[which]
    if not src then NS.Print("no saved spec " .. which); return end
    local list = {}
    for _, e in ipairs(src) do table.insert(list, e) end
    table.sort(list, function(a, b) if a.tier ~= b.tier then return a.tier < b.tier end return a.tab < b.tab end)
    local g, plan, missing = GetActiveTalentGroup(), {}, {}
    for _, e in ipairs(list) do
      local found
      for i = 1, GetNumTalents(e.tab) do
        local _, _, tier, col = GetTalentInfo(e.tab, i, false, false, g)
        if tier == e.tier and col == e.col then found = i end
      end
      if found then table.insert(plan, { tab = e.tab, i = found, rank = e.rank, name = e.name })
      else table.insert(missing, e.name or "?") end
    end
    if #missing > 0 then NS.Print("not found: " .. table.concat(missing, ", ")) end
    return plan, g, saved.from or "?"
  end

  local function TalentLoad(which)
    local plan, g, from = Plan(which)
    if not plan then return end
    SetCVar("previewTalents", "1")
    ResetGroupPreviewTalentPoints(false, g)
    for _, e in ipairs(plan) do
      local rank = select(5, GetTalentInfo(e.tab, e.i, false, false, g)) or 0
      if e.rank > rank then AddPreviewTalentPoints(e.tab, e.i, e.rank - rank, false, g) end
    end
    local took = GetGroupPreviewTalentPointsSpent and GetGroupPreviewTalentPointsSpent(false, g) or 0
    NS.Print(string.format("%s's spec %d: %d points in the preview, %d unspent points on this character", from,
      which, took, GetUnspentTalentPoints(false, false, g) or 0))
    if took > 0 then
      NS.Print("open your talents (N), check them, click Learn")
    else
      NS.Print("the preview didn't take: /aframes talents learn " .. which .. " learns them one by one instead")
    end
  end

  -- learn point by point: one LearnTalent, wait for the rank to go up (server), next; stops if one won't learn
  local queue, waitFor, waited, done
  local learner = CreateFrame("Frame")
  learner:Hide()
  learner:RegisterEvent("PLAYER_TALENT_UPDATE")         -- the server confirmed a point: check right away
  learner:SetScript("OnEvent", function() waited = 1 end)
  learner:SetScript("OnUpdate", function(self, dt)
    if not queue or not self:IsShown() then return end
    waited = waited + dt
    if waited < 0.25 then return end
    if InCombatLockdown() then NS.Print("talent learning stopped: combat"); queue = nil; self:Hide(); return end
    local e = queue[1]
    if not e then NS.Print("learned " .. done .. " talent points"); queue = nil; self:Hide(); return end
    local rank = select(5, GetTalentInfo(e.tab, e.i)) or 0
    if waitFor and rank > waitFor then done, waitFor = done + (rank - waitFor), nil end
    if rank >= e.rank then table.remove(queue, 1); waited = 0; return end
    if waitFor then                                  -- sent, the server hasn't answered yet
      if waited < 3 then return end
      NS.Print(string.format("stopped at %s (%d/%d): not learnable (no points left?). Learned %d.", e.name or "?",
        rank, e.rank, done))
      queue = nil
      self:Hide()
      return
    end
    waitFor, waited = rank, 0
    LearnTalent(e.tab, e.i)
  end)

  local function TalentLearn(which)
    local plan, _, from = Plan(which)
    if not plan then return end
    SetCVar("previewTalents", "0")
    queue, waitFor, waited, done = plan, nil, 0, 0
    NS.Print("learning " .. from .. "'s spec " .. which .. " point by point...")
    learner:Show()
  end

  function NS.Talents(a, which)
    if a == "save" then TalentSave()
    elseif a == "load" then TalentLoad(which or 1)
    elseif a == "learn" then TalentLearn(which or 1)
    else NS.Print("/aframes talents save (on the character to copy from), then /aframes talents load 1|2 (on the new one)") end
  end
end

