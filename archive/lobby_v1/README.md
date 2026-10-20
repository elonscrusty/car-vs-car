# Archived lobby v1 (warehouse race HQ)

Retired 2026-10-20 when carter's new Car Battle Lobby replaced it (docs/LOBBY_SPEC.md).
Kept, not deleted: Rojo ships this folder to `ServerStorage.LobbyArchive` (see default.project.json)
so it sits in storage and never runs. Nothing in `src/` requires it. Its tests are not in tests/run.
To bring it back, move the files into src/server (and LobbyLayout into src/shared) and fix the requires.
