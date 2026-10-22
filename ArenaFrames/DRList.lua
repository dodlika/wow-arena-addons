--[[
  Spell data for ArenaFrames (WoW 3.3.5a). Two tables: ArenaFrames_DR (below) and
  ArenaFrames_Auras (at the end of the file).

  Diminishing-return categories for WoW 3.3.5a (WotLK), from the Wrath DR table on
  warcraft.wiki.gg. Spell IDs are the debuff (aura) IDs the combat log reports.

  IDs can be incomplete (other ranks, pet variants); ArenaFrames also matches by spell
  name built from these IDs, except for names listed in NO_NAME_MATCH (shared with a
  non-CC aura or with another category). Missing a spell? /aframes debug lists debuffs
  seen on arena enemies that aren't in this table.
]]

ArenaFrames_DR = {
  -- category -> label for /aframes debug
  LABELS = {
    stun = "Stun", opener = "Opener stun", rndstun = "Random stun",
    incap = "Incapacitate", scatter = "Scatter", fear = "Fear", horror = "Horror",
    silence = "Silence", root = "Root", rndroot = "Random root", disarm = "Disarm",
    cyclone = "Cyclone",
  },

  SPELLS = {
    -- Controlled stuns
    [5211] = "stun", [6798] = "stun", [8983] = "stun",              -- Bash
    [22570] = "stun", [49802] = "stun",                              -- Maim
    [24394] = "stun",                                                -- Intimidation
    [50519] = "stun",                                                -- Sonic Blast (bat)
    [50518] = "stun",                                                -- Ravage (ravager)
    [44572] = "stun",                                                -- Deep Freeze
    [853] = "stun", [5588] = "stun", [5589] = "stun", [10308] = "stun", -- Hammer of Justice
    [2812] = "stun", [10318] = "stun", [27139] = "stun", [48816] = "stun", [48817] = "stun", -- Holy Wrath
    [408] = "stun", [8643] = "stun",                                 -- Kidney Shot
    [58861] = "stun",                                                -- Bash (Spirit Wolf)
    [30283] = "stun", [30413] = "stun", [30414] = "stun", [47846] = "stun", [47847] = "stun", -- Shadowfury
    [60995] = "stun",                                                -- Demon Charge
    [30153] = "stun", [30195] = "stun", [30197] = "stun", [47995] = "stun", -- Intercept (Felguard)
    [20253] = "stun",                                                -- Intercept (warrior stun)
    [12809] = "stun",                                                -- Concussion Blow
    [46968] = "stun",                                                -- Shockwave
    [20549] = "stun",                                                -- War Stomp
    [47481] = "stun",                                                -- Gnaw (ghoul)

    -- Opener stuns
    [1833] = "opener",                                               -- Cheap Shot
    [9005] = "opener", [9823] = "opener", [9827] = "opener", [27006] = "opener", [49803] = "opener", -- Pounce

    -- Random stuns (procs; generic aura names, so ID-only)
    [12355] = "rndstun",                                             -- Impact
    [39796] = "rndstun",                                             -- Stoneclaw Stun
    [12798] = "rndstun",                                             -- Revenge Stun
    [5530] = "rndstun",                                              -- Mace Stun Effect
    [20170] = "rndstun",                                             -- Seal of Justice stun
    [16922] = "rndstun",                                             -- Starfire Stun (Celestial Focus)
    [19410] = "rndstun",                                             -- Improved Concussive Shot

    -- Incapacitates
    [118] = "incap", [12824] = "incap", [12825] = "incap", [12826] = "incap", -- Polymorph
    [28271] = "incap", [28272] = "incap", [61305] = "incap", [61721] = "incap", [61780] = "incap", -- Polymorph variants
    [1776] = "incap",                                                -- Gouge
    [6770] = "incap", [2070] = "incap", [11297] = "incap", [51724] = "incap", -- Sap
    [20066] = "incap",                                               -- Repentance
    [51514] = "incap",                                               -- Hex
    [3355] = "incap", [14308] = "incap", [14309] = "incap",          -- Freezing Trap Effect
    [60210] = "incap",                                               -- Freezing Arrow Effect
    [19386] = "incap", [24132] = "incap", [24133] = "incap", [27068] = "incap", [49011] = "incap", [49012] = "incap", -- Wyvern Sting (sleep)
    [2637] = "incap", [18657] = "incap", [18658] = "incap",          -- Hibernate
    [9484] = "incap", [9485] = "incap", [10955] = "incap",           -- Shackle Undead
    [710] = "incap", [18647] = "incap",                              -- Banish
    [49203] = "incap",                                               -- Hungering Cold

    -- Scatter / Dragon's Breath
    [19503] = "scatter",                                             -- Scatter Shot
    [31661] = "scatter", [33041] = "scatter", [33042] = "scatter", [33043] = "scatter",
    [42949] = "scatter", [42950] = "scatter",                        -- Dragon's Breath

    -- Fears (Blind shares this in WotLK)
    [2094] = "fear",                                                 -- Blind
    [5782] = "fear", [6213] = "fear", [6215] = "fear",               -- Fear
    [6358] = "fear",                                                 -- Seduction
    [5484] = "fear", [17928] = "fear",                               -- Howl of Terror
    [8122] = "fear", [8124] = "fear", [10888] = "fear", [10890] = "fear", -- Psychic Scream
    [5246] = "fear",                                                 -- Intimidating Shout
    [1513] = "fear", [14326] = "fear", [14327] = "fear",             -- Scare Beast
    [10326] = "fear",                                                -- Turn Evil

    -- Horrors
    [6789] = "horror", [17925] = "horror", [17926] = "horror", [27223] = "horror",
    [47859] = "horror", [47860] = "horror",                          -- Death Coil
    [64044] = "horror",                                              -- Psychic Horror

    -- Silences
    [47476] = "silence",                                             -- Strangulate
    [34490] = "silence",                                             -- Silencing Shot
    [18469] = "silence", [55021] = "silence",                        -- Counterspell - Silenced
    [15487] = "silence",                                             -- Silence
    [1330] = "silence",                                              -- Garrote - Silence
    [18425] = "silence",                                             -- Kick - Silenced
    [24259] = "silence",                                             -- Spell Lock
    [31117] = "silence",                                             -- Unstable Affliction (silence on dispel)
    [18498] = "silence",                                             -- Gag Order
    [25046] = "silence", [28730] = "silence", [50613] = "silence",   -- Arcane Torrent
    [53588] = "silence", [53589] = "silence",                        -- Nether Shock

    -- Controlled roots
    [339] = "root", [1062] = "root", [5195] = "root", [5196] = "root", [9852] = "root",
    [9853] = "root", [26989] = "root", [53308] = "root",             -- Entangling Roots
    [19975] = "root", [19974] = "root", [19973] = "root", [19972] = "root", [19971] = "root",
    [19970] = "root", [27010] = "root", [53313] = "root",            -- Nature's Grasp roots
    [122] = "root", [865] = "root", [6131] = "root", [10230] = "root", [27088] = "root",
    [42917] = "root",                                                -- Frost Nova
    [33395] = "root",                                                -- Freeze (Water Elemental)
    [50245] = "root",                                                -- Pin
    [64695] = "root",                                                -- Earthgrab
    [63685] = "root",                                                -- Freeze (Frost Shock)

    -- Random roots
    [12494] = "rndroot",                                             -- Frostbite
    [19185] = "rndroot", [64803] = "rndroot", [64804] = "rndroot",   -- Entrapment
    [19229] = "rndroot",                                             -- Improved Wing Clip
    [23694] = "rndroot",                                             -- Improved Hamstring
    [55080] = "rndroot",                                             -- Shattered Barrier

    -- Disarms
    [676] = "disarm",                                                -- Disarm
    [51722] = "disarm",                                              -- Dismantle
    [64058] = "disarm",                                              -- Psychic Horror (disarm)
    [53359] = "disarm",                                              -- Chimera Shot - Scorpid
    [50541] = "disarm",                                              -- Snatch
    [64346] = "disarm",                                              -- Fiery Payback

    -- Self-DR only
    [33786] = "cyclone",                                             -- Cyclone
  },

  -- Names that must not be matched by name: shared with a non-CC aura (UA dot, Wyvern
  -- Sting dot) or with another category (Psychic Horror, Intercept charge), or generic.
  NO_NAME_MATCH = {
    [31117] = true, [19386] = true, [64044] = true, [64058] = true,
    [12355] = true, [39796] = true, [12798] = true, [5530] = true, [20170] = true,
    [16922] = true, [19410] = true, [20253] = true, [30153] = true,
  },
}

