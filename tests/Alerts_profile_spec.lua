-- ArenaFrames 3.17.1: owner's disc priest got no SWD icon on any Poly a whole session; the
-- recorder said profile = nil (talent trees read 0 points after a fresh login, no event later)
dofile("tests/harness.lua")
UNITS.player = { name = "Me", player = true, guid = "0xME", class = "PRIEST", hp = 1, maxhp = 1 }
TALENTS = { 0, 0, 0 }                            -- talents not loaded yet
UNKNOWN_SPELLS = { Penance = true }              -- spellbook not loaded either
LoadAddon("ArenaFrames")

local pass, fail = 0, 0
local function check(cond, label)
  if cond then pass = pass + 1 else fail = fail + 1; print("FAIL: " .. label) end
end

FireEvent("ADDON_LOADED", "ArenaFrames")
FireEvent("PLAYER_ENTERING_WORLD")
Tick(0.1)
check(ArenaFrames_NS.Alerts.Profile() == nil, "no profile while nothing is loaded")

-- talents arrive later without any talent event: picked up by the periodic recheck
TALENTS = { 51, 20, 0 }
NOW = NOW + 3; Tick(0.1)
check(ArenaFrames_NS.Alerts.Profile() == "disc", "disc once talents read right, no event needed")
check(ArenaFramesSWD ~= nil, "SWD button created once disc is known")

-- talents still 0 but Penance is in the spellbook: disc
TALENTS = { 0, 0, 0 }
UNKNOWN_SPELLS = {}
FireEvent("PLAYER_TALENT_UPDATE")
check(ArenaFrames_NS.Alerts.Profile() == "disc", "Penance known = disc even with 0 talent points")

-- a holy priest (no Penance) isn't disc
TALENTS = { 10, 61, 0 }
UNKNOWN_SPELLS = { Penance = true }
FireEvent("PLAYER_TALENT_UPDATE")
check(ArenaFrames_NS.Alerts.Profile() == nil, "holy priest: no disc profile")

print(string.format("Alerts_profile: %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
