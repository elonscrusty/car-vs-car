# Sounds wanted (carter: send Roblox sound ids, one per line)

Right now every cue is the built-in ping, pitched (src/client/Sfx.luau). No ids are made up.
Swap in a real sound by changing `Sfx.luau`; volumes live in `src/shared/SoundLevels.luau`.

1. Coin collect — short bright "ching" (one coin landing)
2. Level up — happy rising jingle, about 1 second
3. Race finish — cheer or fanfare (a longer one for 1st-3rd)
4. New car reveal — sparkly "ta-da"
5. Countdown beep and GO — low beep, high beep

## Car VS Car cues (Sfx.crate, Sfx.trophy, Sfx.train — UI/Race call them)
6. Crate open — drum roll then sparkle (longer for rare cars)
7. Trophy / win — cheer plus fanfare
8. Training station hum — now the motor loop at low pitch; a real soft hum per station kind would be nicer
9. Engine, upbeat music — need ids; engine already has two
