#!/usr/bin/env python3
"""
Arena data for ArenaFrames' kill target (3.10): your combat logs + the Warmane armory.

  python3 tools/arena.py update     parse the combat log, look up the players in it (and the SoloQ
                                    ladder) on the armory, write ArenaFrames_Data into DRList.lua
  python3 tools/arena.py report     what happened in each arena match of the log
  python3 tools/arena.py update --no-armory   only the log part (no network)

Then /reload in game. Logs come from /combatlog (ArenaFrames switches it on in arena).
Only the Python standard library is used (macOS python3 3.9 is enough).

Warmane's armory allows about one request per 4 s: lookups are cached in tools/cache/ and only
refreshed after a week, so the first run is the slow one. Item levels / resilience come from
wotlk.cavernoftime.com (the item database Warmane's own tooltips use), cached forever.
"""
import argparse
import csv
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from collections import defaultdict
from datetime import datetime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DRLIST = os.path.join(ROOT, "ArenaFrames", "DRList.lua")
CACHE = os.path.join(ROOT, "tools", "cache")
DEFAULT_LOG = os.path.expanduser("~/Downloads/World of Warcraft 3.3.5a/Logs/WoWCombatLog.txt")
REALMS = ["Icecrown", "Lordaeron", "Onyxia", "Blackrock"]
# the owner's characters -> realm. Arenas are cross-realm, so this only decides which realm is tried
# first for opponents without "-Realm" in the log; the others are tried too and the class seen in the
# log decides between two level 80s with the same name.
OWN_REALMS = {}          # your characters, e.g. {"Mychar": "Blackrock", "Myalt": "Icecrown"}
ARMORY = "https://armory.warmane.com"
ARMORY_DELAY, ITEM_DELAY, REFRESH_DAYS = 4.5, 1.0, 7
MATCH_GAP = 40          # seconds without enemy players = the match is over
UA = "Mozilla/5.0 (ArenaFrames data tool; personal use)"

MINE, FRIENDLY, HOSTILE, PLAYER = 0x1, 0x10, 0x40, 0x400
GROUP = 0x1 | 0x2 | 0x4          # affiliation mine / party / raid: your arena team
CLASS_TOKENS = {"Death Knight": "DEATHKNIGHT", "Druid": "DRUID", "Hunter": "HUNTER", "Mage": "MAGE",
                "Paladin": "PALADIN", "Priest": "PRIEST", "Rogue": "ROGUE", "Shaman": "SHAMAN",
                "Warlock": "WARLOCK", "Warrior": "WARRIOR"}
HEALERS = {("PRIEST", "Discipline"), ("PRIEST", "Holy"), ("PALADIN", "Holy"), ("SHAMAN", "Restoration"),
           ("DRUID", "Restoration")}


# ------------------------------------------------------------------ DRList.lua tables --

def lua_entries(text, table):
    """The { class = ..., ids = { ... } ... } entries of one table in DRList.lua."""
    start = text.index(table + " = {")
    depth, i = 0, text.index("{", start)
    for j in range(i, len(text)):
        if text[j] == "{":
            depth += 1
        elif text[j] == "}":
            depth -= 1
            if depth == 0:
                body = text[i + 1:j]
                break
    out = []
    for m in re.finditer(r"\{\s*class\s*=\s*\"(\w+)\"(.*?)\}\s*,?\s*(?=\{\s*class|\Z|--)", body, re.S):
        rest = m.group(2)
        e = {"class": m.group(1)}
        for key in ("spec", "name", "race"):
            k = re.search(key + r'\s*=\s*"([^"]*)"', rest)
            if k:
                e[key] = k.group(1)
        w = re.search(r"weight\s*=\s*(\d+)", rest)
        e["weight"] = int(w.group(1)) if w else 0
        ids = re.search(r"ids\s*=\s*\{([^}]*)\}", rest)
        e["ids"] = [int(x) for x in re.findall(r"\d+", ids.group(1))] if ids else []
        out.append(e)
    return out


