"""review_page.py: the lead's veto page for draft lines (round 16, booth B3)."""

import json
import unittest

import review_page

LIBRARY = {"vocabulary": {}, "lines": [
    {"id": "caller.kill.40", "speaker": "caller", "act": "call", "tags": ["kill", "streak"], "text": "Old line!"}]}
DRAFTS = [{"id": "caller.kill.900", "speaker": "caller", "act": "call", "tags": ["streak", "kill"], "text": "New line!"},
          {"id": "pa.result.900", "speaker": "pa", "act": "result", "tags": ["outro"], "text": "A wrong detail here.",
           "oddity": {"span": "wrong detail", "category": "paperwork"}}]


class ReviewPageTest(unittest.TestCase):
    def page_data(self, before=None, after=None):
        html = review_page.build(DRAFTS, LIBRARY, before or {}, after or {}, "Booth Veto")
        start = html.index("const DATA = ") + len("const DATA = ")
        return html, json.loads(html[start:html.index(";\n", start)])

    def test_each_draft_is_a_card_in_the_pool_it_joins(self):
        html, data = self.page_data()
        self.assertIn("<title>Booth Veto</title>", html)
        pools = {p["key"]: p for p in data["pools"]}
        streak = pools["caller call [kill,streak]"]
        self.assertEqual([c["id"] for c in streak["cards"]], ["caller.kill.900"])
        self.assertEqual(streak["existing"], ["Old line!"])
        self.assertEqual((streak["today"]["lines"], streak["with"]["lines"]), (1, 2))
        self.assertEqual(pools["pa result [outro]"]["cards"][0]["oddity"], "wrong detail")

    def test_the_numbers_come_from_the_two_tables(self):
        key = "caller call [kill,streak]"
        _, data = self.page_data({key: {"calls_per_match": 2.6, "again5": 0.72}}, {key: {"calls_per_match": 4.0, "again5": 0.07}})
        streak = {p["key"]: p for p in data["pools"]}[key]
        self.assertEqual(streak["today"]["again5"], 0.72)
        self.assertEqual(streak["with"]["again5"], 0.07)
        self.assertTrue(all(c["credits"] > 0 for p in data["pools"] for c in p["cards"]))


if __name__ == "__main__":
    unittest.main()