--[[
  Aura data for the unit frames (target / focus, later arena rows). WoW 3.3.5a.

  * CC_PRIORITY: which CC wins the portrait square, by DR category from DRList.lua.
    Roots and slows are deliberately left out (owner: "only the core ones").
  * IMMUNE: buffs that take the portrait like a CC (they matter more than any CC).
  * BUFFS: enemy buffs worth seeing in arena (defensives, immunities, big cooldowns).
    Everything else (Arcane Intellect & co) is hidden.
  * LOCKOUT: interrupt spell -> school lockout seconds, from SPELL_INTERRUPT. Shown in the
    portrait with the interrupt's icon, at silence priority.

  IDs are matched first, then the spell name built from them (catches other ranks).
]]

ArenaFrames_Auras = {
  CC_PRIORITY = {
    immune = 100, cyclone = 95,
    stun = 80, opener = 80, rndstun = 78,
    incap = 70, scatter = 70, fear = 70, horror = 70,
    silence = 60, lockout = 60,
    disarm = 50,
  },

  -- portrait border color by kind
  CC_COLORS = {
    immune = { 1, 0.82, 0 }, cyclone = { 0.2, 1, 0.6 },
    stun = { 1, 0.15, 0.15 }, opener = { 1, 0.15, 0.15 }, rndstun = { 1, 0.15, 0.15 },
    incap = { 0.75, 0.35, 1 }, scatter = { 0.75, 0.35, 1 }, fear = { 0.75, 0.35, 1 },
    horror = { 0.75, 0.35, 1 },
    silence = { 0.3, 0.6, 1 }, lockout = { 0.3, 0.6, 1 },
    disarm = { 1, 0.5, 0.1 },
  },

  IMMUNE = {
    [642] = true,                                    -- Divine Shield
    [45438] = true,                                  -- Ice Block
    [1022] = true, [5599] = true, [10278] = true,    -- Hand of Protection
  },

  BUFFS = {
    [642] = true, [45438] = true, [1022] = true, [5599] = true, [10278] = true,
    [19263] = true,                                  -- Deterrence
    [31224] = true,                                  -- Cloak of Shadows
    [5277] = true, [26669] = true,                   -- Evasion
    [48707] = true,                                  -- Anti-Magic Shell
    [48792] = true,                                  -- Icebound Fortitude
    [49039] = true,                                  -- Lichborne
    [33206] = true,                                  -- Pain Suppression
    [47788] = true,                                  -- Guardian Spirit
    [47585] = true,                                  -- Dispersion
    [6346] = true,                                   -- Fear Ward
    [10060] = true,                                  -- Power Infusion
    [498] = true,                                    -- Divine Protection
    [1044] = true,                                   -- Hand of Freedom
    [6940] = true,                                   -- Hand of Sacrifice
    [31821] = true,                                  -- Aura Mastery
    [31884] = true,                                  -- Avenging Wrath
    [46924] = true,                                  -- Bladestorm
    [23920] = true,                                  -- Spell Reflection
    [871] = true,                                    -- Shield Wall
    [1719] = true,                                   -- Recklessness
    [12292] = true,                                  -- Death Wish
    [22812] = true,                                  -- Barkskin
    [61336] = true,                                  -- Survival Instincts
    [50334] = true,                                  -- Berserk
    [29166] = true,                                  -- Innervate
    [17116] = true, [16188] = true,                  -- Nature's Swiftness (druid, shaman)
    [12472] = true,                                  -- Icy Veins
    [12042] = true,                                  -- Arcane Power
    [12043] = true,                                  -- Presence of Mind
    [51713] = true,                                  -- Shadow Dance
    [13750] = true,                                  -- Adrenaline Rush
    [51690] = true,                                  -- Killing Spree
    [2983] = true, [8696] = true, [11305] = true,    -- Sprint
    [2825] = true, [32182] = true,                   -- Bloodlust, Heroism
    [30823] = true,                                  -- Shamanistic Rage
    [8178] = true,                                   -- Grounding Totem Effect
    [16166] = true,                                  -- Elemental Mastery
    [34471] = true,                                  -- The Beast Within
    [54216] = true,                                  -- Master's Call
    [49016] = true,                                  -- Hysteria
  },

  LOCKOUT = {
    [1766] = 5, [1767] = 5, [1768] = 5, [1769] = 5, [38768] = 5,   -- Kick
    [2139] = 8,                                                    -- Counterspell
    [6552] = 4, [6554] = 4,                                        -- Pummel
    [72] = 6, [1671] = 6, [1672] = 6, [29704] = 6,                 -- Shield Bash
    [47528] = 4,                                                   -- Mind Freeze
    [57994] = 2,                                                   -- Wind Shear
    [19244] = 5, [19647] = 6,                                      -- Spell Lock
    [19675] = 4,                                                   -- Feral Charge Effect (bear)
  },
}