def load_tables():
    with open(DRLIST, encoding="utf-8") as fh:
        text = fh.read()
    specs = lua_entries(text, "ArenaFrames_Specs")
    cds = lua_entries(text, "ArenaFrames_Cooldowns")
    class_by_id, class_by_name = {}, {}
    for e in specs + cds:
        if e["class"] == "ANY":
            continue
        for i in e["ids"]:
            class_by_id[i] = e["class"]
        if e.get("name"):
            class_by_name.setdefault(e["name"], set()).add(e["class"])
    spec_by_id, spec_by_name = defaultdict(list), defaultdict(list)
    for e in specs:
        for i in e["ids"]:
            spec_by_id[i].append(e)
        spec_by_name[e["name"]].append(e)
    return {"class_by_id": class_by_id, "class_by_name": class_by_name, "spec_by_id": spec_by_id,
            "spec_by_name": spec_by_name, "cooldown_names": {e["name"] for e in cds}}


# --------------------------------------------------------------------------- the log --

def parse_line(line, year):
    # 3.3.5: "10/20 21:15:03.123  SPELL_DAMAGE,0x...,"Name",0x511,0x...,"Mob",0xa48,48666,"Mutilate",0x1,..."
    m = re.match(r"(\d+)/(\d+) (\d+):(\d+):(\d+)\.(\d+)  (.*)", line)
    if not m:
        return None
    mo, d, h, mi, s, ms, rest = m.groups()
    try:
        t = datetime(year, int(mo), int(d), int(h), int(mi), int(s)).timestamp() + int(ms) / 1000
    except ValueError:
        return None
    f = next(csv.reader([rest]))
    if len(f) < 7:
        return None

    def flags(x):
        try:
            return int(x, 16)
        except ValueError:
            return 0
    ev = {"t": t, "sub": f[0], "src": f[1], "srcName": None if f[2] == "nil" else f[2], "srcFlags": flags(f[3]),
          "dst": f[4], "dstName": None if f[5] == "nil" else f[5], "dstFlags": flags(f[6]), "extra": f[7:]}
    if ev["sub"].startswith(("SPELL_", "RANGE_")) and len(f) > 8:
        try:
            ev["spellId"] = int(f[7])
        except ValueError:
            ev["spellId"] = None
        ev["spell"] = f[8]
    if ev["sub"].endswith("_DAMAGE"):
        idx = 7 if ev["sub"] == "SWING_DAMAGE" else 10
        try:
            ev["amount"] = int(f[idx])
        except (ValueError, IndexError):
            ev["amount"] = 0
    return ev


def is_player(flags):
    return flags & PLAYER != 0


def read_log(path):
    year = datetime.now().year
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            ev = parse_line(line.rstrip("\n"), year)
            if ev:
                yield ev


def split_matches(events):
    """Arena-like fights: events with enemy players, split where none were seen for MATCH_GAP s."""
    cur, last_hostile = None, None
    for ev in events:
        hostile = (is_player(ev["srcFlags"]) and ev["srcFlags"] & HOSTILE) or \
                  (is_player(ev["dstFlags"]) and ev["dstFlags"] & HOSTILE)
        if hostile:
            if cur is None or ev["t"] - last_hostile > MATCH_GAP:
                if cur:
                    yield cur
                cur = []
            last_hostile = ev["t"]
        if cur is not None:
            if last_hostile is not None and ev["t"] - last_hostile > MATCH_GAP:
                yield cur
                cur = None
                continue
            cur.append(ev)
    if cur:
        yield cur


def short(name):
    return name.split("-")[0] if name else name


