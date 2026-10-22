# wow-addons

Arena addons for WoW 3.3.5a (WotLK) on Warmane. Plain Lua, no client patches, no automation.

| Addon | What it does |
|---|---|
| CombatPlates | Swords / Sap icon on enemy nameplates based on combat state (`/cplates`) |
| ArenaFrames | Clean arena, target and focus frames: CC on the portrait, casts, auras, trinket, DR (`/aframes`) |

## Install

**Without git:** click the green **Code** button on GitHub, then **Download ZIP**. Unzip it and copy the
`ArenaFrames` and `CombatPlates` folders into `World of Warcraft/Interface/AddOns`. Restart the game (not just
`/reload`) and tick both addons on the character screen. To update, download again and replace the two folders.

**With git (easy updates):**

    git clone https://github.com/dodlika/wow-arena-addons.git
    wow-arena-addons/scripts/link-addons.sh "/path/to/World of Warcraft/Interface/AddOns"

This links both folders into AddOns (keep the clone where it is). Updating is `git pull` + `/reload` in game.
If your setup doesn't see linked folders (some Wine setups), copy them instead.

## Commands

Type `/aframes` or `/cplates` alone in game for the full list with current values.

**First time**
- `/aframes unlock` - show test frames and drag everything into place; `/aframes lock` when done
- `/cplates test` - preview the nameplate icons
- `/aframes reset`, `/cplates reset` - back to defaults

**ArenaFrames (`/aframes`)**
- Arena rows: left click = target, right click = focus
- `scale 0.5-2`, `width 120-400`, `height 20-64` - size of the arena rows
- `names on|off` - name + health % on the bars
- `cd on|off` - enemy cooldown bar; `bigcd on|off` - big icon when an enemy pops a big cooldown
- `range on|off` - fade enemies out of range
- `kill on|off` - kill-target skull; `autocall on|off` - "go lock" in party when the gates open; `call` - say it now
- `alerts on|off` - class alerts (rogue: Kick on heals / Poly; disc: SWD on Poly / Seduction, Scatter warning)
- Disc priest: `swdbutton on|off` (big SWD button, bind it with a macro `/click ArenaFramesSWD`),
  `los on|off` (teammate low and out of range / LoS), `lowcall on|off` + `lowhp 15-60` (party chat "BOP me" / "PEEL me")
- `bars save` on one character, `bars load` on another - copy action bars
- `talents save`, then `talents load 1|2` (fills the preview, you click Learn) or `talents learn 1|2` on another character
- `debug` - why something shows (or doesn't); include its output in bug reports

**CombatPlates (`/cplates`)**
- `mode combat|sap|both` - swords on enemies in combat, Sap icon on enemies out of combat, or both
- `size 10-64`, `pos left|right|top`, `offset x y` - icon look and position
- `party on|off` - teammates' plates become class icon + name + cooldowns (`partysize 0.5-3`)
- `auras on|off` - CC, immunities and big buffs above enemy plates (`aurasize 14-48`)
- `totems on|off` - totems, Succubus, Felhunter as a big spell icon (`totemsize 16-64`)
- `debug` - every combat signal per plate

**Useful game commands**
- `/console scriptErrors 1` - show Lua errors (send them with bug reports)
- `/reload` - load addon updates after `git pull`

## Tests

    bash tests/run.sh

Needs Lua 5.1: `brew install luajit` on macOS, `apt install lua5.1` on Linux.
