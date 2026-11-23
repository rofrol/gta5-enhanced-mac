# GTA V Enhanced Wine engine

Wine 11.13 with the patches GTA V Enhanced and the Rockstar Games Launcher need on
macOS with Apple's D3DMetal, built by `.github/workflows/build-engine.yml` and
published in this repository's releases (https://github.com/rofrol/gta5-enhanced-mac/releases),
each with Wine's source tarball and the patches.

## Inputs

- Source: WineHQ's `wine-11.13.tar.xz`
  (https://dl.winehq.org/wine/source/11.x/wine-11.13.tar.xz, SHA-256 in
  `source.sha256`). It unpacks to the same tree as the `wine-11.13.tar.gz` MacGames
  ships as the source of its GTA V engine.
- Patches: `patches/`, applied in file-name order with `patch -p1`.
  - Six come unchanged from the `gta5` pack of MacGames by Tarik Caramanico
    (https://github.com/tarikbc/macgames): `Sources/patches/` in `macgames-pack-gta5.tar.xz`
    of its release `packs-1` (https://github.com/tarikbc/macgames/releases/tag/packs-1,
    SHA-256 bc8d15d5ad6713e6a192de6d78e0534a2925db886d7a9225efdf52c25fcc7499):
    `d3dmetal-unix-call.patch`, `kernelbase-cef.patch`, `mac-d3dmetal-surface.patch`,
    `mac-keyboard-reset.patch`, `mac-native-gs.patch` and `rockstar-feature-level.patch`.
    MacGames' own code is under the PolyForm Noncommercial License 1.0.0, but these patches
    are changes to Wine, and MacGames' `THIRD_PARTY_NOTICES.md` lists its `gta5` pack (Wine
    11.13 with patches) under the GNU LGPL 2.1 or later, as Wine is.
  - `wine-native-copy.patch` was written for this engine (first in a fork of Portnaut,
    https://github.com/rofrol/Portnaut), under the GNU LGPL 2.1 or later: `tools/makedep`
    links a module whose `Makefile.in` sets `NATIVECOPY` once more without Wine's builtin
    mark, as `<module>-native.dll` beside it (set for d3d11, dxgi and d3d10core).

  Wine and the patches are under the GNU LGPL 2.1 or later (`Wine-LGPL-2.1.txt`).
  The `rockstar` pack's `rockstar-cef.patch` is not applied: `kernelbase-cef.patch`
  already carries its Rockstar block. The `gta5` pack's `gta-d3d12core-load.patch` is not
  applied either: when `GTM_ROCKSTAR_SWIFTSHADER=1` and the process is `GTA5_Enhanced.exe`,
  it makes `kernelbase` load `d3d12core.dll` as soon as the game loads `d3d12.dll`, for
  D3DMetal 3. With D3DMetal 4.0b3, which the script uses, `d3d12.dll` loads `dxgi.dll`
  and then `d3d12core.dll` itself, and with the patch one game thread holds the loader lock
  while D3DMetal builds its device, so another waits: 19.9 s from `GTA5_Enhanced.exe`'s load
  to `msctf.dll` with the patch against 4.0 s with a `kernelbase.dll` rebuilt without it,
  the game playing in both (one start each, 2026-11-22). An engine paired with an older
  D3DMetal may need the patch back.

## Release contents

- `engine/`: `bin/`, `lib/wine/{x86_64-unix,x86_64-windows,i386-windows}`, `share/wine`,
  x86_64 (it runs under Rosetta 2 on Apple silicon). The Unix side loads its libraries
  (FreeType, GnuTLS, MoltenVK and others) at run time from the path the caller sets,
  as MacGames' engine does; none are bundled.
- `launcher-wined3d/`: Wine's own x86_64 `d3d11.dll`, `dxgi.dll` and `d3d10core.dll` from
  the same build, linked without Wine's builtin mark (`wine-native-copy.patch`). They go into a prefix's `system32`
  for the Rockstar Games Launcher and Social Club, which do not start on D3DMetal: Wine
  replaces a marked file found there with the builtin first in `WINEDLLPATH`
  (`load_builtin` in `dlls/ntdll/unix/loader.c`), which is D3DMetal's.
- `tools/fsevents-wake`: the script's watch of the Windows environment while the launcher
  runs, built from `tools/fsevents-wake.c` (MIT, `tools/LICENSE`); not part of Wine.
- Beside the archive: Wine's source tarball, the patches and `SHA256SUMS`.

D3DMetal is not part of this engine.