def analyze_match(evs, T):
    players = {}       # guid -> info

    def p(guid, name, flags):
        if guid not in players:
            players[guid] = {"guid": guid, "name": name, "hostile": False, "friendly": False, "me": False,
                             "group": False,
                             "classVotes": defaultdict(int), "specSeen": {}, "dmgTaken": 0, "died": None,
                             "cds": []}
        x = players[guid]
        # a stealthed enemy is flagged neutral (0x528) until he's revealed: any hostile line counts
        # teammates = your party / raid (strangers around you in a city are "friendly" too, and after a
        # cross-faction arena a teammate can show up hostile once he's back outside)
        x["group"] = x["group"] or bool(flags & GROUP)
        x["hostile"] = x["hostile"] or bool(flags & HOSTILE and not flags & GROUP)
        x["friendly"] = x["friendly"] or bool(flags & FRIENDLY)
        x["me"] = x["me"] or bool(flags & MINE)
        return x

    for ev in evs:
        if is_player(ev["srcFlags"]) and ev["srcName"]:
            src = p(ev["src"], ev["srcName"], ev["srcFlags"])
            sid, sname = ev.get("spellId"), ev.get("spell")
            if sid:
                c = T["class_by_id"].get(sid)
                if c:
                    src["classVotes"][c] += 2
                for c in T["class_by_name"].get(sname, ()):
                    src["classVotes"][c] += 1
                for e in T["spec_by_id"].get(sid, []) + T["spec_by_name"].get(sname, []):
                    src["specSeen"][id(e)] = e
                if ev["sub"] == "SPELL_CAST_SUCCESS" and sname in T["cooldown_names"]:
                    src["cds"].append((ev["t"], sname))
        if is_player(ev["dstFlags"]) and ev["dstName"]:
            dst = p(ev["dst"], ev["dstName"], ev["dstFlags"])
            if ev["sub"].endswith("_DAMAGE"):
                dst["dmgTaken"] += ev.get("amount", 0)
                dst.setdefault("lastHits", []).append((ev["t"], ev.get("spell") or "melee", ev["srcName"],
                                                       ev.get("amount", 0)))
                dst["lastHits"] = dst["lastHits"][-6:]
            if ev["sub"] == "UNIT_DIED" and dst["died"] is None:
                dst["died"] = ev["t"]

    for x in players.values():
        x["class"] = max(x["classVotes"], key=x["classVotes"].get) if x["classVotes"] else None
        score = defaultdict(int)
        for e in x["specSeen"].values():
            if e["class"] == x["class"]:
                score[e["spec"]] += e["weight"]
        x["spec"] = max(score, key=score.get) if score else None
        if x["spec"] and score[x["spec"]] < 2:
            x["spec"] = None

    enemies = [x for x in players.values() if x["hostile"] and not x["group"]]
    team = [x for x in players.values() if x["group"]]
    if not enemies or len(enemies) > 5 or len(team) > 5 or not team:
        return None                     # not your fight (world PvP around you), or a battleground
    start, end = evs[0]["t"], evs[-1]["t"]
    if end - start < 20:
        return None
    dead_e = sorted([x for x in enemies if x["died"]], key=lambda x: x["died"])
    dead_t = [x for x in team if x["died"]]
    size = max(len(enemies), len(team))
    result = "win" if len(dead_e) >= len(enemies) and dead_e else "loss" if team and len(dead_t) >= len(team) else "?"
    me = next((x for x in team if x["me"]), None)
    return {"start": start, "end": end, "size": size, "enemies": enemies, "team": team, "result": result,
            "me": short(me["name"]) if me else None,
            "firstDeath": dead_e[0] if dead_e else None,
            "teamFirstDeath": min(dead_t, key=lambda x: x["died"]) if dead_t else None}


def matches_from_log(path):
    T = load_tables()
    out = []
    for evs in split_matches(read_log(path)):
        m = analyze_match(evs, T)
        if m:
            out.append(m)
    return out


# ------------------------------------------------------------------------ the armory --

_last = {"armory": 0.0, "item": 0.0}