--[[
  Spec detection (arena): spells, auras and pet spells only one spec has in 3.3.5.
  { class, spec, name (English, also matched by name), ids = { every rank / aura ID }, weight }
  weight 3 = deep talent only that spec reaches, 2 = clearly that tree, 1 = weak hint.
]]
ArenaFrames_Specs = {
  -- names matter most: they're matched from the combat log, UNIT_SPELLCAST_* and aura scans
  { class = "ROGUE", spec = "Assassination", name = "Mutilate", ids = { 1329, 34411, 34412, 34413, 48663, 48666 }, weight = 3 },
  { class = "ROGUE", spec = "Assassination", name = "Hunger For Blood", ids = { 51662, 63848 }, weight = 3 },
  { class = "ROGUE", spec = "Assassination", name = "Cold Blood", ids = { 14177 }, weight = 2 },
  { class = "ROGUE", spec = "Assassination", name = "Overkill", ids = { 58426, 58427 }, weight = 2 },
  { class = "ROGUE", spec = "Combat", name = "Killing Spree", ids = { 51690 }, weight = 3 },
  { class = "ROGUE", spec = "Combat", name = "Adrenaline Rush", ids = { 13750 }, weight = 3 },
  { class = "ROGUE", spec = "Combat", name = "Blade Flurry", ids = { 13877 }, weight = 2 },
  { class = "ROGUE", spec = "Combat", name = "Riposte", ids = { 14251 }, weight = 2 },
  { class = "ROGUE", spec = "Subtlety", name = "Shadow Dance", ids = { 51713 }, weight = 3 },
  { class = "ROGUE", spec = "Subtlety", name = "Shadowstep", ids = { 36554, 36563 }, weight = 2 },
  { class = "ROGUE", spec = "Subtlety", name = "Premeditation", ids = { 14183 }, weight = 2 },
  { class = "ROGUE", spec = "Subtlety", name = "Hemorrhage", ids = { 16511, 17347, 17348, 26864, 48660 }, weight = 2 },
  { class = "ROGUE", spec = "Subtlety", name = "Ghostly Strike", ids = { 14278 }, weight = 2 },
  { class = "ROGUE", spec = "Subtlety", name = "Preparation", ids = { 14185 }, weight = 1 },

  { class = "PRIEST", spec = "Discipline", name = "Penance", ids = { 47540, 53005, 53006, 53007, 47666, 52983, 52998,
    52999, 53000, 47750, 52986, 52987, 52988, 53001 }, weight = 3 },
  { class = "PRIEST", spec = "Discipline", name = "Pain Suppression", ids = { 33206 }, weight = 3 },
  { class = "PRIEST", spec = "Discipline", name = "Power Infusion", ids = { 10060 }, weight = 2 },
  { class = "PRIEST", spec = "Discipline", name = "Borrowed Time", ids = { 59887, 59888, 59889, 59890, 59891 }, weight = 2 },
  { class = "PRIEST", spec = "Discipline", name = "Grace", ids = { 47930 }, weight = 2 },
  { class = "PRIEST", spec = "Discipline", name = "Divine Aegis", ids = { 47753 }, weight = 2 },
  { class = "PRIEST", spec = "Holy", name = "Guardian Spirit", ids = { 47788 }, weight = 3 },
  { class = "PRIEST", spec = "Holy", name = "Circle of Healing", ids = { 34861, 34863, 34864, 34865, 34866, 48088, 48089 },
    weight = 3 },
  { class = "PRIEST", spec = "Holy", name = "Lightwell", ids = { 724, 27870, 27871, 28275, 48086, 48087 }, weight = 2 },
  { class = "PRIEST", spec = "Holy", name = "Serendipity", ids = { 63731, 63735, 63737 }, weight = 2 },
  { class = "PRIEST", spec = "Shadow", name = "Shadowform", ids = { 15473 }, weight = 3 },
  { class = "PRIEST", spec = "Shadow", name = "Vampiric Touch", ids = { 34914, 34916, 34917, 48159, 48160 }, weight = 3 },
  { class = "PRIEST", spec = "Shadow", name = "Dispersion", ids = { 47585 }, weight = 3 },
  { class = "PRIEST", spec = "Shadow", name = "Mind Flay", ids = { 15407, 17311, 17312, 17313, 17314, 18807, 25387,
    48155, 48156 }, weight = 3 },
  { class = "PRIEST", spec = "Shadow", name = "Psychic Horror", ids = { 64044, 64058 }, weight = 2 },
  { class = "PRIEST", spec = "Shadow", name = "Silence", ids = { 15487 }, weight = 2 },
  { class = "PRIEST", spec = "Shadow", name = "Vampiric Embrace", ids = { 15286 }, weight = 2 },

  { class = "MAGE", spec = "Frost", name = "Deep Freeze", ids = { 44572 }, weight = 3 },
  { class = "MAGE", spec = "Frost", name = "Summon Water Elemental", ids = { 31687 }, weight = 3 },
  { class = "MAGE", spec = "Frost", name = "Freeze", ids = { 33395 }, weight = 3 },            -- Water Elemental
  { class = "MAGE", spec = "Frost", name = "Waterbolt", ids = { 31707, 72898 }, weight = 3 },   -- Water Elemental
  { class = "MAGE", spec = "Frost", name = "Ice Barrier", ids = { 11426, 13031, 13032, 13033, 27134, 33405, 43038, 43039 },
    weight = 2 },
  { class = "MAGE", spec = "Frost", name = "Fingers of Frost", ids = { 44544 }, weight = 2 },
  { class = "MAGE", spec = "Frost", name = "Fireball!", ids = { 57761 }, weight = 2 },          -- Brain Freeze proc
  { class = "MAGE", spec = "Frost", name = "Cold Snap", ids = { 11958 }, weight = 1 },
  { class = "MAGE", spec = "Fire", name = "Living Bomb", ids = { 44457, 55359, 55360 }, weight = 3 },
  { class = "MAGE", spec = "Fire", name = "Hot Streak", ids = { 48108 }, weight = 3 },
  { class = "MAGE", spec = "Fire", name = "Dragon's Breath", ids = { 31661, 33041, 33042, 33043, 42949, 42950 }, weight = 2 },
  { class = "MAGE", spec = "Fire", name = "Blast Wave", ids = { 11113, 13018, 13019, 13020, 13021, 27133, 33933, 42944,
    42945 }, weight = 2 },
  { class = "MAGE", spec = "Fire", name = "Combustion", ids = { 11129 }, weight = 2 },
  { class = "MAGE", spec = "Arcane", name = "Arcane Barrage", ids = { 44425, 44780, 44781 }, weight = 3 },
  { class = "MAGE", spec = "Arcane", name = "Arcane Power", ids = { 12042 }, weight = 2 },
  { class = "MAGE", spec = "Arcane", name = "Slow", ids = { 31589 }, weight = 2 },
  { class = "MAGE", spec = "Arcane", name = "Missile Barrage", ids = { 44401 }, weight = 2 },

  { class = "PALADIN", spec = "Holy", name = "Holy Shock", ids = { 20473, 20929, 20930, 27174, 33072, 48824, 48825, 25914,
    25913, 25903, 27175, 33074, 48820, 48821 }, weight = 3 },
  { class = "PALADIN", spec = "Holy", name = "Beacon of Light", ids = { 53563, 53651, 53654 }, weight = 3 },
  { class = "PALADIN", spec = "Holy", name = "Divine Illumination", ids = { 31842 }, weight = 2 },
  { class = "PALADIN", spec = "Holy", name = "Divine Favor", ids = { 20216 }, weight = 2 },
  { class = "PALADIN", spec = "Holy", name = "Infusion of Light", ids = { 53672, 54149 }, weight = 2 },
  { class = "PALADIN", spec = "Protection", name = "Avenger's Shield", ids = { 31935, 32699, 32700, 48826, 48827 }, weight = 3 },
  { class = "PALADIN", spec = "Protection", name = "Hammer of the Righteous", ids = { 53595 }, weight = 3 },
  { class = "PALADIN", spec = "Protection", name = "Holy Shield", ids = { 20925, 20927, 20928, 27179, 48951, 48952 },
    weight = 2 },
  { class = "PALADIN", spec = "Retribution", name = "Crusader Strike", ids = { 35395 }, weight = 3 },
  { class = "PALADIN", spec = "Retribution", name = "Divine Storm", ids = { 53385 }, weight = 3 },
  { class = "PALADIN", spec = "Retribution", name = "Repentance", ids = { 20066 }, weight = 2 },
  { class = "PALADIN", spec = "Retribution", name = "The Art of War", ids = { 53489, 59578 }, weight = 2 },
  { class = "PALADIN", spec = "Retribution", name = "Sanctified Retribution", ids = { 31869 }, weight = 2 },

  { class = "WARRIOR", spec = "Arms", name = "Mortal Strike", ids = { 12294, 21551, 21552, 21553, 25248, 30330, 47485,
    47486 }, weight = 3 },
  { class = "WARRIOR", spec = "Arms", name = "Bladestorm", ids = { 46924 }, weight = 3 },
  { class = "WARRIOR", spec = "Fury", name = "Bloodthirst", ids = { 23881, 23892, 23893, 23894, 25251, 30335, 47470, 47471 },
    weight = 3 },
  { class = "WARRIOR", spec = "Fury", name = "Rampage", ids = { 29801 }, weight = 2 },
  { class = "WARRIOR", spec = "Fury", name = "Heroic Fury", ids = { 60970 }, weight = 2 },
  { class = "WARRIOR", spec = "Protection", name = "Devastate", ids = { 20243, 30016, 30022, 47497, 47498 }, weight = 3 },
  { class = "WARRIOR", spec = "Protection", name = "Shockwave", ids = { 46968 }, weight = 3 },
  { class = "WARRIOR", spec = "Protection", name = "Concussion Blow", ids = { 12809 }, weight = 2 },
  { class = "WARRIOR", spec = "Protection", name = "Vigilance", ids = { 50720 }, weight = 2 },

  { class = "DRUID", spec = "Balance", name = "Moonkin Form", ids = { 24858 }, weight = 3 },
  { class = "DRUID", spec = "Balance", name = "Moonkin Aura", ids = { 24907 }, weight = 2 },
  { class = "DRUID", spec = "Balance", name = "Starfall", ids = { 48505, 53199, 53200, 53201 }, weight = 3 },
  { class = "DRUID", spec = "Balance", name = "Force of Nature", ids = { 33831 }, weight = 3 },
  { class = "DRUID", spec = "Balance", name = "Typhoon", ids = { 50516, 53223, 53225, 53226, 61384 }, weight = 2 },
  { class = "DRUID", spec = "Balance", name = "Insect Swarm", ids = { 5570, 24974, 24975, 24976, 24977, 27013, 48468 },
    weight = 2 },
  { class = "DRUID", spec = "Feral Combat", name = "Mangle (Cat)", ids = { 33876, 33982, 33983, 48565, 48566 }, weight = 3 },
  { class = "DRUID", spec = "Feral Combat", name = "Mangle (Bear)", ids = { 33878, 33986, 33987, 48563, 48564 }, weight = 3 },
  { class = "DRUID", spec = "Feral Combat", name = "Berserk", ids = { 50334 }, weight = 3 },
  { class = "DRUID", spec = "Feral Combat", name = "Survival Instincts", ids = { 61336 }, weight = 2 },
  { class = "DRUID", spec = "Feral Combat", name = "Leader of the Pack", ids = { 24932 }, weight = 2 },
  { class = "DRUID", spec = "Feral Combat", name = "Feral Charge - Cat", ids = { 49376 }, weight = 2 },
  { class = "DRUID", spec = "Feral Combat", name = "Feral Charge - Bear", ids = { 16979 }, weight = 2 },
  { class = "DRUID", spec = "Restoration", name = "Tree of Life", ids = { 33891, 34123 }, weight = 3 },
  { class = "DRUID", spec = "Restoration", name = "Wild Growth", ids = { 48438, 53248, 53249, 53251 }, weight = 3 },
  { class = "DRUID", spec = "Restoration", name = "Swiftmend", ids = { 18562 }, weight = 2 },
  { class = "DRUID", spec = "Restoration", name = "Nature's Swiftness", ids = { 17116 }, weight = 2 },

  { class = "SHAMAN", spec = "Elemental", name = "Thunderstorm", ids = { 51490, 59156, 59158, 59159 }, weight = 3 },
  { class = "SHAMAN", spec = "Elemental", name = "Totem of Wrath", ids = { 30706, 57720, 57721, 57722 }, weight = 3 },
  { class = "SHAMAN", spec = "Elemental", name = "Elemental Mastery", ids = { 16166 }, weight = 2 },
  { class = "SHAMAN", spec = "Enhancement", name = "Stormstrike", ids = { 17364 }, weight = 3 },
  { class = "SHAMAN", spec = "Enhancement", name = "Feral Spirit", ids = { 51533 }, weight = 3 },
  { class = "SHAMAN", spec = "Enhancement", name = "Lava Lash", ids = { 60103 }, weight = 3 },
  { class = "SHAMAN", spec = "Enhancement", name = "Shamanistic Rage", ids = { 30823 }, weight = 2 },
  { class = "SHAMAN", spec = "Enhancement", name = "Maelstrom Weapon", ids = { 53817 }, weight = 2 },
  { class = "SHAMAN", spec = "Enhancement", name = "Unleashed Rage", ids = { 30809 }, weight = 2 },
  { class = "SHAMAN", spec = "Restoration", name = "Earth Shield", ids = { 974, 32593, 32594, 49283, 49284 }, weight = 3 },
  { class = "SHAMAN", spec = "Restoration", name = "Riptide", ids = { 61295, 61299, 61300, 61301 }, weight = 3 },
  { class = "SHAMAN", spec = "Restoration", name = "Mana Tide Totem", ids = { 16190 }, weight = 2 },
  { class = "SHAMAN", spec = "Restoration", name = "Tidal Force", ids = { 55198 }, weight = 2 },
  { class = "SHAMAN", spec = "Restoration", name = "Nature's Swiftness", ids = { 16188 }, weight = 2 },

  { class = "HUNTER", spec = "Beast Mastery", name = "Bestial Wrath", ids = { 19574 }, weight = 3 },
  { class = "HUNTER", spec = "Beast Mastery", name = "The Beast Within", ids = { 34471 }, weight = 3 },
  { class = "HUNTER", spec = "Beast Mastery", name = "Intimidation", ids = { 19577, 24394 }, weight = 2 },
  { class = "HUNTER", spec = "Marksmanship", name = "Chimera Shot", ids = { 53209 }, weight = 3 },
  { class = "HUNTER", spec = "Marksmanship", name = "Silencing Shot", ids = { 34490 }, weight = 2 },
  { class = "HUNTER", spec = "Marksmanship", name = "Trueshot Aura", ids = { 19506 }, weight = 2 },
  { class = "HUNTER", spec = "Marksmanship", name = "Readiness", ids = { 23989 }, weight = 2 },
  { class = "HUNTER", spec = "Marksmanship", name = "Scatter Shot", ids = { 19503 }, weight = 2 },
  { class = "HUNTER", spec = "Survival", name = "Explosive Shot", ids = { 53301, 60051, 60052, 60053 }, weight = 3 },
  { class = "HUNTER", spec = "Survival", name = "Black Arrow", ids = { 3674, 63668, 63669, 63670, 63671, 63672 }, weight = 3 },
  { class = "HUNTER", spec = "Survival", name = "Wyvern Sting", ids = { 19386, 24132, 24133, 27068, 49011, 49012 }, weight = 3 },
  { class = "HUNTER", spec = "Survival", name = "Counterattack", ids = { 19306, 20909, 20910, 27067, 48998, 48999 }, weight = 2 },

  { class = "WARLOCK", spec = "Affliction", name = "Unstable Affliction", ids = { 30108, 30404, 30405, 47841, 47843 },
    weight = 3 },
  { class = "WARLOCK", spec = "Affliction", name = "Haunt", ids = { 48181, 59161, 59163, 59164 }, weight = 3 },
  { class = "WARLOCK", spec = "Affliction", name = "Curse of Exhaustion", ids = { 18223 }, weight = 2 },
  { class = "WARLOCK", spec = "Demonology", name = "Metamorphosis", ids = { 47241 }, weight = 3 },
  { class = "WARLOCK", spec = "Demonology", name = "Summon Felguard", ids = { 30146 }, weight = 3 },
  { class = "WARLOCK", spec = "Demonology", name = "Demonic Empowerment", ids = { 47193 }, weight = 2 },
  { class = "WARLOCK", spec = "Destruction", name = "Chaos Bolt", ids = { 50796, 59170, 59171, 59172 }, weight = 3 },
  { class = "WARLOCK", spec = "Destruction", name = "Shadowfury", ids = { 30283, 30413, 30414, 47846, 47847 }, weight = 3 },
  { class = "WARLOCK", spec = "Destruction", name = "Conflagrate", ids = { 17962 }, weight = 2 },
  { class = "WARLOCK", spec = "Destruction", name = "Backdraft", ids = { 54274, 54276, 54277 }, weight = 2 },

  { class = "DEATHKNIGHT", spec = "Blood", name = "Heart Strike", ids = { 55050, 55258, 55259, 55260, 55261, 55262 },
    weight = 3 },
  { class = "DEATHKNIGHT", spec = "Blood", name = "Hysteria", ids = { 49016 }, weight = 3 },
  { class = "DEATHKNIGHT", spec = "Blood", name = "Dancing Rune Weapon", ids = { 49028 }, weight = 3 },
  { class = "DEATHKNIGHT", spec = "Blood", name = "Vampiric Blood", ids = { 55233 }, weight = 2 },
  { class = "DEATHKNIGHT", spec = "Blood", name = "Mark of Blood", ids = { 49005 }, weight = 2 },
  { class = "DEATHKNIGHT", spec = "Frost", name = "Howling Blast", ids = { 49184, 51408, 51409, 51410, 51411 }, weight = 3 },
  { class = "DEATHKNIGHT", spec = "Frost", name = "Frost Strike", ids = { 49143, 51416, 51417, 51418, 51419, 55268 },
    weight = 3 },
  { class = "DEATHKNIGHT", spec = "Frost", name = "Hungering Cold", ids = { 49203 }, weight = 2 },
  { class = "DEATHKNIGHT", spec = "Frost", name = "Lichborne", ids = { 49039 }, weight = 2 },
  { class = "DEATHKNIGHT", spec = "Frost", name = "Deathchill", ids = { 49796 }, weight = 2 },
  { class = "DEATHKNIGHT", spec = "Unholy", name = "Scourge Strike", ids = { 55090, 55265, 55270, 55271 }, weight = 3 },
  { class = "DEATHKNIGHT", spec = "Unholy", name = "Summon Gargoyle", ids = { 49206 }, weight = 3 },
  { class = "DEATHKNIGHT", spec = "Unholy", name = "Anti-Magic Zone", ids = { 51052 }, weight = 2 },
  { class = "DEATHKNIGHT", spec = "Unholy", name = "Bone Shield", ids = { 49222 }, weight = 2 },
  { class = "DEATHKNIGHT", spec = "Unholy", name = "Corpse Explosion", ids = { 49158, 51325, 51326, 51327, 51328 },
    weight = 2 },
}

