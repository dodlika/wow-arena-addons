-- ArenaFrames 3.19: /aframes bars save on one character, /aframes bars load on another
dofile("tests/harness.lua")
UNITS.player = { name = "Simulator", player = true, guid = "0xME", class = "PRIEST", hp = 1, maxhp = 1 }
LoadAddon("ArenaFrames")
local pass, fail = 0, 0
local function check(cond, label)
  if cond then pass = pass + 1 else fail = fail + 1; print("FAIL: " .. label) end
end
local function cmd(s) SlashCmdList.ARENAFRAMES(s) end
FireEvent("ADDON_LOADED", "ArenaFrames")
FireEvent("PLAYER_ENTERING_WORLD")

-- Simulator: Flash Heal (rank 11 = book 3), a macro named "s", an item, Penance
BOOK = { { "Flash Heal", "Rank 10" }, { "Smite", "Rank 12" }, { "Flash Heal", "Rank 11" }, { "Penance", "Rank 4" } }
MACROS = { [37] = { "s", "/cast inner focus" }, [38] = { "s", "/cast [target=simulator] fear ward" } }
ACTIONS = { [1] = { "spell", 3, "spell" }, [2] = { "macro", 38 }, [5] = { "item", 33447 }, [7] = { "spell", 4, "spell" } }
cmd("bars save")
local saved = ArenaFramesDB.bars
check(saved and saved.from == "Simulator" and saved.slots[1].name == "Flash Heal"
  and saved.slots[2].body == "/cast [target=simulator] fear ward" and saved.slots[5].id == 33447, "saved by name / body")

-- new priest: different spellbook order, macros in another order, junk on slot 9, no Penance
UNITS.player.name = "Wadawd"
BOOK = { { "Smite", "Rank 12" }, { "Flash Heal", "Rank 11" } }
MACROS = { [37] = { "s", "/cast [target=simulator] fear ward" }, [38] = { "s", "/cast inner focus" } }
ACTIONS = { [9] = { "spell", 1, "spell" } }
CHAT = {}
cmd("bars load")
check(ACTIONS[1] and ACTIONS[1][1] == "spell" and ACTIONS[1][2] == 2, "spell placed from this character's book")
check(ACTIONS[2] and ACTIONS[2][1] == "macro" and ACTIONS[2][2] == 37, "macro matched by its text, not its index")
check(ACTIONS[5] and ACTIONS[5][2] == 33447, "item placed")
check(ACTIONS[9] == nil and ACTIONS[7] == nil and CURSOR == nil, "slots empty on the source end up empty; cursor clear")
local msg = table.concat(CHAT, "\n")
check(msg:find("placed 3") and msg:find("7 Penance"), "reports what's missing")

COMBAT = true
ACTIONS = {}
cmd("bars load")
check(next(ACTIONS) == nil, "nothing in combat")
COMBAT = false

print(string.format("Bars: %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
