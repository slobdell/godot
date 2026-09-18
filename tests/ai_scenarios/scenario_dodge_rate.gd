extends TestCase
## Round-5 reopening (ai): the 30 Hz tick cost dodging — a tank dodged 17% of a leading cannon's shells before and 1%
## after — but combat's `ready_to_fire` fix put more shells in the air at the same time, so "dodged fewer" could be a
## worse dodger or a denser barrage, and the fix differs. This separates them: for one unit against one cannon at 50 m,
##   inbound        rounds that ever came close enough to be worth dodging (IncomingFire.count_for > 0)
##   dodging ticks  ticks the brain's own plan said it was dodging one
##   attempts       dodging ticks per inbound round: does it still TRY as often, and are its tries less effective?
## Reported per brain variant, never asserted except that the champion still tries: this is evidence for the lead's
## choice between army size and units that react.

const SEEDS := [1, 2, 3, 4, 5, 6, 7, 8]
const SECONDS := 30


func _duel(variant: String, unit: String, seed_value: int) -> Dictionary:
	BrainVariants.use(Match.Team.GREEN, variant)
	var s := AiScenario.create(self, seed_value)
	var gun := s.shooter(Match.Team.RUST, "Rust_Gun_1", Vector3(-100, 0, -15), 0.0)
	AiScenario.make_durable(gun)
	var me := s.brain_tank(Match.Team.GREEN, "Green_A_1", Vector3(-104 + seed_value * 3, 0, 35), PI, {}, unit)
	AiScenario.make_durable(me)
	var brain := s.brain_of(me)
	var hits := 0
	var inbound_ticks := 0
	var dodging_ticks := 0
	var last := me.health + me.shield
	await s.start()
	for tick in SimClock.TICK_RATE * SECONDS:
		await s.step()
		var now := me.health + me.shield
		if now < last - 5.0:
			hits += 1
		last = now
		# Rounds actually threatening this unit right now, and whether the plan it is driving is a dodge.
		var incoming: int = IncomingFire.count_for(s.game_match, me)
		if incoming > 0:
			inbound_ticks += 1
			dodging_ticks += 1 if brain.why.contains("dodging") else 0
	var fired := s.shots_by(gun)
	s.dispose()
	BrainVariants.reset()
	return {"fired": fired, "hits": hits, "inbound_ticks": inbound_ticks, "dodging_ticks": dodging_ticks}


## KNOWN-FAILING since CP4 (round 6), and why — so nobody re-derives it: dodging has never really fired (round 5: 254 of
## 254 candidate directions scored "would still be hit"), so "the champion still tries to dodge" tests an aspiration.
## squad and combat A/B'd it in the CP4 pair (2026-09-18, laptop): the champion's IFV made 0 attempts in ~490 inbound
## ticks with X6's crossing penalty on AND off. Which variant happens to collect the few attempts (0-32 of ~500 ticks)
## reshuffles with any change at all — it looked like a pattern (IFVs with crossing on, tanks with it off) and is NOT
## one. Not in make check. Fix dodging itself before tuning anything to this number.
func test_who_dodges_and_how_often_they_try() -> void:
	var tried := {}
	for unit: String in ["ifv", "tank"]:
		for variant: String in [BrainVariants.CHAMPION, "x6t5", "x6t4"]:
			var totals := {"fired": 0, "hits": 0, "inbound_ticks": 0, "dodging_ticks": 0}
			for seed_value: int in SEEDS:
				var run: Dictionary = await _duel(variant, unit, seed_value)
				for key: String in totals:
					totals[key] += int(run[key])
			tried["%s/%s" % [unit, variant]] = totals
			print("MEASURE ai_dodge_attempts %s %s: %d shells fired, %d hit (%.0f%% dodged); %d ticks with a round inbound, %d of them dodging (%.0f%% of the time it had something to dodge)" % [
					unit, variant, totals["fired"], totals["hits"],
					100.0 * (1.0 - float(totals["hits"]) / maxf(totals["fired"], 1.0)), totals["inbound_ticks"],
					totals["dodging_ticks"],
					100.0 * float(totals["dodging_ticks"]) / maxf(totals["inbound_ticks"], 1.0)])
	var champion: Dictionary = tried["ifv/%s" % BrainVariants.CHAMPION]
	assert_true(int(champion["inbound_ticks"]) > 0, "setup: rounds came at it (%d ticks)" % champion["inbound_ticks"])
	assert_true(int(champion["dodging_ticks"]) > 0,
			"the champion still tries to dodge (%d of %d inbound ticks)" % [champion["dodging_ticks"], champion["inbound_ticks"]])
