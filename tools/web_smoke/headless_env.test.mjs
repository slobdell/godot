// Run first by `make web-smoke` (node --test): the smoke's Chrome gets no display.
import { test } from "node:test";
import assert from "node:assert/strict";
import { headlessEnv } from "./headless_env.mjs";

test("a dead desktop's display never reaches the smoke's Chrome", () => {
  const env = headlessEnv({ DISPLAY: ":0", XAUTHORITY: "/run/user/1000/.mutter-Xwaylandauth.X", WAYLAND_DISPLAY: "wayland-0",
    PATH: "/usr/bin", HOME: "/home/x" });
  assert.equal(env.DISPLAY, undefined);
  assert.equal(env.XAUTHORITY, undefined);
  assert.equal(env.WAYLAND_DISPLAY, undefined);
  assert.equal(env.PATH, "/usr/bin", "everything else is kept");
  assert.equal(env.HOME, "/home/x");
});

test("the caller's environment is not changed", () => {
  const before = { DISPLAY: ":0" };
  headlessEnv(before);
  assert.equal(before.DISPLAY, ":0");
});
