class_name FreshWorld
extends RefCounted
## Round 48 (native N3, R48.5): EVERY MATCH STARTS ON A FRESH World3D. The root Viewport's World3D (its physics space and its
## navigation map) outlives a scene change, so a process's second match ran on the first one's space: test_native_rematch, the
## CPU sliver lab on Crossing run three times in one process, parted from the first run at tick 2 (0.32 m worst, builder3,
## f0900328a) and runs 2 and 3 matched each other (state left by a freed match); on a fresh World3D all three are identical tick for
## tick. That is the R47.47 history dependence and the in-process rematch / netplay hazard. Main._enter_tree and the test runner
## (per file) call apply(); `--fresh-world=off` keeps the old world (round 47's).

static var ON := not OS.get_cmdline_user_args().has("--fresh-world=off")
## How many worlds apply() has made in this process (tests).
static var made := 0


## Give `viewport` a new World3D with the old one's environments. The old world is held until the viewport has let go of it:
## dropped first, the engine frees it inside the setter and then reports its scenario as null (an engine error per swap).
static func apply(viewport: Viewport) -> void:
	if not ON or viewport == null:
		return
	var old := viewport.world_3d
	var fresh := World3D.new()
	if old != null:
		fresh.environment = old.environment
		fresh.fallback_environment = old.fallback_environment
		fresh.camera_attributes = old.camera_attributes
	viewport.world_3d = fresh
	made += 1
	old = null
