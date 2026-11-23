# gta5-enhanced-mac

One bash script that sets up Grand Theft Auto V Enhanced on an Apple silicon Mac with the Rockstar Games
Launcher, without an app: you sign in, install the game in the launcher and play.

This is an unofficial community script. It is not affiliated with, endorsed or supported by Rockstar
Games, Take-Two Interactive, Apple, CodeWeavers or WineHQ. You need your own copy of the game; the script
never downloads the game. GTA Online does not run under Wine (its anti-cheat blocks it); story mode does.

## Use

```sh
git clone https://github.com/rofrol/gta5-enhanced-mac
cd gta5-enhanced-mac
./gta5-enhanced-mac install
```

`install` downloads and builds the engine (about 2 GB on disk), creates the Windows environment and runs
Rockstar's launcher installer. Keep the installer's folder (the script looks for the launcher there).
When the launcher opens, sign in and install GTA V Enhanced, in its default folder or another folder of
drive C:. Then quit the launcher and start it again with:

```sh
./gta5-enhanced-mac play
```

and choose Play in the launcher. `play` waits until every Wine process of the environment has ended, and
refuses to start while one still runs (quit the launcher first). You can also play straight away in the
launcher session `install` opened.

The game needs `-disableSpatialAudioClient` in its `commandline.txt` (without it voices and most effects
are silent under Wine). The script writes it, with `-nobattleye`, into every folder of the environment
that holds `GTA5_Enhanced.exe`: the default one or another you chose in the launcher. It does so before
each launcher session, after it, and during it, as soon as the launcher installs or moves the game
(a small FSEvents watch, `fsevents-wake`, tells it when), so the first Play after installing normally
has them.
Nothing makes the launcher wait for that write: a Play that comes before it starts the game without
them (`play` writes them again before the next session).
Your own arguments in that file are kept; a `commandline.txt` that is not a plain UTF-8 file (UTF-16,
a link) is left as it is, without them. A game folder outside the environment (a drive you linked
elsewhere) gets nothing.

Run `install` again to update: it rebuilds the engine when this script's pins change and applies its
files and registry to the environment again; it does not reinstall the launcher once it is there.

Requirements: an Apple silicon Mac with Rosetta 2 (`softwareupdate --install-rosetta`) and macOS's own
`/bin/bash`, `curl` and `tar`. Apple's D3DMetal 4 needs a recent macOS.

What has been tested: GTA V Enhanced signs in and plays, with voices, with the same Wine source,
patches, D3DMetal and settings in Portnaut's bottle on an M1 Pro. This script, with this repository's
engine build, has been run up to the start of Rockstar's installer (downloads, engine, Windows
environment, registry, system32 copies); signing in and playing through it are yet to be reported.

## What it downloads

Each pinned archive is checked against its SHA-256 before it is used.

