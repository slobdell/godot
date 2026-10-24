# CORE-MATH (vendored, unedited)

Correctly rounded binary32 `atan2f acosf asinf atanf tanf` from the CORE-MATH project (Alexei Sibidanov, Paul Zimmermann
et al.), MIT licence (in each file's header). Source: https://gitlab.inria.fr/core-math/core-math `src/binary32/<fn>/<fn>.c`
at commit `0ce0cbc15935e24c656280e5a46c34e89f301b7a` (2026-10-20). The same code glibc >= 2.41 ships, so these give the
builders' libm results bit for bit on any machine. Why and how they are used: `_agents/native.md` "Machine-independent trig".

To update: fetch the five files at a new commit, run `make trig-check` on a glibc >= 2.41 box (must print 0 differ for
every function), then `make sim-baseline` on the laptop.
