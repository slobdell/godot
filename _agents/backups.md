# Backups: what's protected, and how

> Added 2026-09-17, after the lead asked for the generated assets to be copied to builder0 automatically:
> *"Can we set up some sort of automated background task that runs fairly frequently to back the data up to builder0?"*

## What matters, and where each copy lives

| What | Size | In git? | Copies |
|---|---|---|---|
| Source, docs, scenes, the shipped faction models, the shipped voice clips | ~135 MB of binaries | **Yes** | the laptop, GitHub (`git@github.com:slobdell/godot.git`) |
| `assets/incoming/` — raw Meshy downloads and CC0 texture sets (~600 Meshy credits) | 968 MB | No (ignored) | the laptop, builder0 (this timer), the cache drive |
| `assets/announcer/masters/` — ElevenLabs MP3 masters (171k credits) | 176 MB | No (ignored) | the laptop, builder0 (this timer), the cache drive |
| `assets/music/` — the lead's Suno tracks, when they land | — | No (ignored) | the same three |

**Why the ignored ones matter:** they're the *inputs*. With them, re-running the asset pipeline or re-cutting announcer
clips (levels, trims, new sentences) costs nothing. Without them it's a paid re-generation, and the result would
differ — a different performance, different meshes.

**Why they're not in git:** a gigabyte of binaries that change wholesale on every regeneration. Git keeps every version
forever; `.git` is already 353 MB. Git LFS is the eventual answer for the binaries that *ship* (clips, models);
GitHub's free tier is 1 GB of storage and 1 GB of bandwidth a month, so the sources wouldn't fit anyway.

## The automatic copy (builder0, every 30 minutes)

```bash
make backup           # run one now
make backup-status    # when it last ran, what's on builder0, room left there
make backup-install   # install and start the timer (already done on the lead's laptop)
```

- **`tools/backup_assets.sh`** rsyncs those three paths to `builder0:~/tank_squad_backup/`.
- **It never deletes.** A file that changed or vanished locally is moved into `_replaced/<date>/` on builder0 rather
  than being overwritten away, so a bad local edit or an accidental `rm` can't destroy the second copy.
- **It's polite:** `nice 10`, idle I/O priority, and a lock file, so it never competes with an agent's build, and a slow
  first copy can't overlap the next tick.
- **Being offline isn't a failure:** if builder0 is unreachable it logs "skipped" and exits 0.
- **Log:** `build/backup.log`, plus `journalctl --user -u tank-squad-backup`.
- **The timer:** the unit files live in the repo (`tools/systemd/tank-squad-backup.{service,timer}`, `%h`-relative so
  they work for any user); `make backup-install` copies them into `~/.config/systemd/user/` and starts them. Every 30
  minutes, `Persistent=true` so a missed window runs after a reboot. It runs while the lead is logged in; `loginctl enable-linger slobdell` would make
  it run when logged out too.

**Verified 2026-09-17:** first full copy 1.2 GB on builder0, file counts equal on both sides, and the timer correctly
skipped a tick that fired while the first copy was still running.

## The manual copy (cache drive → Google Drive)

`/media/slobdell/plane-cache/tank_squad_assets/<date>/` holds a dated snapshot with a README explaining each folder and
how to restore it. That's the copy the lead mirrors to Google Drive. Make a fresh dated snapshot after any big
generation round:

```bash
D=/media/slobdell/plane-cache/tank_squad_assets/$(date +%F)
rsync -a assets/incoming/ $D/assets_incoming/
rsync -a assets/announcer/masters/ $D/announcer_masters/
```

## Restoring

```bash
rsync -a slobdell@builder0:~/tank_squad_backup/assets/incoming/ assets/incoming/
rsync -a slobdell@builder0:~/tank_squad_backup/assets/announcer/masters/ assets/announcer/masters/
```

## Round-close note for the orchestrator

The timer only sees the **main checkout**. A worker's worktree can hold git-ignored payload that has never been copied
anywhere (round 3: 397 MB of Meshy downloads; round 4: 176 MB of announcer masters). Before
`make worktree-remove`, rsync any ignored payload into the main checkout — then the timer picks it up within half an
hour ([orchestration.md](orchestration.md) §8).
