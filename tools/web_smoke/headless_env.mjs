// N6 (round 34, native): the environment the smoke's headless Chrome runs in. A display in it (DISPLAY, XAUTHORITY,
// WAYLAND_DISPLAY) makes Chrome's GPU process try that display first; when it is gone (builder0, 2026-10-18 ~23:00: the
// desktop session died and tools/remote.sh still exported DISPLAY=:0 with its stale Xwayland auth file), WebGL2 is
// missing and the game never boots. Headless SwiftShader needs no display, so the smoke never hands it one.
const DISPLAY_VARS = ["DISPLAY", "XAUTHORITY", "WAYLAND_DISPLAY"];

export function headlessEnv(env) {
  const out = { ...env };
  for (const name of DISPLAY_VARS) delete out[name];
  return out;
}
