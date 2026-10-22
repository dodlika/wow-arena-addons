"""tools/arena.py on a fake 3.3.5 combat log (no network). Run: python3 tests/test_arena_tool.py"""
import os
import shutil
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import arena  # noqa: E402

LOG = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fixtures", "combatlog_2v2.txt")


class Args:
    log, realm, no_armory, last = LOG, None, True, 10


class ArenaTool(unittest.TestCase):
    def test_matches(self):
        m = arena.matches_from_log(LOG)
        self.assertEqual(len(m), 3, "split at the 40 s gap without enemies")
        first, second, third = m
        # regression (first real log): a stealthed rogue is flagged neutral (0x528) at first
        self.assertEqual(sorted(arena.short(x["name"]) for x in third["enemies"]), ["Healz", "Sneaky"])
        self.assertEqual(first["result"], "win")
        self.assertEqual(second["result"], "loss")
        enemies = {arena.short(x["name"]): x for x in first["enemies"]}
        self.assertEqual(enemies["Lockz"]["class"], "WARLOCK")
        self.assertEqual(enemies["Lockz"]["spec"], "Affliction")       # Haunt + UA
        self.assertEqual(enemies["Bubble"]["spec"], "Holy")            # Holy Shock + Beacon
        self.assertEqual(arena.short(first["firstDeath"]["name"]), "Lockz")
        self.assertEqual(arena.short(second["teamFirstDeath"]["name"]), "Me")
        self.assertIn("Divine Shield", [n for _, n in enemies["Bubble"]["cds"]])
        self.assertEqual(first["me"], "Me")

    def test_export(self):
        tmp = tempfile.mkdtemp()
        try:
            dst = os.path.join(tmp, "DRList.lua")
            shutil.copy(arena.DRLIST, dst)
            old = arena.DRLIST
            arena.DRLIST = dst
            try:
                arena.cmd_update(Args())
            finally:
                arena.DRLIST = old
            with open(dst) as fh:
                text = fh.read()
            # a 2v2 log: the numbers go to the 2v2 fields (3.17)
            self.assertIn('["Lockz"] = { class = "WARLOCK", firstDeath2 = 1, l2 = 1, met2 = 1, spec = "Affliction", w2 = 1 }',
                          text)
            self.assertIn('["WARLOCK:Affliction"] = { seen = 1, firstDeath = 1, winWhenFirst = 1 }',
                          text.split("specs2 = {", 1)[1], "in specs2")
            # the loss had no enemy death: it doesn't count for "who dies first"
            self.assertIn("ArenaFrames_KillPrior", text, "the rest of DRList.lua is kept")
            self.assertEqual(text.count("BEGIN GENERATED"), 1)
        finally:
            shutil.rmtree(tmp)


class Armory(unittest.TestCase):
    """Cross-realm arenas: the same name on two realms, the class seen in the log decides."""
    def test_class_decides(self):
        import json
        tmp = tempfile.mkdtemp()
        pages = {"Icecrown": {"level": "80", "class": "Paladin", "name": "Twin"},
                 "Lordaeron": {"error": "Character does not exist."},
                 "Onyxia": {"level": "1", "class": "Rogue", "name": "Twin"},
                 "Blackrock": {"level": "80", "class": "Rogue", "name": "Twin"}}
        calls = []

        def fake_fetch(url, kind):
            realm = url.split("/")[-2]
            calls.append(realm)
            return json.dumps(pages[realm])
        old_fetch, old_cache = arena.fetch, arena.CACHE
        arena.fetch, arena.CACHE = fake_fetch, tmp
        try:
            self.assertEqual(arena.character("Twin", "Icecrown", "ROGUE")["class"], "Rogue")
            self.assertEqual(calls, ["Icecrown", "Lordaeron", "Onyxia", "Blackrock"])
            self.assertEqual(arena.character("Twin", "Icecrown", "PALADIN")["class"], "Paladin")
            self.assertEqual(len(calls), 4, "second lookup comes from the cache")
            self.assertIsNone(arena.character("Twin", "Icecrown", "MAGE"), "no level 80 mage of that name")
        finally:
            arena.fetch, arena.CACHE = old_fetch, old_cache
            shutil.rmtree(tmp)


class WarmaneHistory(unittest.TestCase):
    """/match-history list + per-game details (POST matchinfo)."""
    def test_history_and_details(self):
        import json
        tmp = tempfile.mkdtemp()
        with open(os.path.join(os.path.dirname(LOG), "match_history.html")) as fh:
            page = fh.read()
        game = [
            {"charname": "Azaret", "realm": "Icecrown", "class": "4", "deaths": "0", "damageDone": "95817",
             "healingDone": "0", "matchmaking_change": '1446 (<span class="history-win">+11</span>)',
             "personal_change": '1206 (<span class="history-win">+22</span>)'},
            {"charname": "Dietime", "realm": "Icecrown", "class": "4", "deaths": "1", "damageDone": "22109",
             "healingDone": "0", "matchmaking_change": '1211 (<span class="history-loss">-8</span>)',
             "personal_change": '1166 (<span class="history-loss">-8</span>)'}]

        def fake_fetch(url, kind, post=None):
            return json.dumps(game) if post else page
        old_fetch, old_cache = arena.fetch, arena.CACHE
        arena.fetch, arena.CACHE = fake_fetch, tmp
        try:
            rows = arena.history("Azaret", "Icecrown", 1)
            self.assertEqual([r["soloq"] for r in rows], [True, True, False], "newest first, SoloQ flagged")
            self.assertEqual([r["bracket"] for r in rows], ["soloq", "soloq", "2v2"], "bracket of each game")
            self.assertEqual((rows[0]["id"], rows[0]["win"], rows[0]["rating"], rows[0]["change"]),
                             ("47759373", True, 1206, 22))
            ps = arena.details("47759373", "Azaret", "Icecrown")
            self.assertEqual(ps[0], {"name": "Azaret", "realm": "Icecrown", "class": "ROGUE", "win": True,
                                     "deaths": 0, "damage": 95817, "healing": 0, "mmr": 1446})
            form = arena.recent_form("Azaret", "Icecrown")
            self.assertEqual((form["hgames"], form["hdeaths"], form["mmr"], form["wr"]), (2, 0, 1446, 50))
            self.assertIsNotNone(arena.recent_form("Azaret", "Icecrown", "2v2"), "his 2v2 games")
            self.assertIsNone(arena.recent_form("Azaret", "Icecrown", "3v3"), "no 3v3 games")
        finally:
            arena.fetch, arena.CACHE = old_fetch, old_cache
            shutil.rmtree(tmp)


if __name__ == "__main__":
    unittest.main()
