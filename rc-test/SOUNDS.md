# Sounds

Every action's sound is in `src/shared/SoundCues.luau`; `src/client/Sfx.luau` plays it; volumes in `src/shared/SoundLevels.luau`.
Real files come only from `SoundCues.CHECKED`: Creator Store ids found and load-checked in Studio
(`/mnt/project-files/car-vs-car/sounds/find-sounds.lua` → `found.txt`). Never make up an id.
A cue with no checked id (or a file that fails to load) plays the built-in ping as notes, so nothing goes silent.

Still the ping (no clean Creator Store pick yet): unlock, finish (4th+), go (the count beep pitched up), gun (per bullet),
pickup, respawn, freeze shot, freeze, shatter, and the older plot cues (train, speedUp, maxed, spark, trophy, cheer).
