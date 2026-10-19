--!strict
-- Numbers and words for the first-win celebration. All values are placeholders to tune.
return {
	headline = "YOUR FIRST WIN!",
	confettiCount = 60, -- pieces falling (a normal win has none)
	coinCount = 30, -- coin burst size (a normal win uses WinText.DefaultCoins)
	bannerScale = 1.25, -- banner ends bigger than a normal win
	toastText = "FIRST WIN!",
	confettiColors = {
		{ 255, 205, 40 },
		{ 255, 90, 140 },
		{ 60, 240, 255 },
		{ 120, 255, 150 },
		{ 190, 120, 255 },
	},
}
