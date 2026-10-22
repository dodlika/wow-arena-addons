# Walkthrough

A first-time guide to ArenaFrames and CombatPlates on WoW 3.3.5a (Warmane). Takes about 10 minutes.

## 1. Install

1. On the GitHub page, click the green **Code** button → **Download ZIP**.
2. Unzip it. Inside `wow-arena-addons-main` you'll find the folders `ArenaFrames` and `CombatPlates`.
3. Copy **those two folders** into `World of Warcraft\Interface\AddOns\`.
   The result must be `Interface\AddOns\ArenaFrames\ArenaFrames.toc`, not
   `Interface\AddOns\wow-arena-addons-main\ArenaFrames\...` (a nested folder is never loaded).
4. **Restart the game completely.** `/reload` does not pick up new addons.
5. On the character screen click **AddOns** (bottom left), tick both, and tick **Load out of date AddOns** if they
   show as out of date.

Turn on Lua errors once, so you see problems instead of silent failures:

    /console scriptErrors 1

## 2. First login: place everything

    /aframes unlock

Test frames appear for everything ArenaFrames draws: three enemy arena rows, your party boxes, the target and focus
frames, the enemy cooldown bar and the alert area. **Drag** each one where you want it, then:

    /aframes lock

Size: `/aframes scale 0.5-2` (everything), `/aframes width 120-400` and `/aframes height 20-64` (arena rows).

For the nameplate icons:

    /cplates test

shows the icons on the nameplates around you. Type it again to stop. Change them with `/cplates size 10-64` and
`/cplates pos left|right|top`.

If you mess up: `/aframes reset` or `/cplates reset`.

## 3. What you see in arena

### Enemy rows (one per arena1-3)

From left to right:

- **DR icons**: diminishing returns on that enemy. Border color = what the next CC of that type does:
  green = half duration, yellow = quarter, red = immune. They reset 18 s after the last one ends.
- **Class square**: class icon. While the enemy is CC'd or immune it shows the CC and a big timer;
  it also flashes every spell they cast for 1.5 s (dispels, Frost Nova, ...).
- **Health bar** in class color, a thin power bar under it, and the **spec** once the addon has seen enough of
  their spells.
- **Trinket** with its 2 min timer, and the **racial** next to it (not for Humans: their racial is the trinket).
- **Cast bar**: amber = kickable, grey = can't be interrupted.
- Under the bar: the **cooldowns** that enemy has used, with timers.

**Click a row:** left click = target, right click = focus.

A row turns **half transparent** when that enemy is out of your range, and dims when you can't see them
(stealth). Before a stealthed rogue or druid shows up, a dim **"stealth?"** row guesses which one it is (druid if
their team has Mark/Gift of the Wild).

The **skull** marks the suggested kill target. It's picked from the enemy classes and specs, how geared they look
(max health) and their racial. With `/aframes autocall on` (default) it says "go lock" / "go rog" in party chat 2 s
after the gates open. `/aframes call` says it again, `/aframes kill off` hides it.

### Your party

Your box first, then party 1-4: class-colored health, mana bar for mana users, the CC on them in the middle,
debuffs bottom left (dispellable ones first), big buffs bottom right, and their cooldowns (trinket, racial, class
cooldowns) on the left. Out of range = faded. Crossed swords on your box = you're in combat.

### Target and focus

Blizzard-style frames: class icon portrait (replaced by the CC and its timer while they're CC'd), all buffs and
debuffs, cast bar with "(no kick)" on uninterruptible casts, combo points. A **Sap icon** to the left means that
enemy is out of combat and can be Sapped.

### Enemy cooldowns

A bar with every cooldown enemies use, newest first. Big offensive ones (Avenging Wrath, Shadow Dance, Icy Veins,
...) also pop up as a large icon in the middle of the screen with a sound. `/aframes cd off`, `/aframes bigcd off`,
`/aframes bigsound off` if it's too much.

### Nameplates (CombatPlates)

- **Swords** on enemies in combat, or a **Sap icon** on enemies out of combat: `/cplates mode combat|sap|both`.
- **Teammates' plates** become their class icon + name + running cooldowns (`/cplates party off` to keep normal
  plates, `/cplates partysize` to resize).
- **CC, immunities and big buffs** show above enemy plates (`/cplates auras off`).
- **Totems, Succubus and Felhunter** show as a big spell icon so you can find them fast (`/cplates totems off`).

## 4. Class extras

These appear automatically for your class / spec. `/aframes alerts off` turns them off.

**Rogue:** a **Kick** alert when an enemy casts a heal or Polymorph: KICK! (green), out of range, no energy, or Kick
on cooldown.

**Discipline priest:**

- **SWD alert** when a mage casts Polymorph (or a Succubus Seduction) that may be aimed at you, with a **NOW!** when
  Shadow Word: Death will break it in time. A big clickable SWD button appears during the alert; bind it with a
  macro `/click ArenaFramesSWD`. `/aframes swdbutton off` to hide it.
- **Scatter warning** when a hunter with Scatter Shot ready is close.
- **LoS / range warning** when a low teammate is out of your range or your heal on him failed because of line of
  sight (`/aframes loshp 20-90`; `/aframes losparty on` also tells him in party chat).
- **Low health call**: under 35% in arena, party chat asks your paladin for BoP (physical damage) or Sacrifice,
  else for a peel, naming who's hitting you. `/aframes lowhp 15-60`, `/aframes lowcall off`.

## 5. Handy extras

**Copy action bars to another character** (same class): on the old one `/aframes bars save`, on the new one
`/aframes bars load`. Run it again after the new character learns more spells.

**Copy talents:** `/aframes talents save` on the old one; on the new one `/aframes talents load 1` (fills the talent
preview, you check it and click Learn) or `/aframes talents learn 1` (learns them right away; `2` = second spec).

## 6. When something doesn't work

1. Type `/aframes` and `/cplates`: if nothing answers, the addon isn't loaded (check step 1: folder names, full
   restart, ticked on the character screen).
2. `/aframes debug` or `/cplates debug` explains why something shows or doesn't.
3. Report it with the Lua error text (from `/console scriptErrors 1`), the debug output and a screenshot.

Not needed and not supported: awesome_wotlk or any other client patch (Warmane disconnects you for them).
