// Round 27 (native, stage 1 E1): THE TABLE of a crew's execute state -- every script member of its Movement
// (game/ai/movement.gd), Gunnery (game/ai/gunnery.gd; its five forwarding getters tank/tanks_root/weapon_order/
// move_order/_step are the controller's, not state) and Engagement.Lay (game/combat/engagement.gd), in the scripts'
// declaration order, with the Variant type each is declared with. ExecState (exec_state.h) generates from it the typed
// struct, the names, pull/push and the test's row. tests/test_native_exec_state.gd fails when a script's members and
// this table disagree (a member added, removed or retyped), and prints the line to add.
//
// F(ctype, Variant::Type the member holds, name). Object members are held as a Variant (OBJECT; null allowed),
// an untyped `Variant` member as NIL (anything). Array and Dictionary members are SHARED references (the struct holds the
// same container the GDScript does, so an in-place change is seen by both); packed arrays are values.
#pragma once

#define EXEC_MOVER_FIELDS(F) \
	F(Variant, OBJECT, ctl) \
	F(int64_t, INT, native_stale) \
	F(int64_t, INT, stalled_ticks) \
	F(String, STRING, phase) \
	F(String, STRING, blocked_by) \
	F(PackedVector3Array, PACKED_VECTOR3_ARRAY, _path) \
	F(int64_t, INT, _path_index) \
	F(Vector3, VECTOR3, _path_goal) \
	F(double, FLOAT, _repath_left) \
	F(double, FLOAT, _stuck_time) \
	F(Vector3, VECTOR3, _stuck_from) \
	F(double, FLOAT, _unstick_left) \
	F(bool, BOOL, _unstick_pivot) \
	F(Vector3, VECTOR3, _progress_goal) \
	F(double, FLOAT, _progress_best) \
	F(Vector3, VECTOR3, _goal) \
	F(bool, BOOL, _reachable) \
	F(bool, BOOL, _circling) \
	F(Vector3, VECTOR3, _repair_for) \
	F(Vector3, VECTOR3, _repair_to) \
	F(Dictionary, DICTIONARY, _route_reading) \
	F(double, FLOAT, _arrive) \
	F(double, FLOAT, _remaining) \
	F(int64_t, INT, _blocker_left) \
	F(String, STRING, yield_to) \
	F(Vector3, VECTOR3, _yield_point) \
	F(Vector2, VECTOR2, _yield_dir) \
	F(int64_t, INT, _yield_left) \
	F(int64_t, INT, _yield_held) \
	F(String, STRING, _last_yielded_to) \
	F(int64_t, INT, _ask_left) \
	F(Vector2, VECTOR2, _goal_velocity) \
	F(Vector3, VECTOR3, _goal_seen) \
	F(int64_t, INT, _goal_changed_at) \
	F(bool, BOOL, _reissued) \
	F(int64_t, INT, _ticks) \
	F(int64_t, INT, _order_ticks) \
	F(Vector3, VECTOR3, steer_to) \
	F(double, FLOAT, pace_now) \
	F(bool, BOOL, stationed_now) \
	F(int64_t, INT, _blocked_ticks) \
	F(int64_t, INT, _give_way_left) \
	F(int64_t, INT, give_ways) \
	F(Variant, OBJECT, _station) \
	F(String, STRING, _station_faction) \
	F(String, STRING, _wheel_radius_unit) \
	F(double, FLOAT, _wheel_radius_value) \
	F(Variant, NIL, _fire_detour) \
	F(int64_t, INT, _fire_detour_until) \
	F(int64_t, INT, _fire_detour_since) \
	F(int64_t, INT, _fire_detour_again) \
	F(int64_t, INT, _fire_since) \
	F(int64_t, INT, _fire_checked_tick) \
	F(Variant, OBJECT, contact) \
	F(bool, BOOL, _deflected) \
	F(bool, BOOL, arc_live) \
	F(Vector3, VECTOR3, _behind_goal) \
	F(String, STRING, _behind_plan) \
	F(int64_t, INT, _behind_tick) \
	F(int64_t, INT, _behind_since) \
	F(Vector3, VECTOR3, _kept_goal) \
	F(Vector3, VECTOR3, _kept_from) \
	F(Array, ARRAY, _face_legs) \
	F(double, FLOAT, _face_turn) \
	F(int64_t, INT, _face_gear) \
	F(double, FLOAT, _face_left_m) \
	F(Vector3, VECTOR3, _face_from) \
	F(double, FLOAT, _face_travelled) \
	F(int64_t, INT, _face_tick) \
	F(double, FLOAT, _face_timeout) \
	F(Vector3, VECTOR3, _face_want) \
	F(Vector3, VECTOR3, _face_spot) \
	F(Vector3, VECTOR3, _face_origin) \
	F(Vector3, VECTOR3, _face_home) \
	F(Vector3, VECTOR3, _face_blocked) \
	F(double, FLOAT, _face_err0) \
	F(double, FLOAT, _face_window) \
	F(Vector3, VECTOR3, _face_window_heading) \
	F(int64_t, INT, _face_retry) \
	F(bool, BOOL, _nose_at_end) \
	F(Vector3, VECTOR3, _nose_goal) \
	F(double, FLOAT, pass_offer) \
	F(String, STRING, _pass_by) \
	F(double, FLOAT, _pass_side) \
	F(Vector2, VECTOR2, _pass_way) \
	F(int64_t, INT, _pass_left) \
	F(String, STRING, _pass_failed_by) \
	F(Dictionary, DICTIONARY, _yield_rec) \
	F(Vector3, VECTOR3, _yield_from) \
	F(double, FLOAT, _yield_stop_m) \
	F(bool, BOOL, _yield_unfit_last) \
	F(Vector3, VECTOR3, _gate_dropped_for) \
	F(String, STRING, _gate_dropped_why) \
	F(Vector3, VECTOR3, _gate_turning_for) \
	F(int64_t, INT, _gate_turning_tick) \
	F(Vector3, VECTOR3, _gate_seen_for) \
	F(Vector3, VECTOR3, _gate_side_for) \
	F(Vector3, VECTOR3, _gate_side) \
	F(Array, ARRAY, _roomy_key) \
	F(Vector3, VECTOR3, _roomy_value) \
	F(Array, ARRAY, _turn_room_key) \
	F(bool, BOOL, _turn_room_value) \
	F(Array, ARRAY, _deflect_window) \
	F(Array, ARRAY, _wedge_trail) \
	F(bool, BOOL, wedged) \
	F(double, FLOAT, wedge_moved_m) \
	F(double, FLOAT, wedge_hull_m) \
	F(StringName, STRING_NAME, last_replan) \
	F(int64_t, INT, _chord_frame) \
	F(Vector3, VECTOR3, _chord_from) \
	F(Vector3, VECTOR3, _chord_to) \
	F(bool, BOOL, _chord_answer) \
	F(Variant, OBJECT, _census) \
	F(int64_t, INT, _esc_stage) \
	F(double, FLOAT, _esc_gap) \
	F(Variant, OBJECT, _esc_friend) \
	F(double, FLOAT, _esc_target_m) \
	F(Vector3, VECTOR3, _unstick_from) \
	F(String, STRING, _h1b_blocker) \
	F(Vector3, VECTOR3, _h1b_goal) \
	F(Vector3, VECTOR3, _h1b_at) \
	F(int64_t, INT, _h1b_failed) \
	F(bool, BOOL, _h1b_last_answer) \
	F(double, FLOAT, _esc_gear) \
	F(double, FLOAT, _press_time) \
	F(Vector3, VECTOR3, _press_from) \
	F(double, FLOAT, _escape_gear) \
	F(double, FLOAT, _escape_turn) \
	F(double, FLOAT, _kturn_left_m) \
	F(double, FLOAT, _kturn_turn) \
	F(Vector3, VECTOR3, _kturn_from) \
	F(double, FLOAT, _kturn_timeout) \
	F(int64_t, INT, _kturn_check) \
	F(int64_t, INT, _kturn_gear) \
	F(Array, ARRAY, _kturn_legs) \
	F(RID, RID, _lazy_map) \
	F(Array, ARRAY, _lazy_frame) \
	F(Vector3, VECTOR3, _lazy_at) \
	F(Vector3, VECTOR3, _lazy_heading) \
	F(PackedFloat32Array, PACKED_FLOAT32_ARRAY, _lazy_start) \
	F(String, STRING, _reverse_why) \
	F(Dictionary, DICTIONARY, _kturn_rec) \
	F(String, STRING, _kturn_plan_kind) \
	F(int64_t, INT, _kturn_leg_no) \
	F(PackedFloat32Array, PACKED_FLOAT32_ARRAY, _kturn_start_offs) \
	F(Dictionary, DICTIONARY, _circle_rec) \
	F(Vector3, VECTOR3, _circle_last) \
	F(double, FLOAT, _circle_away) \
	F(int64_t, INT, _circle_away_ticks) \
	F(double, FLOAT, _kturn_arc_m) \
	F(Array, ARRAY, _kturn_looks) \
	F(int64_t, INT, _ease_ticks) \
	F(double, FLOAT, _ease_throttle) \
	F(bool, BOOL, _kturn_rolling) \
	F(Array, ARRAY, _kturn_plan_pose) \
	F(double, FLOAT, _kturn_hit_m) \
	F(String, STRING, yield_spot)

#define EXEC_GUNNERY_FIELDS(F) \
	F(Variant, OBJECT, ctl) \
	F(String, STRING, engaged_target) \
	F(Variant, NIL, watch_point) \
	F(Callable, CALLABLE, spotter) \
	F(Variant, OBJECT, engagement_lay) \
	F(int64_t, INT, ticks_since_fire) \
	F(int64_t, INT, lane_blocked_ticks) \
	F(String, STRING, lane_blocker) \
	F(bool, BOOL, hold_for_friends) \
	F(Vector3, VECTOR3, _held_aim) \
	F(Variant, OBJECT, _scan_pick) \
	F(int64_t, INT, _scan_left) \
	F(int64_t, INT, _lane_hold_left) \
	F(double, FLOAT, _seconds)

#define EXEC_LAY_FIELDS(F) \
	F(String, STRING, target) \
	F(double, FLOAT, progress) \
	F(bool, BOOL, firing)