| What | From | SHA-256 | Licence |
|---|---|---|---|
| Wine 11.13 with six of MacGames' GTA V patches and one of this repository's, WineD3D builds of `d3d11`, `dxgi` and `d3d10core` for the launcher, and `fsevents-wake` (release `gta5-wine-11.13-0a2a2901a478-r1`) | [this repository's releases](https://github.com/rofrol/gta5-enhanced-mac/releases/tag/gta5-wine-11.13-0a2a2901a478-r1), built by `.github/workflows/build-engine.yml` from `engine/` and `tools/` and published with Wine's source, the patches and `SHA256SUMS` | `7159cd0a…18d31` | Wine and the patches: LGPL 2.1 or later; `fsevents-wake`: MIT |
| Sikarugir's template 1.0.15: the engine's libraries (GStreamer, MoltenVK and others) | [Sikarugir-App/Wrapper](https://github.com/Sikarugir-App/Wrapper/releases/tag/v1.0) | `34273bcc…5c8c3` | each library's own |
| Sikarugir's template 1.0.27, for Apple's D3DMetal 4.0b3 (the game's Direct3D 12) | [Sikarugir-App/Wrapper](https://github.com/Sikarugir-App/Wrapper/releases/tag/v1.0) | `dd0778f7…edbb9` | D3DMetal: Apple's licence |
| Rockstar Games Launcher installer | Rockstar's own link, `gamedownloads.rockstargames.com`, over HTTPS (redirects only to HTTPS) | not pinned: Rockstar replaces it; the script checks only that its first two bytes are `MZ`, as a Windows program's are | Rockstar's terms |

The full hashes are in the script. D3DMetal is Apple's, from the Game Porting Toolkit. This repository
does not include or redistribute it: the script downloads Sikarugir's template and unpacks D3DMetal on
your Mac. Apple's licence covers non-commercial use for developing, testing and
evaluating games on Apple hardware; read it (`License.rtf` in
`profile/packs/sikarugir-d3dmetal-4.0b3`) before you use it.

## Where things go

Everything lives in `~/Library/Application Support/gta5-enhanced-mac`:

- `downloads/`: the archives above (delete them after `install` to save about 300 MB);
- `profile/`: the engine (`engine/`, `launcher-wined3d/`, `tools/`, `deps/Frameworks`, `packs/`);
- `prefix/`: the Windows environment, with the launcher, the game, your sign-in and saves;
- `logs/`: `setup.log` and `session.log`, Wine's messages.

Remove that folder to remove everything. The environment runs every program as the Windows user
`crossover`, the user the engine's patches expect. It has no drive `Z:` (the whole Mac),
and its Documents, Desktop and other user folders are its own instead of links to yours, so the launcher
and the game keep their files in the environment and not in `~/Documents`. This is not a sandbox: Wine
runs with your account's rights, and a Windows program can still reach your files through Wine's own
paths to the Mac's disk. Drive `Y:` points to the engine's folder.

## How it works

The script builds the environment MacGames' GTA V setup uses, with the Rockstar Games Launcher:

- the engine gets links to D3DMetal's `dxgi`, `d3d11`, `d3d12` and `atidxx64` in its own `lib/wine`, so the
  game draws through D3DMetal;
- `system32` gets copies of WineD3D's `d3d11`, `dxgi` and `d3d10core`, which the launcher and Social Club
  take (they do not start on D3DMetal);
- per-program DLL overrides in the registry choose between the two, and the Mac driver captures the
  display in fullscreen so the cursor does not flicker;
- `commandline.txt` in the game's folder gets `-disableSpatialAudioClient` and `-nobattleye`.

The engine is built in this repository: `engine/README.md` lists its source, patches and their origin,
and each release carries Wine's source and the patches.

## Prior work

- [MacGames](https://github.com/tarikbc/macgames) by Tarik Caramanico, an app whose GTA V Enhanced
  environment this recipe comes from, and whose `gta5` pack is the origin of six of the engine's
  patches (LGPL 2.1 or later, as its third-party notices state; MacGames' own code is under the PolyForm
  Noncommercial License 1.0.0). It sets up Steam in that environment, and you install the game through
  Steam; it needs macOS 26 or later. This script installs the Rockstar Games Launcher from Rockstar itself,
  with no Steam, and uses D3DMetal 4.0b3 where MacGames 0.1.6 uses 4.0b2.
- [Portnaut](https://github.com/BuiltByArgo/Portnaut), an app for many launchers and games, in whose
  fork this engine build and recipe were first worked out (pull request
  [#6](https://github.com/BuiltByArgo/Portnaut/pull/6)). This script needs neither app: it is the same
  setup for one game, without a bottle library, save backups, renderer choice or doctor.

## Checks

```sh
shellcheck -x gta5-enhanced-mac tests/test.sh
tests/test.sh   # where commandline.txt goes, how it is merged, and the watch (needs clang)
```

## Licence

The script and `tools/fsevents-wake.c` are under the [MIT licence](LICENSE). The engine's patches and
Wine are under the GNU LGPL 2.1 or later (`engine/Wine-LGPL-2.1.txt`). What the script downloads keeps
its own licence (above).
Grand Theft Auto, Rockstar Games and their logos are trademarks of Take-Two Interactive Software; Apple,
Mac and D3DMetal are trademarks of Apple Inc.