--[[
  Cooldowns tracked for the enemy cooldown bar and the party cooldown icons.
  { class ("ANY" = everyone; race = "Human" etc. for racials), name, ids = { every rank / trigger ID }, cd (seconds, what
    arena players usually have), cat = interrupt|cc|defensive|offensive|mobility|healer|other,
    talent = tree (or "seen"): party icons show it only once that player has used it,
    event = combat log event that means "used" (default SPELL_CAST_SUCCESS),
    shares = { names that go on cooldown with it } }
]]
ArenaFrames_Cooldowns = {
  -- everyone (trinket icon = your faction's, set in ArenaFrames.lua: the spell's own icon looks like Dispel Magic)
  { class = "ANY", name = "PvP Trinket", ids = { 42292 }, cd = 120, cat = "defensive", trinket = true,
    shares = { "Every Man for Himself" } },
  { class = "ANY", race = "Human", name = "Every Man for Himself", ids = { 59752 }, cd = 120, cat = "defensive",
    shares = { "PvP Trinket" } },
  { class = "ANY", race = "Scourge", name = "Will of the Forsaken", ids = { 7744 }, cd = 120, cat = "defensive" },
  { class = "ANY", race = "Dwarf", name = "Stoneform", ids = { 20594 }, cd = 120, cat = "defensive" },
  { class = "ANY", race = "Gnome", name = "Escape Artist", ids = { 20589 }, cd = 105, cat = "mobility" },
  { class = "ANY", race = "NightElf", name = "Shadowmeld", ids = { 58984 }, cd = 120, cat = "defensive" },
  { class = "ANY", race = "Draenei", name = "Gift of the Naaru", ids = { 28880, 59542, 59543, 59544, 59545, 59547, 59548 },
    cd = 180, cat = "healer" },
  { class = "ANY", race = "Orc", name = "Blood Fury", ids = { 20572, 33697, 33702 }, cd = 120, cat = "offensive" },
  { class = "ANY", race = "Troll", name = "Berserking", ids = { 26297 }, cd = 180, cat = "offensive" },
  { class = "ANY", race = "Tauren", name = "War Stomp", ids = { 20549 }, cd = 120, cat = "cc" },
  { class = "ANY", race = "BloodElf", name = "Arcane Torrent", ids = { 28730, 25046, 50613 }, cd = 120, cat = "interrupt" },

  { class = "ROGUE", name = "Kick", ids = { 1766, 1767, 1768, 1769, 38768 }, cd = 10, cat = "interrupt" },
  { class = "ROGUE", name = "Kidney Shot", ids = { 408, 8643 }, cd = 20, cat = "cc" },
  { class = "ROGUE", name = "Blind", ids = { 2094 }, cd = 120, cat = "cc" },
  { class = "ROGUE", name = "Cloak of Shadows", ids = { 31224 }, cd = 60, cat = "defensive" },
  { class = "ROGUE", name = "Vanish", ids = { 1856, 1857, 26889 }, cd = 120, cat = "defensive" },
  { class = "ROGUE", name = "Evasion", ids = { 5277, 26669 }, cd = 180, cat = "defensive" },
  { class = "ROGUE", name = "Sprint", ids = { 2983, 8696, 11305 }, cd = 180, cat = "mobility" },
  { class = "ROGUE", name = "Dismantle", ids = { 51722 }, cd = 60, cat = "cc" },
  { class = "ROGUE", name = "Shadowstep", ids = { 36554 }, cd = 20, cat = "mobility", talent = "Subtlety" },
  { class = "ROGUE", name = "Preparation", ids = { 14185 }, cd = 300, cat = "defensive", talent = "Subtlety" },
  { class = "ROGUE", name = "Shadow Dance", ids = { 51713 }, cd = 60, cat = "offensive", talent = "Subtlety" },
  { class = "ROGUE", name = "Cold Blood", ids = { 14177 }, cd = 180, cat = "offensive", talent = "Assassination" },
  { class = "ROGUE", name = "Adrenaline Rush", ids = { 13750 }, cd = 180, cat = "offensive", talent = "Combat" },
  { class = "ROGUE", name = "Killing Spree", ids = { 51690 }, cd = 120, cat = "offensive", talent = "Combat" },

  { class = "PRIEST", name = "Psychic Scream", ids = { 8122, 8124, 10888, 10890 }, cd = 30, cat = "cc" },
  { class = "PRIEST", name = "Fear Ward", ids = { 6346 }, cd = 180, cat = "defensive" },
  { class = "PRIEST", name = "Shadowfiend", ids = { 34433 }, cd = 300, cat = "other" },
  { class = "PRIEST", name = "Hymn of Hope", ids = { 64901 }, cd = 360, cat = "healer" },
  { class = "PRIEST", name = "Divine Hymn", ids = { 64843 }, cd = 480, cat = "healer" },
  { class = "PRIEST", name = "Pain Suppression", ids = { 33206 }, cd = 144, cat = "defensive", talent = "Discipline" },
  { class = "PRIEST", name = "Power Infusion", ids = { 10060 }, cd = 96, cat = "offensive", talent = "Discipline" },
  { class = "PRIEST", name = "Guardian Spirit", ids = { 47788 }, cd = 180, cat = "defensive", talent = "Holy" },
  { class = "PRIEST", name = "Dispersion", ids = { 47585 }, cd = 120, cat = "defensive", talent = "Shadow" },
  { class = "PRIEST", name = "Silence", ids = { 15487 }, cd = 45, cat = "interrupt", talent = "Shadow" },
  { class = "PRIEST", name = "Psychic Horror", ids = { 64044 }, cd = 120, cat = "cc", talent = "Shadow" },

  { class = "MAGE", name = "Counterspell", ids = { 2139 }, cd = 24, cat = "interrupt" },
  { class = "MAGE", name = "Ice Block", ids = { 45438 }, cd = 240, cat = "defensive" },
  { class = "MAGE", name = "Blink", ids = { 1953 }, cd = 15, cat = "mobility" },
  { class = "MAGE", name = "Frost Nova", ids = { 122, 865, 6131, 10230, 27088, 42917 }, cd = 20, cat = "cc" },
  { class = "MAGE", name = "Invisibility", ids = { 66 }, cd = 180, cat = "defensive" },
  { class = "MAGE", name = "Mirror Image", ids = { 55342 }, cd = 180, cat = "defensive" },
  { class = "MAGE", name = "Evocation", ids = { 12051 }, cd = 240, cat = "other" },
  { class = "MAGE", name = "Deep Freeze", ids = { 44572 }, cd = 30, cat = "cc", talent = "Frost" },
  { class = "MAGE", name = "Cold Snap", ids = { 11958 }, cd = 384, cat = "defensive", talent = "Frost" },
  { class = "MAGE", name = "Icy Veins", ids = { 12472 }, cd = 144, cat = "offensive", talent = "Frost" },
  { class = "MAGE", name = "Freeze", ids = { 33395 }, cd = 25, cat = "cc", talent = "Frost" },   -- Water Elemental
  { class = "MAGE", name = "Dragon's Breath", ids = { 31661, 33041, 33042, 33043, 42949, 42950 }, cd = 20, cat = "cc",
    talent = "Fire" },
  { class = "MAGE", name = "Combustion", ids = { 11129 }, cd = 120, cat = "offensive", talent = "Fire" },
  { class = "MAGE", name = "Presence of Mind", ids = { 12043 }, cd = 120, cat = "offensive", talent = "Arcane" },
  { class = "MAGE", name = "Arcane Power", ids = { 12042 }, cd = 120, cat = "offensive", talent = "Arcane" },

  { class = "PALADIN", name = "Hammer of Justice", ids = { 853, 5588, 5589, 10308 }, cd = 40, cat = "cc" },
  { class = "PALADIN", name = "Divine Shield", ids = { 642 }, cd = 300, cat = "defensive" },
  { class = "PALADIN", name = "Hand of Protection", ids = { 1022, 5599, 10278 }, cd = 180, cat = "defensive" },
  { class = "PALADIN", name = "Hand of Freedom", ids = { 1044 }, cd = 25, cat = "defensive" },
  { class = "PALADIN", name = "Hand of Sacrifice", ids = { 6940 }, cd = 120, cat = "defensive" },
  { class = "PALADIN", name = "Divine Protection", ids = { 498 }, cd = 180, cat = "defensive" },
  { class = "PALADIN", name = "Avenging Wrath", ids = { 31884 }, cd = 180, cat = "offensive" },
  { class = "PALADIN", name = "Aura Mastery", ids = { 31821 }, cd = 120, cat = "defensive", talent = "Holy" },
  { class = "PALADIN", name = "Divine Favor", ids = { 20216 }, cd = 120, cat = "healer", talent = "Holy" },
  { class = "PALADIN", name = "Divine Illumination", ids = { 31842 }, cd = 180, cat = "healer", talent = "Holy" },
  { class = "PALADIN", name = "Divine Sacrifice", ids = { 64205 }, cd = 120, cat = "defensive", talent = "Protection" },
  { class = "PALADIN", name = "Repentance", ids = { 20066 }, cd = 60, cat = "cc", talent = "Retribution" },

  { class = "WARRIOR", name = "Pummel", ids = { 6552, 6554 }, cd = 10, cat = "interrupt" },
  { class = "WARRIOR", name = "Shield Bash", ids = { 72 }, cd = 12, cat = "interrupt", talent = "seen" },
  { class = "WARRIOR", name = "Spell Reflection", ids = { 23920 }, cd = 10, cat = "defensive" },
  { class = "WARRIOR", name = "Intervene", ids = { 3411 }, cd = 30, cat = "mobility" },
  { class = "WARRIOR", name = "Intercept", ids = { 20252 }, cd = 20, cat = "mobility" },
  { class = "WARRIOR", name = "Disarm", ids = { 676 }, cd = 60, cat = "cc" },
  { class = "WARRIOR", name = "Intimidating Shout", ids = { 5246 }, cd = 120, cat = "cc" },
  { class = "WARRIOR", name = "Shattering Throw", ids = { 64382 }, cd = 300, cat = "offensive" },
  { class = "WARRIOR", name = "Shield Wall", ids = { 871 }, cd = 300, cat = "defensive", talent = "seen" },
  { class = "WARRIOR", name = "Berserker Rage", ids = { 18499 }, cd = 30, cat = "defensive" },
  { class = "WARRIOR", name = "Bladestorm", ids = { 46924 }, cd = 90, cat = "offensive", talent = "Arms" },
  { class = "WARRIOR", name = "Concussion Blow", ids = { 12809 }, cd = 30, cat = "cc", talent = "Protection" },
  { class = "WARRIOR", name = "Shockwave", ids = { 46968 }, cd = 20, cat = "cc", talent = "Protection" },

  { class = "DRUID", name = "Barkskin", ids = { 22812 }, cd = 60, cat = "defensive" },
  { class = "DRUID", name = "Innervate", ids = { 29166 }, cd = 180, cat = "healer" },
  { class = "DRUID", name = "Bash", ids = { 5211, 6798, 8983 }, cd = 30, cat = "cc" },
  { class = "DRUID", name = "Dash", ids = { 1850, 9821, 33357 }, cd = 180, cat = "mobility" },
  { class = "DRUID", name = "Nature's Swiftness", ids = { 17116 }, cd = 180, cat = "healer", talent = "Restoration" },
  { class = "DRUID", name = "Swiftmend", ids = { 18562 }, cd = 15, cat = "healer", talent = "Restoration" },
  { class = "DRUID", name = "Feral Charge - Bear", ids = { 16979 }, cd = 15, cat = "interrupt", talent = "Feral Combat" },
  { class = "DRUID", name = "Feral Charge - Cat", ids = { 49376 }, cd = 30, cat = "mobility", talent = "Feral Combat" },
  { class = "DRUID", name = "Survival Instincts", ids = { 61336 }, cd = 180, cat = "defensive", talent = "Feral Combat" },
  { class = "DRUID", name = "Berserk", ids = { 50334 }, cd = 180, cat = "offensive", talent = "Feral Combat" },
  { class = "DRUID", name = "Starfall", ids = { 48505, 53199, 53200, 53201 }, cd = 90, cat = "offensive",
    talent = "Balance" },
  { class = "DRUID", name = "Typhoon", ids = { 50516, 53223, 53225, 53226, 61384 }, cd = 20, cat = "cc", talent = "Balance" },

  { class = "SHAMAN", name = "Wind Shear", ids = { 57994 }, cd = 6, cat = "interrupt" },
  { class = "SHAMAN", name = "Grounding Totem", ids = { 8177 }, cd = 15, cat = "defensive" },
  { class = "SHAMAN", name = "Hex", ids = { 51514 }, cd = 45, cat = "cc" },
  { class = "SHAMAN", name = "Heroism", ids = { 32182 }, cd = 300, cat = "offensive", talent = "seen" },
  { class = "SHAMAN", name = "Bloodlust", ids = { 2825 }, cd = 300, cat = "offensive", talent = "seen" },
  { class = "SHAMAN", name = "Nature's Swiftness", ids = { 16188 }, cd = 120, cat = "healer", talent = "Restoration" },
  { class = "SHAMAN", name = "Mana Tide Totem", ids = { 16190 }, cd = 300, cat = "healer", talent = "Restoration" },
  { class = "SHAMAN", name = "Tidal Force", ids = { 55198 }, cd = 180, cat = "healer", talent = "Restoration" },
  { class = "SHAMAN", name = "Shamanistic Rage", ids = { 30823 }, cd = 60, cat = "defensive", talent = "Enhancement" },
  { class = "SHAMAN", name = "Feral Spirit", ids = { 51533 }, cd = 180, cat = "offensive", talent = "Enhancement" },
  { class = "SHAMAN", name = "Thunderstorm", ids = { 51490, 59156, 59158, 59159 }, cd = 45, cat = "cc",
    talent = "Elemental" },
  { class = "SHAMAN", name = "Elemental Mastery", ids = { 16166 }, cd = 180, cat = "offensive", talent = "Elemental" },

  { class = "HUNTER", name = "Deterrence", ids = { 19263 }, cd = 90, cat = "defensive" },
  { class = "HUNTER", name = "Freezing Trap", ids = { 1499, 14310, 14311 }, cd = 28, cat = "cc" },
  { class = "HUNTER", name = "Freezing Arrow", ids = { 60192 }, cd = 28, cat = "cc" },
  { class = "HUNTER", name = "Disengage", ids = { 781 }, cd = 25, cat = "mobility" },
  { class = "HUNTER", name = "Master's Call", ids = { 53271 }, cd = 60, cat = "defensive" },
  { class = "HUNTER", name = "Feign Death", ids = { 5384 }, cd = 30, cat = "defensive" },
  { class = "HUNTER", name = "Scatter Shot", ids = { 19503 }, cd = 30, cat = "cc", talent = "Marksmanship" },
  { class = "HUNTER", name = "Silencing Shot", ids = { 34490 }, cd = 20, cat = "interrupt", talent = "Marksmanship" },
  { class = "HUNTER", name = "Readiness", ids = { 23989 }, cd = 180, cat = "other", talent = "Marksmanship" },
  { class = "HUNTER", name = "Wyvern Sting", ids = { 19386, 24132, 24133, 27068, 49011, 49012 }, cd = 60, cat = "cc",
    talent = "Survival" },
  { class = "HUNTER", name = "Intimidation", ids = { 19577 }, cd = 60, cat = "cc", talent = "Beast Mastery" },
  { class = "HUNTER", name = "Bestial Wrath", ids = { 19574 }, cd = 84, cat = "offensive", talent = "Beast Mastery" },
  { class = "HUNTER", name = "Roar of Sacrifice", ids = { 53480 }, cd = 60, cat = "defensive", talent = "Beast Mastery" },

  { class = "WARLOCK", name = "Death Coil", ids = { 6789, 17925, 17926, 27223, 47859, 47860 }, cd = 120, cat = "cc" },
  { class = "WARLOCK", name = "Howl of Terror", ids = { 5484, 17928 }, cd = 40, cat = "cc" },
  { class = "WARLOCK", name = "Demonic Circle: Teleport", ids = { 48020 }, cd = 30, cat = "mobility" },
  { class = "WARLOCK", name = "Spell Lock", ids = { 19244, 19647 }, cd = 24, cat = "interrupt" },   -- Felhunter
  { class = "WARLOCK", name = "Shadowfury", ids = { 30283, 30413, 30414, 47846, 47847 }, cd = 20, cat = "cc",
    talent = "Destruction" },
  { class = "WARLOCK", name = "Metamorphosis", ids = { 47241 }, cd = 180, cat = "offensive", talent = "Demonology" },

  { class = "DEATHKNIGHT", name = "Mind Freeze", ids = { 47528 }, cd = 10, cat = "interrupt" },
  { class = "DEATHKNIGHT", name = "Strangulate", ids = { 47476, 49913, 49914, 49915, 49916 }, cd = 120, cat = "interrupt" },
  { class = "DEATHKNIGHT", name = "Death Grip", ids = { 49576 }, cd = 25, cat = "mobility" },
  { class = "DEATHKNIGHT", name = "Anti-Magic Shell", ids = { 48707 }, cd = 45, cat = "defensive" },
  { class = "DEATHKNIGHT", name = "Icebound Fortitude", ids = { 48792 }, cd = 120, cat = "defensive" },
  { class = "DEATHKNIGHT", name = "Empower Rune Weapon", ids = { 47568 }, cd = 300, cat = "offensive" },
  { class = "DEATHKNIGHT", name = "Gnaw", ids = { 47481 }, cd = 60, cat = "cc", talent = "Unholy" },   -- ghoul
  { class = "DEATHKNIGHT", name = "Lichborne", ids = { 49039 }, cd = 120, cat = "defensive", talent = "Frost" },
  { class = "DEATHKNIGHT", name = "Hungering Cold", ids = { 49203 }, cd = 60, cat = "cc", talent = "Frost" },
  { class = "DEATHKNIGHT", name = "Anti-Magic Zone", ids = { 51052 }, cd = 120, cat = "defensive", talent = "Unholy" },
  { class = "DEATHKNIGHT", name = "Summon Gargoyle", ids = { 49206 }, cd = 180, cat = "offensive", talent = "Unholy" },
}

