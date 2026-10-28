# Sounds

Every action's sound is in `src/shared/SoundCues.luau`; `src/client/Sfx.luau` plays it; volumes in `src/shared/SoundLevels.luau`.
Real files come only from `SoundCues.CHECKED`: Creator Store ids found and load-checked in Studio
(`/mnt/project-files/car-vs-car/sounds/find-sounds.lua` → `found.txt`). Never make up an id.
A cue with no checked id (or a file that fails to load) plays the built-in ping as notes, so nothing goes silent.

Still the ping (Studio search 2 hit Roblox's rate limit before these; re-run queued): finish (4th+), trophy, gold, cheer,
speedUp, maxed, spark, train. Most are old racing/plot cues.
