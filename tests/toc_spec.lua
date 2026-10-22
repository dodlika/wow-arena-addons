-- Every addon's .toc file list is frozen. WoW reads that list only when the client starts,
-- so an update that adds a file to an existing addon silently doesn't load it after the
-- usual git pull + /reload (happened with ArenaFrames 2.0). Put new code in the listed
-- files instead. A brand-new addon needs a restart anyway: add it here.
local FROZEN = {
  CombatPlates = { "CombatPlates.lua" },
  ArenaFrames = { "DRList.lua", "ArenaFrames.lua" },
}

local pass, fail = 0, 0
local function check(cond, label)
  if cond then pass = pass + 1 else fail = fail + 1; print("FAIL: " .. label) end
end

local function TocFiles(name)
  local f = io.open(name .. "/" .. name .. ".toc")
  if not f then return nil end
  local list = {}
  for line in f:lines() do
    line = line:gsub("\r", ""):match("^%s*(.-)%s*$")
    if line ~= "" and not line:find("^#") then table.insert(list, line) end
  end
  f:close()
  return list
end

local dirs = io.popen("ls -d */ 2>/dev/null")
for dir in dirs:lines() do
  local name = dir:gsub("/$", "")
  local files = TocFiles(name)
  if files then
    local want = FROZEN[name]
    check(want ~= nil, name .. ": new addon - add its file list to FROZEN in tests/toc_spec.lua")
    if want then
      check(table.concat(files, ",") == table.concat(want, ","),
        name .. ".toc lists " .. table.concat(files, ", ") .. " but the frozen list is " ..
        table.concat(want, ", ") .. " (the owner's client won't load added files without a restart)")
    end
  end
end
dirs:close()

print(string.format("%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