def fetch(url, kind, post=None):
    wait = (ARMORY_DELAY if kind == "armory" else ITEM_DELAY) - (time.time() - _last[kind])
    if wait > 0:
        time.sleep(wait)
    _last[kind] = time.time()
    data = urllib.parse.urlencode(post).encode() if post else None
    req = urllib.request.Request(url, data=data, headers={"User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as e:
        if e.code == 429:
            time.sleep(30)
        return None
    except (urllib.error.URLError, TimeoutError, OSError):
        return None


def cache_get(path, max_days=None):
    try:
        with open(path, encoding="utf-8") as fh:
            d = json.load(fh)
    except (OSError, ValueError):
        return None
    if max_days is not None and time.time() - d.get("_fetched", 0) > max_days * 86400:
        return None
    return d


def cache_put(path, d):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    d["_fetched"] = time.time()
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(d, fh)


def ladder():
    """SoloQ top 50 (all realms): name, realm, class, race, rating, wins, losses."""
    path = os.path.join(CACHE, "ladder_soloq.json")
    d = cache_get(path, max_days=1)
    if d:
        return d["rows"]
    html = fetch(ARMORY + "/ladder/SoloQ/Icecrown/80", "armory")
    rows = []
    for tr in re.findall(r"<tr>(.*?)</tr>", html or "", re.S):
        name = re.search(r'/character/([^/]+)/([^/]+)/summary">', tr)
        cells = re.findall(r'<td class="dt-center">([^<]*)</td>', tr)
        alts = re.findall(r'alt="([^"]+)"', tr)
        if name and len(cells) >= 5 and len(alts) >= 2:
            rows.append({"name": urllib.parse.unquote(name.group(1)), "realm": name.group(2),
                         "class": CLASS_TOKENS.get(alts[0]), "race": alts[1], "rating": int(cells[-1]),
                         "wins": int(cells[-3]), "losses": int(cells[-2])})
    if rows:
        cache_put(path, {"rows": rows})
    return rows


def character(name, realm=None, cls=None):
    """Armory summary: the given realm first, then the others; with a class, the one of that class."""
    fallback = None
    for r in ([realm] if realm else []) + [x for x in REALMS if x != realm]:
        path = os.path.join(CACHE, "armory", "%s_%s.json" % (r, name))
        d = cache_get(path, max_days=REFRESH_DAYS)
        if d is None:
            body = fetch("%s/api/character/%s/%s/summary" % (ARMORY, urllib.parse.quote(name), r), "armory")
            if body is None:
                return fallback                 # network trouble: try again next run
            try:
                d = json.loads(body)
            except ValueError:
                return fallback
            if d.get("error") or str(d.get("level")) != "80":
                d = {"missing": True}
            cache_put(path, d)
        if d.get("missing"):
            continue
        if not cls or CLASS_TOKENS.get(d.get("class")) == cls:
            return d
        fallback = fallback or d                # same name, other class: keep looking
    return None if cls else fallback


# ------------------------------------------------------------------- match history --
# Every character's armory page has /match-history (all arena games: outcome, rating, time, map) and
# each game's details (POST matchinfo=<id>): every player's class, realm, damage, healing, deaths,
# MMR and rating change. Solo Queue games are listed as "Solo Queue (5v5)".

CLASS_IDS = {"1": "WARRIOR", "2": "PALADIN", "3": "HUNTER", "4": "ROGUE", "5": "PRIEST", "6": "DEATHKNIGHT",
             "7": "SHAMAN", "8": "MAGE", "9": "WARLOCK", "11": "DRUID"}
OWN_MAX_GAMES = 400      # your own games looked at in detail (newest first), per character
RECENT_GAMES = 8         # an opponent's latest games of a bracket looked at in detail
BRACKETS = {"soloq": "", "2v2": "2"}     # bracket -> suffix of its fields in ArenaFrames_Data (SoloQ = none)


def bracket_of(tr):
    """ "soloq", "2v2", "3v3", "5v5" or None from a match-history row (Solo Queue rows also say (5v5))."""
    if "Solo Queue" in tr:
        return "soloq"
    m = re.search(r"\((\dv\d)\)", tr)
    return m.group(1) if m else None


def history(name, realm, max_days):
    """[{id, soloq, bracket, win, rating, change, t, duration, map}] newest first."""
    path = os.path.join(CACHE, "history", "%s_%s.json" % (realm, name))
    d = cache_get(path, max_days=max_days)
    if d is not None and all("bracket" in r for r in d["rows"]):     # older caches have no bracket
        return d["rows"]
    html = fetch("%s/character/%s/%s/match-history" % (ARMORY, urllib.parse.quote(name), realm), "armory")
    if html is None:
        return []
    rows = []
    body = html.split('id="data-table-history"', 1)[-1]
    for tr in re.findall(r"<tr>(.*?)</tr>", body, re.S):
        gid = re.search(r'data-gameid="(\d+)"', tr)
        t = re.search(r'data-order="(\d+)"', tr)
        if not (gid and t):
            continue
        cells = re.findall(r"<td[^>]*>(.*?)</td>", tr, re.S)
        rating = re.search(r"(\d+) \(<span class=\"history-\w+\">([+-]?\d+)", tr)
        rows.append({"id": gid.group(1), "soloq": "Solo Queue" in tr, "bracket": bracket_of(tr), "win": "Victory" in tr,
                     "rating": int(rating.group(1)) if rating else None,
                     "change": int(rating.group(2)) if rating else None, "t": int(t.group(1)),
                     "map": re.sub("<[^>]+>", "", cells[-2]).strip() if len(cells) >= 2 else None})
    rows.sort(key=lambda r: -r["t"])
    cache_put(path, {"rows": rows})
    return rows


def details(gid, name, realm):
    """The players of one game: [{name, realm, class, win, deaths, damage, healing, mmr}] (cached forever)."""
    path = os.path.join(CACHE, "matches", "%s.json" % gid)
    d = cache_get(path)
    if d is not None:
        return d["players"]
    body = fetch("%s/character/%s/%s/match-history" % (ARMORY, urllib.parse.quote(name), realm), "armory",
                 post={"matchinfo": gid})
    try:
        raw = json.loads(body) if body else None
    except ValueError:
        raw = None
    if not raw:
        return None
    out = []
    for v in raw:
        mmr = re.match(r"(\d+)", str(v.get("matchmaking_change", "")))
        out.append({"name": v.get("charname"), "realm": v.get("realm"), "class": CLASS_IDS.get(str(v.get("class"))),
                    "win": "history-win" in str(v.get("personal_change", "")),
                    "deaths": int(v.get("deaths") or 0), "damage": int(v.get("damageDone") or 0),
                    "healing": int(v.get("healingDone") or 0), "mmr": int(mmr.group(1)) if mmr else None})
    cache_put(path, {"players": out})
    return out


def own_history(progress=print, bracket="soloq"):
    """Your games of one bracket on all your characters: (games, per-class stats, per-player stats, avg death rate)."""
    games, classes, opp = [], defaultdict(lambda: {"games": 0, "deaths": 0}), {}
    for me, realm in OWN_REALMS.items():
        rows = [r for r in history(me, realm, max_days=0.02) if r["bracket"] == bracket][:OWN_MAX_GAMES]
        new = sum(1 for r in rows if not os.path.exists(os.path.join(CACHE, "matches", "%s.json" % r["id"])))
        progress("%s: %d %s games (%d new to look up, ~%d s)" % (me, len(rows), bracket, new, new * ARMORY_DELAY))
        for r in rows:
            ps = details(r["id"], me, realm)
            if not ps:
                continue
            mine = next((x for x in ps if x["name"] == me), None)
            if not mine:
                continue
            enemies = [x for x in ps if x["win"] != mine["win"]]
            games.append({"id": r["id"], "t": r["t"], "me": me, "win": mine["win"], "mmr": mine["mmr"],
                          "enemies": enemies})
            for e in enemies:
                if not e["class"]:
                    continue
                c = classes[e["class"]]
                c["games"] += 1
                c["deaths"] += 1 if e["deaths"] > 0 else 0
                o = opp.setdefault(e["name"], {"met": 0, "died": 0, "w": 0, "class": e["class"], "realm": e["realm"]})
                o["met"] += 1
                o["died"] += 1 if e["deaths"] > 0 else 0
                o["w"] += 1 if mine["win"] else 0
    total = sum(c["games"] for c in classes.values())
    avg = sum(c["deaths"] for c in classes.values()) / total if total else None
    return games, classes, opp, avg


def recent_form(name, realm, bracket="soloq"):
    """An opponent's latest games of a bracket: (games, win %, death %, latest MMR)."""
    rows = [r for r in history(name, realm, max_days=REFRESH_DAYS) if r["bracket"] == bracket]
    if not rows:
        return None
    wins = sum(1 for r in rows[:30] if r["win"])
    n, died, mmr = 0, 0, None
    for r in rows[:RECENT_GAMES]:
        ps = details(r["id"], name, realm)
        me = ps and next((x for x in ps if x["name"] == name), None)
        if not me:
            continue
        n += 1
        died += 1 if me["deaths"] > 0 else 0
        mmr = mmr or me["mmr"]
    return {"hgames": n, "hdeaths": round(100 * died / n) if n else None, "wr": round(100 * wins / min(len(rows), 30)),
            "mmr": mmr}


ITEMS = None


def item_info(item_id):
    """(item level, resilience) of an item, from cavernoftime's WotLK database."""
    global ITEMS
    path = os.path.join(CACHE, "items.json")
    if ITEMS is None:
        ITEMS = cache_get(path) or {}
    key = str(item_id)
    if key not in ITEMS:
        html = fetch("https://wotlk.cavernoftime.com/item=%s" % key, "item")
        if html is None:
            return None, None
        il = re.search(r"Item Level (\d+)", html)
        res = re.search(r"resilience rating by (\d+)", html)
        ITEMS[key] = [int(il.group(1)) if il else None, int(res.group(1)) if res else 0]
        cache_put(path, ITEMS)
    v = ITEMS[key]
    return v[0], v[1]


def gear(summary):
    """Average item level (main slots) and total resilience of an armory summary."""
    levels, resil = [], 0
    for it in summary.get("equipment", []):
        name = it.get("name") or ""
        if "Tabard" in name or "Shirt" in name:
            continue
        il, rs = item_info(it.get("item"))
        if il and il >= 100:
            levels.append(il)
        resil += rs or 0
    if len(levels) < 10:                  # armory shows (almost) nothing: gear unknown
        return None, None
    return round(sum(levels) / len(levels)), resil


def armory_spec(summary):
    t = (summary.get("talents") or [{}])[0]      # first talent group (dual spec: may be the other one)
    return t.get("tree")


# --------------------------------------------------------------------------- export --

def lua_str(s):
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"') + '"'


def export(players, specs, classes=None, avg=None, specs2=None, classes2=None, avg2=None):
    lines = ["ArenaFrames_Data = {", "  generated = %s," % lua_str(datetime.now().strftime("%Y-%m-%d %H:%M")),
             "  players = {"]
    for name in sorted(players):
        p = players[name]
        fields = ", ".join("%s = %s" % (k, lua_str(v) if isinstance(v, str) else v)
                           for k, v in sorted(p.items()) if v is not None)
        lines.append("    [%s] = { %s }," % (lua_str(name), fields))
    lines.append("  },")
    for sfx, sp, cl, av in (("", specs, classes, avg), ("2", specs2, classes2, avg2)):
        if sfx and not (sp or cl):
            continue
        lines.append("  specs%s = {" % sfx)
        for key in sorted(sp or {}):
            s = sp[key]
            lines.append("    [%s] = { seen = %d, firstDeath = %d, winWhenFirst = %d }," %
                         (lua_str(key), s["seen"], s["firstDeath"], s["winWhenFirst"]))
        lines.append("  },")
        lines.append("  classes%s = {" % sfx)
        for c in sorted(cl or {}):
            lines.append("    %s = { games = %d, deaths = %d }," % (c, cl[c]["games"], cl[c]["deaths"]))
        lines.append("  },")
        if av is not None:
            lines.append("  avgDeath%s = %d," % (sfx, round(100 * av)))
    lines.append("}")
    block = "\n".join(lines)
    with open(DRLIST, encoding="utf-8") as fh:
        text = fh.read()
    begin, end = "-- BEGIN GENERATED ArenaFrames_Data\n", "-- END GENERATED ArenaFrames_Data"
    a, b = text.index(begin) + len(begin), text.index(end)
    with open(DRLIST, "w", encoding="utf-8") as fh:
        fh.write(text[:a] + block + "\n" + text[b:])


# ------------------------------------------------------------------------- commands --

def resolve_results(matches, games):
    """A log match without a clear end ("?": the log stopped first) gets its result from your Warmane
    history: the game of the same character that started within 3 minutes of it."""
    for m in matches:
        if m["result"] != "?" or not m.get("me"):
            continue
        g = min((g for g in games if g["me"] == m["me"] and abs(g["t"] - m["start"]) < 180),
                key=lambda g: abs(g["t"] - m["start"]), default=None)
        if g:
            m["result"] = "win" if g["win"] else "loss"


def cmd_update(args):
    matches = matches_from_log(args.log) if os.path.exists(args.log) else []
    if not os.path.exists(args.log):
        print("no combat log at %s yet (type /combatlog in game, or let ArenaFrames do it in arena)" % args.log)
    print("arena matches in the log: %d" % len(matches))
    # 3.17: SoloQ and 2v2 kept apart (owner: "in 2v2 pull the 2v2 brackets, for SoloQ take SoloQ")
    hist = {b: ([], {}, {}, None) for b in BRACKETS}
    if not args.no_armory:
        print("your Warmane match history:")
        for b in BRACKETS:
            hist[b] = own_history(bracket=b)
            g, _, _, a = hist[b]
            print("  %d %s games with details, enemy death rate %s" % (len(g), b, "%d%%" % (100 * a) if a else "?"))
        resolve_results(matches, [g for b in BRACKETS for g in hist[b][0]])

    specs = {sfx: defaultdict(lambda: {"seen": 0, "firstDeath": 0, "winWhenFirst": 0}) for sfx in BRACKETS.values()}
    players = {}
    for m in matches:
        first = m["firstDeath"]
        home = OWN_REALMS.get(m["me"]) or args.realm
        sfx = BRACKETS["2v2"] if m["size"] == 2 else BRACKETS["soloq"]     # 3v3 / 5v5: closest to SoloQ
        for e in m["enemies"]:
            name = short(e["name"])
            p = players.setdefault(name, {})
            for k in ("met", "firstDeath", "w", "l"):
                p.setdefault(k + sfx, 0)
            p["_realm"] = e["name"].split("-")[1] if "-" in e["name"] else home
            p.setdefault("_brackets", set()).add("2v2" if sfx else "soloq")
            if first:
                p["met" + sfx] += 1
            p["class"] = e["class"] or p.get("class")
            p["spec"] = e["spec"] or p.get("spec")
            if first is e:
                p["firstDeath" + sfx] += 1
            if m["result"] == "win":
                p["w" + sfx] += 1
            elif m["result"] == "loss":
                p["l" + sfx] += 1
            if e["class"] and e["spec"] and first:     # no enemy died: says nothing about who dies first
                s = specs[sfx]["%s:%s" % (e["class"], e["spec"])]
                s["seen"] += 1
                if first is e:
                    s["firstDeath"] += 1
                    if m["result"] == "win":
                        s["winWhenFirst"] += 1

    if not args.no_armory:
        for b, sfx in BRACKETS.items():
            for name, o in hist[b][2].items():
                p = players.setdefault(name, {})
                p["vsMet" + sfx], p["vsDied" + sfx], p["vsW" + sfx] = o["met"], o["died"], o["w"]
                p["class"] = p.get("class") or o["class"]
                p["_realm"] = p.get("_realm") or o["realm"]
        logged = {short(e["name"]) for m in matches for e in m["enemies"]}
        for name in sorted(logged):
            p = players[name]
            for b in sorted(p.get("_brackets", ())):         # the form of the bracket(s) you met him in
                form = recent_form(name, p.get("_realm") or args.realm or "Icecrown", b)
                if form:
                    p.update({k + BRACKETS[b]: v for k, v in form.items()})
        rows = ladder()
        print("SoloQ ladder: %d players" % len(rows))
        for r in rows:
            p = players.setdefault(r["name"], {})
            p["rating"], p["class"] = r["rating"], p.get("class") or r["class"]
            p["_realm"] = r["realm"]
        # gear only for players you met in your logs and the ladder (your whole history would take hours)
        todo = sorted(n for n, p in players.items() if p.get("met") is not None or p.get("met2") is not None
                      or p.get("rating") is not None or n in logged)
        print("armory lookups: %d players (cached ones are instant, new ones ~5 s each)" % len(todo))
        for i, name in enumerate(todo, 1):
            p = players[name]
            summary = character(name, p.pop("_realm", None) or args.realm, p.get("class"))
            if not summary:
                continue
            p["class"] = p.get("class") or CLASS_TOKENS.get(summary.get("class"))
            p["spec"] = p.get("spec") or armory_spec(summary)
            p["ilvl"], p["resil"] = gear(summary)   # resil = items only (no gems / enchants)
            if i % 10 == 0:
                print("  %d/%d" % (i, len(todo)))
    for name in list(players):
        players[name].pop("_realm", None)
        players[name].pop("_brackets", None)
        if name in OWN_REALMS:
            del players[name]
    export(players, specs[""], hist["soloq"][1], hist["soloq"][3], specs["2"], hist["2v2"][1], hist["2v2"][3])
    print("wrote ArenaFrames_Data (%d players, %d SoloQ + %d 2v2 specs) into %s - /reload in game" %
          (len(players), len(specs[""]), len(specs["2"]), os.path.relpath(DRLIST, ROOT)))


def fmt_player(x):
    return "%s (%s%s)" % (short(x["name"]), (x["spec"] + " ") if x["spec"] else "", x["class"] or "?")


def cmd_report(args):
    if not os.path.exists(args.log):
        print("no combat log at %s" % args.log)
        return
    matches = matches_from_log(args.log)
    if not args.no_armory:
        resolve_results(matches, [g for b in BRACKETS for g in own_history(progress=lambda *a: None, bracket=b)[0]])
    wins = sum(1 for m in matches if m["result"] == "win")
    losses = sum(1 for m in matches if m["result"] == "loss")
    print("%d arena-like fights: %d won, %d lost, %d unclear" % (len(matches), wins, losses,
                                                                 len(matches) - wins - losses))
    for m in matches[-args.last:]:
        print()
        print("%s  %dv%d  %s  %ds" % (datetime.fromtimestamp(m["start"]).strftime("%m/%d %H:%M"), m["size"],
                                      m["size"], m["result"].upper(), m["end"] - m["start"]))
        print("  you + team: " + ", ".join(fmt_player(x) for x in m["team"]))
        print("  enemies:    " + ", ".join(fmt_player(x) for x in m["enemies"]))
        if m["firstDeath"]:
            print("  first enemy death: %s at %ds" % (fmt_player(m["firstDeath"]), m["firstDeath"]["died"] - m["start"]))
        t = m["teamFirstDeath"]
        if t:
            hits = ", ".join("%s %s %d" % (h[2] or "?", h[1], h[3]) for h in t.get("lastHits", []))
            print("  first death on your side: %s at %ds - last hits: %s" % (fmt_player(t), t["died"] - m["start"], hits))
        for x in m["enemies"]:
            if x["cds"]:
                print("  %s used: %s" % (short(x["name"]), ", ".join("%s@%ds" % (n, t0 - m["start"]) for t0, n in x["cds"])))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("command", choices=["update", "report"])
    ap.add_argument("--log", default=DEFAULT_LOG, help="WoWCombatLog.txt (default: %(default)s)")
    ap.add_argument("--realm", default=None, help="your realm, tried first for names without -Realm")
    ap.add_argument("--no-armory", action="store_true", help="skip the armory / ladder (no network)")
    ap.add_argument("--last", type=int, default=10, help="report: how many matches")
    args = ap.parse_args()
    {"update": cmd_update, "report": cmd_report}[args.command](args)


if __name__ == "__main__":
    main()
