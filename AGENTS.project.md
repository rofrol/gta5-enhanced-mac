# Project rules

## Architecture map

- `gta5-enhanced-mac`: the product, one bash script (macOS's `/bin/bash` 3.2: no associative arrays, no
  `${var,,}`, no `mapfile`, no `coproc`). `install` downloads the pinned archives, builds the engine
  profile, creates the Wine prefix and runs Rockstar's launcher installer; `play` starts the launcher.
  Each Wine session runs inside `start_watch`/`stop_watch`, which write the game's arguments while it
  runs. Sourced, it only defines its values and functions (the tests source it).
- `engine/` and `.github/workflows/build-engine.yml`: the engine build (Wine 11.13, the patches in
  `engine/patches`, their origin and licence in `engine/README.md`). A push to main that changes
  `engine/**`, `tools/**` or the workflow builds and publishes a release
  `gta5-wine-11.13-<commit>-r<run>` with Wine's source, the patches and `SHA256SUMS`, created with
  `--latest=false` (the script pins by tag; GitHub still shows the only full release, r1, as
  "latest"). Then pin the new release in the script: `engine_release`, and `engine_sha256` taken from a downloaded archive that matches the release's `SHA256SUMS`; bump the
  version in `marker` when how the profile is assembled or applied changes.
- `tools/fsevents-wake.c`: the watch the script reads during a session (protocol in its header), built
  universal by the engine workflow and shipped in the engine release as `tools/fsevents-wake`.
- The recipe (pins, links, system32 copies, environment, registry, game arguments) lives in the script
  only; it depends on no other project.
- Persistent data: everything under `~/Library/Application Support/gta5-enhanced-mac` (or the existing folder
  `GTA5_ENHANCED_MAC_DATA` names). `prefix/` holds the user's launcher sign-in, game and saves: the script
  never deletes or replaces it; `profile/` and `downloads/` are rebuilt from the pins.
- Trust: the three pinned archives are checked by SHA-256 before use; Rockstar's installer is not pinned
  (Rockstar replaces it) and is checked only for the `MZ` header, over HTTPS from Rockstar's host. Nothing
  of D3DMetal is committed here or published in the releases.
- Folder-mapping cleanup, not a sandbox: the prefix has no drive `Z:` and no links under `drive_c/users`
  (`isolate_user_folders`, `check_user_folders` before every program start), so the launcher and the game
  keep their files in the prefix. `commandline.txt` is written only in real folders inside the prefix.
  Wine still runs with the Mac user's rights and reaches the disk through its own Unix paths.

## Verification

- `shellcheck -x gta5-enhanced-mac tests/test.sh`
- `tests/test.sh`: the game-argument rules and the watch (no Wine needed; builds `tools/fsevents-wake.c`
  with clang).
- A full `install` runs only into a scratch data folder (`GTA5_ENHANCED_MAC_DATA`), never into the owner's
  `~/Library/Application Support/gta5-enhanced-mac`, and follows the owner's user-folder guard for scratch
  Wine bottles (`scratch-bottle-user-folders.sh` in the owner's gta5-on-macos-aarch64 repository, "Probes in
  scratch Wine bottles" in its AGENTS.project.md: `mkdir` the scratch `prefix`, run `prepare PREFIX
  crossover` before `install`, and `check` after `wineserver -w`). Stop the session with `wineserver -k`
  under the scratch `WINEPREFIX` only: other Wine sessions on the Mac (the owner's game) must not be
  touched. Signing in to the launcher and playing are the owner's checks.
