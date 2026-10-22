-- ArenaFrames 3.21: /aframes talents save on one character, /aframes talents load 1|2 on another (preview only)
dofile("tests/harness.lua")
UNITS.player = { name = "Kisame", player = true, guid = "0xME", class = "ROGUE", hp = 1, maxhp = 1 }
LoadAddon("ArenaFrames")
local pass, fail = 0, 0
local function check(cond, label)
  if cond then pass = pass + 1 else fail = fail + 1; print("FAIL: " .. label) end
end
local function cmd(s) SlashCmdList.ARENAFRAMES(s) end
FireEvent("ADDON_LOADED", "ArenaFrames")
FireEvent("PLAYER_ENTERING_WORLD")

-- Kisame: spec 1 sub (Relentless Strikes 5, Shadowstep 1), spec 2 mutilate (Malice 5, Mutilate 1)
TREE[1] = { { { "Malice", 1, 3, 0 }, { "Mutilate", 9, 2, 0 } }, {}, { { "Relentless Strikes", 1, 1, 5 }, { "Shadowstep", 9, 2, 1, 1 } } }
TREE[2] = { { { "Malice", 1, 3, 5 }, { "Mutilate", 9, 2, 1, 1 } }, {}, { { "Relentless Strikes", 1, 1, 0 }, { "Shadowstep", 9, 2, 0, 1 } } }
cmd("talents save")
local saved = ArenaFramesDB.talents
check(saved and saved.from == "Kisame" and #saved.groups == 2 and #saved.groups[1] == 2 and #saved.groups[2] == 2,
  "both specs saved, only talents with points")

-- Mugen: no points, one spec; the tree lists talents in another order
UNITS.player.name = "Mugen"
TREE = { { { { "Mutilate", 9, 2, 0, 1 }, { "Malice", 1, 3, 0 } }, {}, { { "Shadowstep", 9, 2, 0, 1 }, { "Relentless Strikes", 1, 1, 0 } } }, {} }
PREVIEW = { {}, {} }
CVARS.previewTalents = "0"
cmd("talents load 2")
check(PREVIEW[1]["1:2"] == 5 and PREVIEW[1]["1:1"] == 1 and not PREVIEW[1]["3:1"], "spec 2 previewed by tier / column")
check(CVARS.previewTalents == "1", "preview mode on so the Learn button shows")
cmd("talents load")
check(PREVIEW[1]["3:2"] == 5 and PREVIEW[1]["3:1"] == 1 and not PREVIEW[1]["1:2"], "load = spec 1, old preview reset")
UNITS.player.class = "PRIEST"; PREVIEW = { {}, {} }; CHAT = {}
cmd("talents load 1")
check(next(PREVIEW[1]) == nil and table.concat(CHAT, "\n"):find("for a ROGUE"), "other class: refused")
UNITS.player.class = "ROGUE"; COMBAT = true; CHAT = {}
cmd("talents load 1")
check(next(PREVIEW[1]) == nil, "not in combat")
COMBAT = false

-- 3.21.1 (owner: "it says it's filled but it's not"): load reports what the preview holds; learn = point by point
CHAT = {}
cmd("talents load 1")
check(table.concat(CHAT, "\n"):find("spec 1: 6 points in the preview, 71 unspent", 1, true), "load reports the preview")
CHAT = {}
cmd("talents learn 2")
for _ = 1, 60 do Tick(0.3) end
check(TREE[1][1][2][4] == 5 and TREE[1][1][1][4] == 1 and TREE[1][3][2][4] == 0, "spec 2 learned point by point")
check(table.concat(CHAT, "\n"):find("learned 6 talent points", 1, true), "reports the count")
check(CVARS.previewTalents == "0", "preview mode off (talent clicks learn directly again)")
UNSPENT = 0; TREE[1][3][2][4] = 0; CHAT = {}
cmd("talents learn 1")
for _ = 1, 60 do Tick(0.3) end
check(table.concat(CHAT, "\n"):find("stopped at Relentless Strikes (0/5)", 1, true), "no points left: stops and says why")

print(string.format("%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
