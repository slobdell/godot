# Bootstrap: What Gets Installed and Why

`make bootstrap` is the only setup step on a fresh clone. This doc explains the
choices so nobody has to rediscover them.

## What it does

1. Downloads `SHA512-SUMS.txt` for the pinned release from GitHub.
2. Downloads the **Godot editor** (`Godot_v4.7.2-stable_linux.x86_64.zip`), verifies the checksum, and unzips it into `.tools/godot-4.7.2-stable/`.
3. Creates `._sc_` beside the binary, which turns on **self-contained mode**: editor settings, caches, and export templates go under `.tools/godot-4.7.2-stable/editor_data/` instead of `~/.local/share/godot` and `~/.config/godot`. The whole toolchain is deletable with `make distclean`, and two projects on different Godot versions can't interfere.
4. Downloads the **export templates** `.tpz` (≈1.2 GB, all platforms), verifies it, extracts **only** the files we use, then deletes the `.tpz`:
   - `web_nothreads_debug.zip`, `web_nothreads_release.zip`: single-threaded web builds
   - `linux_debug.x86_64`, `linux_release.x86_64`: the dedicated server
5. Runs `make import` (builds `.godot/` cache) and `make doctor`.

Result: about **300 MB** in `.tools/`. The download is resumable (`curl -C -`),
and every step is a Make file target, so re-running skips finished work.

## Why these choices

| Choice | Reason |
|---|---|
| **Pinned version** in the Makefile | Scene files, `.uid` files, and export templates are version-specific. The whole team (the lead and their son) should match. |
| **Standard build, not .NET/Mono** | Web export doesn't support C# in Godot 4, and GDScript is what beginners use. |
| **Non-threaded web template** | Threaded web builds need `SharedArrayBuffer`, which needs `Cross-Origin-Opener-Policy` / `Cross-Origin-Embedder-Policy` headers on the host. That breaks many static hosts and some embeds. Our game doesn't need threads. |
| **Trimmed templates** | This machine's disk was 92% full at bootstrap time; 1.2 GB of iOS/Windows/macOS/Android templates we don't use is waste. |
| **Project-local toolchain** | Nothing global to install or uninstall. A clone plus `make bootstrap` is reproducible. |

## Optional tooling (installed on demand)

| Tool | Needed for | Installed by |
|---|---|---|
| Python 3 | `make serve-web`, `make web-smoke` (static server) | system |
| Node + npm | `make web-smoke` | system; `puppeteer-core` pinned in `tools/web_smoke/package.json`, installed automatically on first run |
| Google Chrome | `make web-smoke` (override with `CHROME=/path`) | system |
| A display | `make run`, `make demo`, `make screenshot`, `make editor` | the desktop session |

## Upgrading Godot

1. Change `GODOT_VERSION` in the `Makefile`.
2. `make bootstrap` (the new version installs beside the old one).
3. `make test && make screenshot && make web-smoke && make export-server`, following [verification.md](verification.md).
4. Open the editor once (`make editor`); it may migrate scene files. Review and commit the diff.
5. Update `config/features` in `project.godot` if the editor didn't, and update the version in `orientation.md` and `architecture.md`.
6. `rm -rf .tools/godot-<old>` when happy.

## Platform scope

The Makefile targets **Linux x86_64**, the lead's machine. If the son works on
Windows or macOS, the Godot editor itself is the same, but these Make targets
won't run as-is. Options when that comes up: a `GODOT_PLATFORM` switch plus
WSL on Windows, or just using the editor's built-in export UI. Record the
decision here.

## Coming later: Android (M8)

Expected additions (verify against the Godot 4.7 "Exporting for Android" docs when we get there):
- Android export templates from the `.tpz` (`android_debug.apk`, `android_release.apk`, `android_source.zip` for Gradle builds, which Android plugins require)
- A JDK (this machine has OpenJDK 17; check which version Godot 4.7 requires)
- Android SDK command-line tools, platform-tools, build-tools, and a platform API level
- A debug keystore
- Makefile targets: `bootstrap-android`, `export-android`, `install-android` (adb)