--[[
  Kill target (3.10). How easy each spec is to kill in WotLK arena, 0-100, before anything
  else is known: escapes / immunities / self-heals / armor make it lower. "_" = spec unknown.
  A starting opinion, meant to be tuned: the owner's own logs correct it per spec over time
  (ArenaFrames_Data.specs, written by tools/arena.py).
]]
ArenaFrames_KillPrior = {
  WARLOCK = { _ = 68, Affliction = 68, Demonology = 62, Destruction = 72 },
  PRIEST = { _ = 50, Shadow = 62, Discipline = 35, Holy = 48 },
  MAGE = { _ = 50, Frost = 45, Fire = 60, Arcane = 55 },
  HUNTER = { _ = 55, ["Beast Mastery"] = 55, Marksmanship = 55, Survival = 55 },
  SHAMAN = { _ = 52, Elemental = 60, Enhancement = 55, Restoration = 45 },
  DRUID = { _ = 42, Balance = 60, ["Feral Combat"] = 40, Restoration = 35 },
  WARRIOR = { _ = 55, Arms = 55, Fury = 60, Protection = 20 },
  ROGUE = { _ = 48, Assassination = 50, Combat = 50, Subtlety = 45 },
  DEATHKNIGHT = { _ = 45, Blood = 35, Frost = 50, Unholy = 45 },
  PALADIN = { _ = 30, Holy = 25, Protection = 15, Retribution = 40 },
}

