# Sounds

Every action's sound is in `src/shared/SoundCues.luau`; `src/client/Sfx.luau` plays it; volumes in `src/shared/SoundLevels.luau`.
Real files come only from `SoundCues.CHECKED`: Creator Store ids found and load-checked in Studio
(`/mnt/project-files/car-vs-car/sounds/find-sounds.lua` → `found.txt`). Never make up an id.
A cue with no checked id (or a file that fails to load) plays the built-in ping as notes, so nothing goes silent.

Every cue now has a real file (searches 1-3: sounds/found*.txt). finish (4th+) and trophy reuse the ta-da, gold
reuses the league fanfare: no clean store pick for them. The ping stays only as the fallback if a file fails to load.
