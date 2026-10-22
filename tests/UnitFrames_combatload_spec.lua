-- /reload in combat: the clickable frames can't be built during combat lockdown, so they
-- wait for PLAYER_REGEN_ENABLED, and the addon says so instead of looking broken.
dofile("tests/harness.lua")
UNITS.player = { name = "Me", player = true, guid = "0xME", class = "ROGUE", hp = 1, maxhp = 1 }
LoadAddon("ArenaFrames")

local pass, fail = 0, 0
local function check(cond, label)
  if cond then pass = pass + 1 else fail = fail + 1; print("FAIL: " .. label) end
end

COMBAT = true
local ok, err = pcall(FireEvent, "ADDON_LOADED", "ArenaFrames")
check(ok, "loading in combat doesn't hit a blocked action " .. tostring(err))
check(ArenaFramesTarget == nil and TargetFrame._shown, "nothing built / hidden yet")
check(ArenaFramesClick1 == nil, "arena row click buttons wait too (3.7)")
check(table.concat(CHAT, "\n"):find("will appear when combat ends"), "tells the owner why")
CHAT = {}
SlashCmdList.ARENAFRAMES("debug")
check(table.concat(CHAT, "\n"):find("waiting for combat to end"), "debug shows the state")
FireEvent("PLAYER_TARGET_CHANGED")             -- events before the frames exist
check(true, "events before setup don't error")
COMBAT = false
FireEvent("PLAYER_REGEN_ENABLED")
Tick(0.2)
check(ArenaFramesTarget and ArenaFramesPlayer._shown and not TargetFrame._shown, "built once combat ended")
check(ArenaFramesClick1 and ArenaFramesClick1._attr["*type2"] == "focus" and IsUnitWatched(ArenaFramesClick1)
  and ArenaFramesClick1._w == 200, "arena row click buttons built and laid out once combat ended")
CHAT = {}
SlashCmdList.ARENAFRAMES("")
check(table.concat(CHAT, "\n"):find("player/target/focus/party frames: on"), "state is on now")

print(string.format("%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