--[[
  Comp plan cards (3.10): a short reminder shown once the enemy team is known. Key = the
  enemy classes sorted and joined with "+". General WotLK knowledge, not orders.
]]
ArenaFrames_CompPlans = {
  ["MAGE+PRIEST+ROGUE"] = "RMP: expect Sap/Poly on your healer at the opener. Stay near pillars, trinket the chain that kills, not the first CC.",
  ["MAGE+ROGUE+SHAMAN"] = "RMS: Grounding Totem eats your CC/SWD - kill or wait it out. Burst comes with Shadow Dance/Icy Veins.",
  ["DRUID+ROGUE+WARRIOR"] = "Cleave + druid: lots of physical damage. Keep the warrior slowed, Cyclone on your DPS during their go.",
  ["PALADIN+WARLOCK+WARRIOR"] = "Shadow cleave/paladin: fears everywhere. Fear Ward/Tremor, kill the lock or force bubble early.",
  ["DEATHKNIGHT+DRUID+WARLOCK"] = "Lock/DK + druid: fears, grips and Cyclone. Dispel UA carefully (its backlash silences you). Pressure the lock.",
  ["HUNTER+PRIEST+ROGUE"] = "Hunter/rogue/priest: watch Scatter + Wyvern on your healer. Kill the hunter if he stays in range.",
  ["MAGE+PRIEST+WARLOCK"] = "Caster cleave: Poly + Fear + Seduction. Line of sight is everything. Interrupt the lock's fears.",
  ["HUNTER+PALADIN+WARRIOR"] = "Physical cleave: high damage, few CCs. Peel the warrior, kite, use defensives early.",
  ["DRUID+SHAMAN+WARRIOR"] = "Wild/warrior-shaman-druid: Heroism burst. Purge HoTs, CC the shaman before they go.",
  ["MAGE+ROGUE"] = "2v2 mage/rogue: openers decide. Don't stand in the open; trinket the CC that would get you killed.",
  ["PRIEST+WARRIOR"] = "2v2 warrior/disc: CC the priest when the warrior goes, kill the warrior with Pain Supp down.",
  ["DRUID+ROGUE"] = "2v2 rogue/druid: Cyclone + Kidney chains. Interrupt Cyclone, keep the druid from drinking.",
  ["PALADIN+WARRIOR"] = "2v2 warrior/paladin: very tanky. Kill the warrior in a CC window on the paladin, after bubble.",
  ["DEATHKNIGHT+PALADIN"] = "2v2 DK/paladin: grips and Strangulate on healers. Keep distance from the DK.",
  ["PRIEST+ROGUE"] = "2v2 rogue/disc: Sap opener on you. Fear/SWD timing matters, kill the rogue when Cloak is down.",
  ["MAGE+PRIEST"] = "2v2 mage/disc: Poly + Fear chains. Kill the mage after Ice Block, LoS his Polys.",
  ["PRIEST+WARLOCK"] = "2v2 lock/priest: dots + fears. Dispel the right things, keep Fear Ward, pressure the lock.",
}

-- written by tools/arena.py from the armory, the SoloQ ladder and your combat logs (keep the markers)
-- BEGIN GENERATED ArenaFrames_Data
-- END GENERATED ArenaFrames_Data
