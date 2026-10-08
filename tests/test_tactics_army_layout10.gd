extends TestCase
## Round 22 (brains B2; orders' request, the orchestrator's ruling): TEN SQUADS A SIDE AT THE START. ArmyLayout stands ten
## squads of five as two rows (ruled: the spawn stays as it is; orders' untangle deals his first order), and no two
## vehicles stand on top of each other at tick 0. The full sweep is `tests/tactics/layout_probe.gd` (every rotation map x
## every faction x both teams: 104 deployments, 0 hull overlaps, laptop, 2026-10-07); this is its worst corner, the
## gangs' 14 m War Rigs on the three maps where their squads' footprints touched most (terminus, crossing, docks), and
## the foundry he plays.

const ARENAS := ["terminus", "crossing", "docks", "foundry"]


func test_ten_squads_a_side_no_two_hulls_overlap() -> void:
	for arena: String in ARENAS:
		var lab := TacticsLab.create(self, 1, arena)
		for team in [Match.Team.GREEN, Match.Team.RUST]:
			var built := LayoutCheck.full_army("gangs", 1 + team)
			assert_eq(String(lab.game_match.load_doctrine(team, built["doctrine"])), "", "%s: the army loads" % arena)
		await lab.start()
		for team in [Match.Team.GREEN, Match.Team.RUST]:
			var squads := lab.game_match.team_squads(team)
			assert_eq(squads.size(), LayoutCheck.SQUADS, "%s team %d: ten squads" % [arena, team])
			for squad: Squad in squads:
				assert_true(squad.roster.size() <= Formations.MAX_MEMBERS, "%s: %s holds at most five" % [arena, squad.squad_name])
			var overlaps := LayoutCheck.hull_overlaps(lab.game_match, team)
			assert_true(overlaps.is_empty(), "%s team %d: no two hulls overlap at the start: %s" % [arena, team, overlaps])
		lab.dispose()
